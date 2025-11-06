#!/usr/bin/env Rscript

################################################################################
# MODULE: Filter, Clip, and Clean Data by Analysis Extent
#
# NEW: D2K wrapper added.
# NEW: Function now saves 3 distinct output files.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(dplyr)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 3. FUNCTION DEFINITION (Original Code) ---
################################################################################

filter_and_clean_by_extent <- function(nuts3pop_country_sf, lau_url, catchment_rough_url) {
  
  message("Reading LAU data from URL/path...")
  lau_sf <- sf::st_read(lau_url)
  message("Reading rough catchment data from URL/path...")
  catchment_rough_sf <- sf::st_read(catchment_rough_url)
  
  # FUNCTION: SELECT DATA WITHIN ANALYSIS EXTENT
  
  # 1. Define Analysis Extent
  message("Defining analysis extent...")
  nuts3_indices_intersect <- sf::st_intersects(nuts3pop_country_sf, catchment_rough_sf, sparse = FALSE)
  nuts3pop_analysis_extent <- nuts3pop_country_sf[apply(nuts3_indices_intersect, 1, any), ]
  
  analysis_extent_geom <- sf::st_union(nuts3pop_analysis_extent)
  analysis_extent_geom <- sf::st_make_valid(analysis_extent_geom)
  
  message(paste("Analysis extent defined. Intersecting", nrow(nuts3pop_analysis_extent), "NUTS3 regions."))
  
  # 2. Process LAU Data
  message("Filtering LAU data by analysis extent...")
  lau_indices_intersect <- sf::st_intersects(lau_sf, analysis_extent_geom, sparse = FALSE)
  LAUpop2018_filtered <- lau_sf[apply(lau_indices_intersect, 1, any), ]
  
  message("Clipping LAU data (this may take a moment)...")
  LAUpop2018_processed <- sf::st_intersection(LAUpop2018_filtered, analysis_extent_geom)
  
  # Clean geometries
  if (nrow(LAUpop2018_processed) > 0) {
    valid_geoms <- sf::st_is_valid(LAUpop2018_processed)
    if (any(!valid_geoms)) {
      message("Fixing invalid LAU geometries after intersection...")
      LAUpop2018_processed[!valid_geoms, ] <- sf::st_make_valid(LAUpop2018_processed[!valid_geoms, ])
    }
    LAUpop2018_processed <- LAUpop2018_processed[!sf::st_is_empty(LAUpop2018_processed), ]
    
    geom_types <- sf::st_geometry_type(LAUpop2018_processed)
    keep_geoms <- geom_types %in% c("POLYGON", "MULTIPOLYGON")
    if(any(!keep_geoms)){
      message("Removing non-polygon geometries after intersection...")
      LAUpop2018_processed <- LAUpop2018_processed[keep_geoms, ]
    }
    if (nrow(LAUpop2018_processed) > 0) {
      LAUpop2018_processed <- sf::st_cast(LAUpop2018_processed, "MULTIPOLYGON")
    } else {
      warning("LAU object became empty after geometry cleaning post-intersection.")
    }
    
  } else {
    warning("LAU object is empty after clipping.")
  }
  
  message("LAU data processing complete.")
  
  # 3. Return a list of the 3 required data objects
  return(list(
    nuts3pop = nuts3pop_analysis_extent,
    laupop = LAUpop2018_processed,
    analysis_extent = analysis_extent_geom
  ))
}

################################################################################
# --- 4. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 6) {
  stop("Usage: Rscript src/filter_clip_clean_extent.R <input_nuts3pop_path> <lau_url> <catchment_rough_url> <output_nuts3_path> <output_lau_path> <output_extent_path>", call. = FALSE)
}

# Assign arguments
path_nuts3pop       <- args[1] # e.g., "/out/nuts3_pop_DE.gpkg"
url_lau             <- args[2]
url_catchment_rough <- args[3]
output_path_nuts    <- args[4] # e.g., "/out/nuts3_filtered.gpkg"
output_path_lau     <- args[5] # e.g., "/out/lau_processed.gpkg"
output_path_extent  <- args[6] # e.g., "/out/analysis_extent.gpkg"

message("D2K Wrapper Started. Reading input NUTS data...")

tryCatch({
  
  nuts3pop_country_sf <- sf::st_read(path_nuts3pop)
  
  message("Running filter_and_clean_by_extent function...")
  
  result_list <- filter_and_clean_by_extent(
    nuts3pop_country_sf = nuts3pop_country_sf,
    lau_url = url_lau,
    catchment_rough_url = url_catchment_rough
  )
  
  message(paste("Saving filtered NUTS3 data to", output_path_nuts))
  sf::st_write(result_list$nuts3pop, output_path_nuts, delete_layer = TRUE, quiet = TRUE)
  
  message(paste("Saving processed LAU data to", output_path_lau))
  sf::st_write(result_list$laupop, output_path_lau, delete_layer = TRUE, quiet = TRUE)
  
  message(paste("Saving analysis extent data to", output_path_extent))
  sf::st_write(result_list$analysis_extent, output_path_extent, delete_layer = TRUE, quiet = TRUE)
  
  message("D2K Wrapper Finished. All 3 output files saved.")
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})