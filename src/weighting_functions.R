#!/usr/bin/env Rscript

################################################################################
# MODULE: WEIGHTING FUNCTIONS (CHAPTER 5)
#
# Calculates the population weights (percent contribution) for CORINE land 
# cover classes based on overlap with the 1km European Census Grid.
# It uses two methods (F1: All Overlaps, F2: Full Overlaps) and averages 
# the results to create the final weight table.
################################################################################

# --- 1. DEPENDENCIES ---
library(terra)   # For raster analysis
library(sf)      # For vector analysis
library(dplyr)   # For data manipulation
library(foreign) # For reading .dbf (dBase) files

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4) # Disable scientific notation

# --- 3. FUNCTION DEFINITION (Corrected) ---
################################################################################

#' Calculate Population Weights for CORINE Classes
#' 
#' Implements the two-step weighting method (F1 and F2) for dasymetric mapping. 
#' Downloads required large files (raster, grid, legend) to temporary storage, 
#' calculates zonal statistics, combines the F1 and F2 weights, and returns 
#' a final, filtered weight table.
#'
#' @param corine_raster_url character: URL to the CORINE raster file (.tif).
#' @param census_grid_url character: URL to the census population grid file (.gpkg).
#' @param corine_legend_url character: URL to the CORINE legend file (.dbf).
#' @return data.frame: A detailed weight table filtered to classes with a final weight >= 1.0.
calculate_population_weights <- function(corine_raster_url, census_grid_url, corine_legend_url) {
  
  message("Starting population weight calculation (Ground Truth Logic)...")
  
  # --- Download large files to temporary local files ---
  message("Downloading large files for weighting to temp storage...")
  
  # Create temp files
  temp_cor_raster <- tempfile(fileext = ".tif")
  temp_census_grid <- tempfile(fileext = ".gpkg")
  temp_cor_legend <- tempfile(fileext = ".dbf")
  
  # Download Corine Raster
  tryCatch({
    download.file(url = corine_raster_url, destfile = temp_cor_raster, mode = "wb", quiet = TRUE)
  }, error = function(e) {stop("Failed to download Corine Raster: ", e$message)})
  
  # Download Census Grid
  tryCatch({
    download.file(url = census_grid_url, destfile = temp_census_grid, mode = "wb", quiet = TRUE)
  }, error = function(e) {stop("Failed to download Census Grid: ", e$message)})
  
  # Download Corine Legend
  tryCatch({
    download.file(url = corine_legend_url, destfile = temp_cor_legend, mode = "wb", quiet = TRUE)
  }, error = function(e) {stop("Failed to download Corine Legend: ", e$message)})
  
  message("Downloads complete. Loading data...")
  
  # --- Load Data from TEMPORARY files ---
  cor2018_country_r <- terra::rast(temp_cor_raster)
  census_grid_country <- sf::st_read(temp_census_grid, quiet = TRUE)
  corlegend <- foreign::read.dbf(temp_cor_legend)
  
  # Clean up legend data types
  corlegend$CODE_18 <- as.integer(as.character(corlegend$CODE_18))
  corlegend$Value <- as.integer(corlegend$Value) # 'Value' is the raster pixel value
  
  
  # --- Start Ground Truth Processing (Chapter 5) ---
  
  ## Weighting step 1: F1 (All Overlaps)
  message("Running Weighting Step 1 (F1 - All Overlaps)...")
  
  # Get raster 'Value' for urban/artificial classes (1xx)
  cor_urban_values <- corlegend$Value[corlegend$CODE_18 >= 100 & corlegend$CODE_18 < 200]
  
  # Create a mask of only urban areas
  mask_cor_logical <- cor2018_country_r[] %in% cor_urban_values
  mask_cor_raster <- terra::setValues(terra::rast(cor2018_country_r), mask_cor_logical)
  cor2018_artificial <- terra::mask(cor2018_country_r, mask_cor_raster, maskvalue = FALSE)
  
  # Convert census polygons to terra vector
  census_grid_country_vector <- terra::vect(census_grid_country)
  
  # Count how many 100x100m CORINE pixels are in each 1km census grid cell
  counts <- terra::extract(cor2018_artificial, 
                           census_grid_country_vector, 
                           fun = function(x, ...) sum(!is.na(x)), 
                           touches = TRUE) 
  
  census_grid_country_vector$count_corine_pixels <- counts[,2]
  
  # Rasterize the counts
  count_raster <- terra::rasterize(census_grid_country_vector, 
                                   cor2018_artificial, 
                                   field = "count_corine_pixels")
  
  # Rasterize the population data
  census_raster <- terra::rasterize(census_grid_country_vector, 
                                    cor2018_artificial, 
                                    field = "T", # 'T' is the population column
                                    fun = "max")
  
  # Remove population from census cells that have no urban CORINE pixels
  census_raster[count_raster == 0] <- NA
  # Correct the population by dividing by the number of pixels
  census_raster_correctedF1 <- census_raster / count_raster
  
  # Mask the CORINE raster to match the corrected census raster
  cor2018_country_maskedF1 <- terra::mask(cor2018_artificial, census_raster_correctedF1)
  
  # Calculate average population per CORINE class
  avg_pop_per_corineF1 <- terra::zonal(census_raster_correctedF1, 
                                       cor2018_country_maskedF1, 
                                       fun = "mean",  
                                       na.rm = TRUE)
  
  # Calculate F1 percentage
  total_avg_sumF1 <- sum(avg_pop_per_corineF1$T, na.rm = TRUE)
  avg_pop_per_corineF1$percentF1 <- round(avg_pop_per_corineF1$T / total_avg_sumF1 * 100, 2)
  
  
  ## Weighting step 2: F2 (Full Overlaps)
  message("Running Weighting Step 2 (F2 - Full Overlaps)...")
  
  census_grid_country_vector <- terra::vect(census_grid_country) # Reset vector
  
  # Count *unique* CORINE classes in each census grid cell
  count_unique_corine_classes <- terra::extract(cor2018_country_r, 
                                                census_grid_country_vector,
                                                fun = function(x, ...) length(unique(x)), 
                                                touches = TRUE)
  
  census_grid_country_vector$unique_corine_classes <- count_unique_corine_classes[,2]  
  # Keep only cells that are 100% one class
  census_grid_country_vector$unique_corine_classes[census_grid_country_vector$unique_corine_classes != 1] <- NA
  
  # Create a mask of only these "pure" cells
  mask_logical_full_raster <- terra::rasterize(census_grid_country_vector, 
                                               cor2018_artificial, 
                                               field = "unique_corine_classes", 
                                               fun = "min")
  
  # Rasterize population again
  census_rasterF2 <- terra::rasterize(census_grid_country_vector, 
                                      cor2018_country_r, 
                                      field = "T", 
                                      fun = "max") 
  
  # Correct population: 1km grid (1000m) vs 100m CORINE = 100 pixels
  census_raster_correctedF2 <- census_rasterF2 / 100
  
  # Apply the "pure" cell mask
  census_raster_correctedF2 <- terra::mask(census_raster_correctedF2, 
                                           mask_logical_full_raster, 
                                           maskvalue = NA)
  
  cor2018_country_maskedF2 <- terra::mask(cor2018_artificial, 
                                          census_raster_correctedF2)
  
  # Calculate zonal stats for F2
  avg_pop_per_corineF2 <- terra::zonal(census_raster_correctedF2, 
                                       cor2018_country_maskedF2, 
                                       fun = "mean", 
                                       na.rm = TRUE)
  
  # Calculate F2 percentage
  total_avg_sumF2 <- sum(avg_pop_per_corineF2$T, na.rm = TRUE)
  avg_pop_per_corineF2$percentF2 <- round(avg_pop_per_corineF2$T / total_avg_sumF2 * 100, 2)
  
  
  ## Statistics table combined: 
  message("Combining F1 and F2 weights...")
  
  # The column name 'zonal_col_name' is the raster value column (e.g., 'ID')
  zonal_col_name <- names(avg_pop_per_corineF1)[1] 
  
  # Join F1 and F2 tables by the raster value
  avg_pop_per_corine_combined <- avg_pop_per_corineF1 %>%
    dplyr::left_join(avg_pop_per_corineF2, by = zonal_col_name, suffix = c("_f1", "_f2"))
  
  # Handle 0 values from F2 (setting them to 0.1 for stability)
  if (any(avg_pop_per_corine_combined$percentF2 == 0, na.rm = TRUE)) {
    avg_pop_per_corine_combined$percentF2[avg_pop_per_corine_combined$percentF2 == 0] <- 0.1
  }
  
  # Calculate the final 'percent' weight (average of F1 and F2)
  avg_pop_per_corine_combined$percent <- apply(avg_pop_per_corine_combined[, c("percentF1", "percentF2")], 
                                               1, # apply over rows 
                                               function(x) {
                                                 if (all(!is.na(x))) {
                                                   return(mean(x, na.rm = TRUE))
                                                 } else {
                                                   return(na.omit(x)[1])
                                                 }
                                               })
  
  # Join with corlegend using 'Value' (raster value) and the zonal column name
  # This brings in ALL columns from the legend (CODE_18, LABEL1, LABEL2, etc.)
  weight_table_full <- avg_pop_per_corine_combined %>%
    dplyr::left_join(corlegend, by = setNames("Value", zonal_col_name))
  
  # The result is the full detailed table.
  weight_table <- weight_table_full
  
  # Filter to only keep rows where the final weight is >= 1.0
  weight_table_final <- weight_table %>%
    dplyr::filter(percent >= 1.0)
  
  message("Weight calculation complete.")
  
  # Clean up temp files
  file.remove(temp_cor_raster, temp_census_grid, temp_cor_legend)
  message("Temporary files cleaned up.")
  
  # Return the final, filtered, DETAILED table
  return(weight_table_final)
}

################################################################################
# --- 4. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 5) {
  # Updated Usage message
  stop("Usage: Rscript src/weighting_functions.R <corine_raster_url> <census_grid_url> <corine_legend_url> <output_csv_path> <output_rds_path>", call. = FALSE)
}

# Assign arguments
url_cor_raster    <- args[1]
url_census_grid   <- args[2]
url_cor_legend    <- args[3]
output_csv_path   <- args[4]
output_rds_path   <- args[5]


message(paste("D2K Wrapper Started. CSV output:", output_csv_path, "RDS output:", output_rds_path))

tryCatch({
  
  # Run the main function
  weight_table_result <- calculate_population_weights(
    corine_raster_url = url_cor_raster,
    census_grid_url = url_census_grid,
    corine_legend_url = url_cor_legend
  )
  
  # Save as .csv for user 
  write.csv(weight_table_result, file = output_csv_path, row.names = FALSE)
  
  # Save as .rds for machine/subsequent steps
  saveRDS(weight_table_result, file = output_rds_path)
  
  message("D2K Wrapper Finished. Detailed weight table successfully saved to CSV and RDS.")
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})