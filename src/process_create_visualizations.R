#!/usr/bin/env Rscript

################################################################################
# MODULE: Visualization Functions (Final Step)
#
# Generates final output files (CSV table and HTML maps) using the results 
# of the dasymetric mapping workflow.
#
# OPTIMIZED: Uses 'leaflet' and 'htmlwidgets' for lightweight,
# self-contained interactive HTML maps without 'mapview' or browser dependencies.
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(dplyr)
library(leaflet)      # Use 'leaflet' for interactive maps
library(htmlwidgets)  # Use 'saveWidget' to save HTML
library(classInt)
library(RColorBrewer)
library(htmltools)    # For formatting HTML labels

# --- 2. SOURCE HELPER FUNCTIONS ---
source("src/utils.R") # For make_system_interval

# --- 3. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# --- 4. FUNCTION DEFINITIONS (Rewritten) ---
################################################################################

#' Save Weight Table to CSV
#' 
#' Reads the weight table from an RDS file and saves it as a user-friendly CSV.
#'
#' @param weight_table_rds_path character: Path to the input RDS file.
#' @param output_csv_path character: Path where the final CSV file will be saved.
#' @return invisible: Writes the file to disk.
save_weight_table_csv <- function(weight_table_rds_path, output_csv_path) {
  message(paste("Saving weight table to", output_csv_path))
  weight_table_df <- readRDS(weight_table_rds_path)
  write.csv(weight_table_df, output_csv_path, row.names = FALSE)
}

#' Generate and Save LAU Error Map (Interactive HTML)
#' 
#' Creates a lightweight, interactive HTML map visualizing the absolute 
#' percentage error for LAU units.
#'
#' @param estimated_lau_pop_sf sf object: LAU data with 'pop2018dif_percent_abs' column.
#' @param output_path character: Path where the final HTML map will be saved.
#' @return invisible: Writes the map to disk as an HTML file.
save_lau_error_map <- function(estimated_lau_pop_sf, output_path) {
  message(paste("Generating LAU error map for", output_path))
  
  # --- Classification logic ---
  classification_values <- c(0, 5, 10, 15, 20, 30, 50, 60, 70, 80, 90, 100)
  max_error <- max(estimated_lau_pop_sf$pop2018dif_percent_abs, na.rm = TRUE)
  if (is.finite(max_error) && max_error > 100) {
    classification_values[length(classification_values)] <- ceiling(max_error)
  }
  
  colors_dif <- c("white", "#f7fbff", "#deebf7", "#B2DDFC", "#9ecae1","#6baed6", 
                  "#2171b5","#084594", "#8734ba", "#5e1989", "#450d68", "#170224")
  
  # Create color palette function
  pal <- colorBin(colors_dif, domain = estimated_lau_pop_sf$pop2018dif_percent_abs, bins = classification_values, na.color = "#808080")
  
  # Transform to 4326 and create a clean HTML label
  map_data <- sf::st_transform(estimated_lau_pop_sf, 4326) %>%
    dplyr::mutate(
      label_html = lapply(paste(
        "<strong>LAU ID:</strong>", LAU_ID, "<br/>",
        "<strong>Error:</strong>", ifelse(is.na(pop2018dif_percent_abs), "N/A", sprintf("%.2f", pop2018dif_percent_abs)), "%"
      ), htmltools::HTML)
    )
  
  # Generate the leaflet map
  map_widget <- leaflet(data = map_data) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addPolygons(
      fillColor = ~pal(pop2018dif_percent_abs), 
      weight = 1,
      opacity = 1,
      color = "white",
      fillOpacity = 0.7,
      label = ~label_html 
    ) %>%
    addLegend(
      pal = pal,
      values = ~pop2018dif_percent_abs, 
      opacity = 0.7,
      title = "Errors in % (Absolute)",
      position = "bottomright"
    )
  
  message("Saving LAU map as self-contained HTML...")
  saveWidget(map_widget, file = output_path, selfcontained = TRUE)
}

#' Generate and Save Subbasin Density Map (Interactive HTML)
#' 
#' Creates a lightweight, interactive HTML map visualizing the estimated 
#' population density for the final subbasin geometries.
#'
#' @param subcatch_ecrins_with_pop_sf sf object: Subbasin data with 'densKm2' column.
#' @param output_path character: Path where the final HTML map will be saved.
#' @return invisible: Writes the map to disk as an HTML file.
save_subbasin_density_map <- function(subcatch_ecrins_with_pop_sf, output_path) {
  message(paste("Generating Subbasin density map for", output_path))
  
  density_data <- subcatch_ecrins_with_pop_sf$densKm2
  max_density <- max(density_data, na.rm = TRUE) # Get the true maximum
  density_data <- density_data[is.finite(density_data) & density_data > 0]
  
  if(length(density_data) > 0) {
    classification_values <- make_systematic_interval(density_data, 8, "jenks", TRUE)
    min_break_positive <- min(classification_values[classification_values > 0], na.rm = TRUE)
    if (is.finite(min_break_positive) && 0.01 < min_break_positive) {
      classification_values <- c(0.01, classification_values)
    }
    classification_values <- sort(unique(classification_values[is.finite(classification_values)]))
    
    # (FIX) Ensure the final break covers the actual maximum value
    if (classification_values[length(classification_values)] < max_density) {
      classification_values[length(classification_values)] <- ceiling(max_density) 
    }
    
    if(length(classification_values) < 2) classification_values <- c(0, 1)
  } else {
    classification_values <- c(0, 1)
  }
  
  # Create color palette function
  pal <- colorBin("YlOrRd", domain = subcatch_ecrins_with_pop_sf$densKm2, bins = classification_values, na.color = "#808080")
  
  # Transform to 4326 and create a clean HTML label
  map_data <- sf::st_transform(subcatch_ecrins_with_pop_sf, 4326) %>%
    dplyr::mutate(
      label_html = lapply(paste(
        "<strong>ObjectID:</strong>", OBJECTID, "<br/>",
        "<strong>Density:</strong>", ifelse(is.na(densKm2), "N/A", sprintf("%.2f", densKm2)), "/km²"
      ), htmltools::HTML)
    )
  
  # Generate the leaflet map
  map_widget <- leaflet(data = map_data) %>%
    addProviderTiles(providers$CartoDB.Positron) %>%
    addPolygons(
      fillColor = ~pal(densKm2),
      weight = 1,
      opacity = 1,
      color = "white",
      fillOpacity = 0.7,
      label = ~label_html 
    ) %>%
    addLegend(
      pal = pal,
      values = ~densKm2,
      opacity = 0.7,
      title = "Population Density (est./km²)",
      position = "bottomright"
    )
  
  message("Saving Subbasin map as self-contained HTML...")
  saveWidget(map_widget, file = output_path, selfcontained = TRUE)
}

################################################################################
# --- 5. D2K EXECUTABLE WRAPPER ---
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 6) {
  stop("Usage: Rscript src/process_create_visualizations.R <in_weight_table_rds> <in_lau_errors> <in_subbasin_pop> <out_table_csv> <out_lau_map_html> <out_subbasin_map_html>", call. = FALSE)
}

# Assign arguments
path_weight_table_rds <- args[1] 
path_lau_errors       <- args[2]
path_subbasin_pop     <- args[3]
output_csv            <- args[4]
output_html_lau       <- args[5] 
output_html_sub       <- args[6] 

message("D2K Wrapper Started. Reading files for visualization...")

tryCatch({
  
  lau_errors_sf <- sf::st_read(path_lau_errors)
  subbasin_pop_sf <- sf::st_read(path_subbasin_pop)
  
  # Run all visualization functions
  save_weight_table_csv(path_weight_table_rds, output_csv)
  save_lau_error_map(lau_errors_sf, output_html_lau)
  save_subbasin_density_map(subbasin_pop_sf, output_html_sub)
  
  message("D2K Wrapper Finished. All visualization files (CSV, HTMLs) saved.")
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})