#!/usr/bin/env Rscript

################################################################################
# MODULE: Interpolate Population to Subbasins (Analysis Step 3)
#
# Performs areal interpolation using the ancillary data (weighted CORINE 
# segments) to estimate the population and density for the final target 
# geometries: the detailed ECRINS Subbasins.
#
# Compliant with D2K Toolbox requirements: Contains one self-contained, 
# reusable function and an executable wrapper that processes command-line arguments.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(dplyr)
library(areal)
library(rlang)
library(units)

# --- 2. SOURCE HELPER FUNCTIONS ---
# Relies on areal_interpolation_wrapper defined in utils.R
source("src/utils.R") 

# --- 3. GLOBAL SETTINGS ---
# Disable scientific notation and set digits for consistent output
options(scipen = 100, digits = 4)

# --- 4. REUSABLE FUNCTION DEFINITION ---
################################################################################

#' Interpolate Population to Subbasin Boundaries
#' 
#' Estimates population and density for subbasin geometries using areal 
#' interpolation from dasymetrically refined ancillary data. The subbasin 
#' geometry is read directly from the provided URL/path.
#'
#' @param subbasin_url character: URL or path to the detailed subbasin geometry file (target data).
#' @param ancillary_data_sf sf object: Source data (CORINE-NUTS segments) with 
#'        the estimated population column ('estPopCor').
#' @return sf object: Subbasin data augmented with estimated population ('estPopCor') 
#'         and density ('densKm2').
interpolate_population_to_subbasins <- function(subbasin_url, ancillary_data_sf) {
  
  message("Starting interpolation to ECRINS Subbasins...")
  
  # Read the subbasin geometries from the URL/path (Input-side I/O)
  catch_ecrins_detailed <- sf::st_read(subbasin_url, quiet = TRUE) 
  
  # Calculate area in km^2
  catch_ecrins_detailed$AreaKm2 <- as.numeric(units::set_units(sf::st_area(catch_ecrins_detailed), "km^2"))
  
  # Perform areal interpolation using the helper wrapper
  subcatch_ecrins_with_pop <- areal_interpolation_wrapper(
    source_data = ancillary_data_sf,
    sid_input = "nuts_cor_int_id", # Unique ID column in ancillary data
    target_data = catch_ecrins_detailed,
    tid_input = "OBJECTID",       # Unique ID column in subbasin data
    areaKm2_column = "AreaKm2"
  )
  
  message("Subbasin interpolation complete.")
  return(subcatch_ecrins_with_pop)
}

################################################################################
# --- 5. D2K EXECUTABLE WRAPPER ---
################################################################################

# The wrapper handles command-line arguments, file I/O, and error handling.
args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/process_interpolate_subbasins.R <in_ancillary_data_path> <subbasin_url> <out_subbasin_pop_path>\n
  <in_ancillary_data_path>: Path to the local ancillary data (.gpkg from Step 5)
  <subbasin_url>: URL or path to the target subbasin geometry file
  <out_subbasin_pop_path>: Path for the final output (.gpkg, e.g., /out/subbasin_population_density.gpkg)", 
       call. = FALSE)
}

# Assign arguments following the strict order defined in the Usage string
path_ancillary <- args[1] 
url_subbasin   <- args[2]
output_path    <- args[3]

message(paste("D2K Wrapper Started. Output file:", output_path))

tryCatch({
  
  # Read the local input file (ancillary data) for the main function
  ancillary_data_sf <- sf::st_read(path_ancillary, quiet = TRUE)
  
  message("Running interpolate_population_to_subbasins function...")
  
  subbasin_pop_sf <- interpolate_population_to_subbasins(
    subbasin_url = url_subbasin, # Passes the URL directly to the function
    ancillary_data_sf = ancillary_data_sf
  )
  
  # Write the final result (Output-side I/O)
  message(paste("Saving Subbasin population data to", output_path))
  sf::st_write(subbasin_pop_sf, output_path, delete_layer = TRUE, quiet = TRUE)
  
  message("D2K Wrapper Finished. Subbasin data saved.")
  
}, error = function(e) {
  # Standardized error handling for the D2K process
  stop(paste("Error during script execution (process_interpolate_subbasins.R):", e$message), call. = FALSE)
})