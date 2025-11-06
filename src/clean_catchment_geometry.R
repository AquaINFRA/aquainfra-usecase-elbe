#!/usr/bin/env Rscript

################################################################################
# MODULE: Clean Catchment Geometry
#
# Reads a detailed catchment geometry file (e.g., ECRINS subbasins) and 
# performs necessary geometric cleaning, validation, and type casting for 
# reliable use in subsequent spatial operations like intersection and interpolation.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
################################################################################

#' Preprocess and Clean Catchment Geometry
#' 
#' Reads an input geometry file, validates/fixes invalid geometries, removes empty 
#' geometries, and casts all features to MULTIPOLYGON for consistency.
#'
#' @param catchment_detailed_url character: URL or path to the detailed catchment geometry file.
#' @return sf object: A cleaned sf object containing only valid MULTIPOLYGON geometries.
preprocess_catchment_geometry <- function(catchment_detailed_url) {
  
  message("Reading detailed catchment data from URL/path...")
  catchment_sf <- sf::st_read(catchment_detailed_url)
  
  # Fix catchment geometry if needed (e.g., self-intersections)
  valid_geoms <- sf::st_is_valid(catchment_sf)
  if (any(!valid_geoms)) {
    message("Fixing invalid catchment geometries...")
    catchment_sf[!valid_geoms, ] <- sf::st_make_valid(catchment_sf[!valid_geoms, ])
  }
  
  # Remove empty or NULL geometries
  catchment_sf <- catchment_sf[!sf::st_is_empty(catchment_sf), ]
  
  # Extract only POLYGON or MULTIPOLYGON types
  catchment_sf <- catchment_sf[sf::st_geometry_type(catchment_sf) %in% c("POLYGON", "MULTIPOLYGON"), ]
  
  # Cast all to MULTIPOLYGON for consistency (required for some functions)
  if (nrow(catchment_sf) > 0) {
    catchment_sf <- sf::st_cast(catchment_sf, "MULTIPOLYGON")
  } else {
    stop("No valid POLYGON or MULTIPOLYGON geometries found in catchment data.")
  }
  
  message("Catchment geometry preprocessing complete.")
  return(catchment_sf)
}

################################################################################
# --- 4. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 2) {
  stop("Usage: Rscript src/clean_catchment_geometry.R <catchment_detailed_url> <output_gpkg_path>", call. = FALSE)
}

# Assign arguments
url_catchment   <- args[1]
output_path     <- args[2]

message(paste("D2K Wrapper Started. Output will be saved to:", output_path))

tryCatch({
  
  cleaned_geometry_sf <- preprocess_catchment_geometry(
    catchment_detailed_url = url_catchment
  )
  
  # Save the output
  sf::st_write(cleaned_geometry_sf, output_path, delete_layer = TRUE, quiet = TRUE)
  
  message(paste("D2K Wrapper Finished. Cleaned geometry saved to", output_path))
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})