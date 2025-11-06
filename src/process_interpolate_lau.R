#!/usr/bin/env Rscript

################################################################################
# MODULE: Interpolate Population to LAU (Analysis Step 2)
#
# Uses the ancillary data (weighted CORINE segments) as the source for areal 
# interpolation to estimate the population for the LAU (Local Administrative 
# Units) target geometries. Calculates population error metrics (difference, 
# percentage) against the ground truth LAU population.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(dplyr)
library(areal)
library(rlang)

# --- 2. SOURCE HELPER FUNCTIONS ---
# This script relies on functions defined in utils.R, specifically the 
# areal_interpolation_wrapper.
source("src/utils.R") 

# --- 3. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 4. FUNCTION DEFINITION (Corrected) ---
################################################################################

#' Interpolate Population to LAU Boundaries
#' 
#' Estimates population for LAU geometries using areal interpolation from 
#' dasymetrically refined ancillary data. Calculates error metrics for validation.
#'
#' @param ancillary_data_sf sf object: Source data (CORINE-NUTS segments) with estimated population ('estPopCor').
#' @param laupop_sf sf object: Target data (LAU geometries) with ground truth population ('POP_2018').
#' @return sf object: LAU data augmented with estimated population, density, and error columns.
interpolate_population_to_lau <- function(ancillary_data_sf, laupop_sf) {
  
  message("Interpolating population to LAU (Ground Truth Logic)...")
  
  # Calculate area of LAU units in km^2
  laupop_sf$AREA_KM2 <- as.numeric(units::set_units(sf::st_area(laupop_sf), "km^2"))
  
  # Call wrapper from utils.R
  estimated_lau_pop <- areal_interpolation_wrapper(
    source_data = ancillary_data_sf,
    sid_input = "nuts_cor_int_id", # Use unique ID from ancillary data as source ID
    target_data = laupop_sf,
    tid_input = "LAU_ID",         # Use LAU_ID as the target ID
    areaKm2_column = "AREA_KM2"
  )
  
  # Calculate differences (Error)
  # Assumes 'POP_2018' is the ground truth column
  estimated_lau_pop$pop2018dif <- (estimated_lau_pop$estPopCor - estimated_lau_pop$POP_2018)
  estimated_lau_pop$pop2018dif_percent <- ( (estimated_lau_pop$estPopCor - estimated_lau_pop$POP_2018) / estimated_lau_pop$POP_2018) * 100.
  
  # Clean geometries (casting to ensure consistency)
  estimated_lau_pop <- estimated_lau_pop[sf::st_geometry_type(estimated_lau_pop) %in% c("POLYGON", "MULTIPOLYGON"), ]
  if (nrow(estimated_lau_pop) > 0) {
    estimated_lau_pop <- sf::st_collection_extract(estimated_lau_pop, "POLYGON")
    estimated_lau_pop <- sf::st_cast(estimated_lau_pop, "MULTIPOLYGON")
  }
  
  # Calculate absolute difference and estimated density
  estimated_lau_pop$pop2018dif_abs <- abs(estimated_lau_pop$pop2018dif)
  # (FIX ADDED) Calculate the absolute PERCENTAGE error for visualization
  estimated_lau_pop$pop2018dif_percent_abs <- abs(estimated_lau_pop$pop2018dif_percent)
  
  estimated_lau_pop$densKm2Est <- as.numeric(estimated_lau_pop$estPopCor) / estimated_lau_pop$AREA_KM2 
  
  message("LAU interpolation complete.")
  return(estimated_lau_pop)
}

################################################################################
# --- 5. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
  stop("Usage: Rscript src/process_interpolate_lau.R <in_ancillary_data_path> <in_lau_processed_path> <out_lau_errors_path>", call. = FALSE)
}

# Assign arguments
path_ancillary <- args[1]
path_lau       <- args[2]
output_path    <- args[3]

message("D2K Wrapper Started. Reading input files for LAU interpolation...")

tryCatch({
  
  ancillary_data_sf <- sf::st_read(path_ancillary)
  laupop_sf <- sf::st_read(path_lau)
  
  message("Running interpolate_population_to_lau...")
  
  estimated_lau_pop_sf <- interpolate_population_to_lau(
    ancillary_data_sf = ancillary_data_sf,
    laupop_sf = laupop_sf
  )
  
  message(paste("Saving LAU population error data to", output_path))
  sf::st_write(estimated_lau_pop_sf, output_path, delete_layer = TRUE, quiet = TRUE)
  
  message("D2K Wrapper Finished. LAU data saved.")
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})