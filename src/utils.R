#!/usr/bin/env Rscript

################################################################################
# MODULE: UTILITY FUNCTIONS (CHAPTER 2)
#
# Contains helper functions (e.g., classification, interpolation)
# used by other modules in the toolbox.
# NEW: Added explicit library calls for robustness.
################################################################################

# --- 1. DEPENDENCIES ---
# These are the packages THIS script's functions rely on.
library(terra)
library(classInt)
library(rlang)
library(areal)

################################################################################
# --- 2. FUNCTION DEFINITIONS ---
################################################################################

#' Extract Valid Raster Values
#' 
#' Extracts non-NA values from a raster input object.
#'
#' @param raster_input terra::SpatRaster: The input raster object.
#' @return numeric vector: A vector of non-NA raster cell values.
get_raster_values <- function(raster_input) {
  # Extracts all values from the raster layer
  raster_values <- values(raster_input, mat = FALSE)
  # Removes NA (NoData) values
  raster_values <- raster_values[!is.na(raster_values)]
  return(raster_values)
}

# --------------------------------------------------------------------------- #

#' Generate Systematic Classification Break Values
#' 
#' Calculates class intervals (breaks) for visualization or data grouping 
#' using various classification styles (e.g., 'jenks', 'quantile').
#' Handles edge cases where the dataset has only one unique value.
#'
#' @param dataset_column_input numeric vector: The data column used for classification.
#' @param amount_intervals integer: The desired number of class intervals (n).
#' @param style_type character: The classification style ('jenks', 'quantile', 'equal', etc.).
#' @param rounded logical: If TRUE, the breaks are rounded to two decimal places.
#' @return numeric vector: A sorted vector of break values.
make_systematic_interval <- function(dataset_column_input, amount_intervals, style_type, rounded) {
  
  dataset_column_input <- dataset_column_input[!is.na(dataset_column_input)]
  if (length(dataset_column_input) == 0) return(numeric(0)) 
  
  unique_vals <- unique(dataset_column_input)
  # Handle single unique value case (required by classInt)
  if (length(unique_vals) == 1) {
    padding <- abs(unique_vals * 0.01); if(padding == 0) padding <- 0.1
    return(sort(c(unique_vals-padding, unique_vals+padding)))
  }
  
  # Calculate class intervals using classInt::classIntervals
  cf <- classInt::classIntervals(dataset_column_input, n = amount_intervals, style = style_type)
  
  if (rounded) {
    return(round(cf$brks, 2))
  } else {
    return(cf$brks)
  }
}

# --------------------------------------------------------------------------- #

#' Areal Interpolation Wrapper
#' 
#' Performs areal interpolation (dasymetric mapping) using the 'areal' package 
#' to estimate a population count ('estPopCor') and density ('densKm2') for 
#' target geometries based on source geometries and population data.
#'
#' @param source_data sf object: The source features (e.g., ancillary/CORINE data) containing population estimates.
#' @param sid_input character: Name of the unique ID column in the source data.
#' @param target_data sf object: The target features (e.g., LAU or Subbasins) to receive population estimates.
#' @param tid_input character: Name of the unique ID column in the target data.
#' @param areaKm2_column character: Name of the column in the target data containing the area in square kilometers.
#' @return sf object: The target data augmented with 'estPopCor' (estimated population) and 'densKm2' (estimated density).
areal_interpolation_wrapper <- function(source_data, sid_input, target_data, tid_input, areaKm2_column) {
  
  catch <- target_data
  
  # Perform interpolation using aw_interpolate (areal package)
  catch_with_pop <- tryCatch({
    areal::aw_interpolate(
      .data = catch,
      tid = !!rlang::sym(tid_input),
      source = source_data,
      sid = !!rlang::sym(sid_input),
      weight = "sum",
      output = "sf",
      extensive = "estPopCor" # Extensive variable (count) to be calculated
    )
  }, error = function(e){
    message("Error during areal interpolation:")
    message(e$message)
    catch$estPopCor <- NA_real_
    return(catch)
  })
  
  # Ensure the estimated population column exists, setting missing values to 0
  if (!"estPopCor" %in% names(catch_with_pop)) {
    catch_with_pop$estPopCor <- NA_real_
    message("Warning: 'estPopCor' column not created by interpolation. Setting to NA.")
  } else {
    catch_with_pop$estPopCor[is.na(catch_with_pop$estPopCor)] <- 0
  }
  
  # Calculate Population Density (estPopCor / AreaKm2)
  catch_with_pop$densKm2 <- NA_real_
  valid_area <- !is.na(catch_with_pop[[areaKm2_column]]) & catch_with_pop[[areaKm2_column]] > 0
  
  if (any(valid_area)) {
    catch_with_pop$densKm2[valid_area] <- catch_with_pop$estPopCor[valid_area] / catch_with_pop[[areaKm2_column]][valid_area]
  }
  
  return(catch_with_pop)
}