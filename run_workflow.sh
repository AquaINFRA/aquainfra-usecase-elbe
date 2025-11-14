#!/bin/bash
# D2K Workflow Execution Script (macOS/Linux Compatible)
# NOTE: This script assumes you have successfully built the 'aquainfra-elbe-usecase-image' image.

# Exit immediately if a command exits with a non-zero status
set -e

# Use $(pwd) for robust volume mapping on macOS/Linux
OUT_DIR=$(pwd)/out

mkdir -p $OUT_DIR
echo "--- Starting D2K Workflow ---"

# Step 1: Fetch NUTS and Eurostat Data
echo "--- Step 1: Fetch NUTS and Eurostat Data (DE) ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=combine_eurostat_data.R aquainfra-elbe-usecase-image "DE" "/out/nuts3_pop_data.gpkg"

# Step 2: Calculate Population Weights
echo "--- Step 2: Calculate Population Weights ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=weighting_functions.R aquainfra-elbe-usecase-image "https://aquainfra-aau.a3s.fi/elbe/cor2018DE_catchSE.tif" "https://aquainfra-aau.a3s.fi/elbe/censusDE_catchSE.gpkg" "https://aquainfra-aau.a3s.fi/elbe/cor2018DE_catchSE.tif.vat.dbf" "/out/weight_table.csv" "/out/weight_table.rds"

# Step 3: Clean Catchment Geometries
echo "--- Step 3: Clean Catchment Geometries ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=clean_catchment_geometry.R aquainfra-elbe-usecase-image "https://aquainfra-aau.a3s.fi/elbe/catchsub_ecrins_northsea_elbeSE.gpkg" "/out/catchment_cleaned.gpkg"

# Step 4: Filter and Clip All Data to Analysis Extent
echo "--- Step 4: Filter and Clip All Data to Analysis Extent ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=filter_clip_clean_extent.R aquainfra-elbe-usecase-image "/out/nuts3_pop_data.gpkg" "https://aquainfra-aau.a3s.fi/elbe/LAUpop2018DE.gpkg" "https://aquainfra-aau.a3s.fi/elbe/catchsub_ecrins_northsea_elbeSE.gpkg" "/out/nuts3_filtered.gpkg" "/out/lau_processed.gpkg" "/out/analysis_extent.gpkg"

# Step 5: Perform Dasymetric Refinement (Core Step)
echo "--- Step 5: Perform Dasymetric Refinement (Core Step) ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=process_dasymetric_refinement.R aquainfra-elbe-usecase-image "/out/nuts3_filtered.gpkg" "/out/weight_table.rds" "/out/analysis_extent.gpkg" "https://aquainfra-aau.a3s.fi/elbe/corDE_nutsSE.gpkg" "/out/ancillary_data.gpkg"

# Step 6: Interpolate Population to LAU
echo "--- Step 6: Interpolate Population to LAU ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=process_interpolate_lau.R aquainfra-elbe-usecase-image "/out/ancillary_data.gpkg" "/out/lau_processed.gpkg" "/out/lau_population_errors.gpkg"

# Step 7: Interpolate Population to Subbasins
echo "--- Step 7: Interpolate Population to Subbasins ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=process_interpolate_subbasins.R aquainfra-elbe-usecase-image "/out/ancillary_data.gpkg" "/out/catchment_cleaned.gpkg" "/out/subbasin_population_density.gpkg"

# Step 8: Create Final Visualizations
echo "--- Step 8: Create Final Visualizations ---"
docker run -it --rm -v $OUT_DIR:/out -e R_SCRIPT=process_create_visualizations.R aquainfra-elbe-usecase-image "/out/weight_table.rds" "/out/lau_population_errors.gpkg" "/out/subbasin_population_density.gpkg" "/out/visual_weight_table.csv" "/out/visual_lau_error_map.html" "/out/visual_subbasin_density_map.html"

echo "--- Workflow Complete ---"