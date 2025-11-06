# run_workflow.ps1

Write-Host "--- Step 1: Fetch NUTS and Eurostat Data ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=combine_eurostat_data.R d2k-toolbox "DE" "/out/nuts3_pop_data.gpkg"

Write-Host "--- Step 2: Calculate Population Weights ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=weighting_functions.R d2k-toolbox "https://aquainfra-aau.a3s.fi/elbe/cor2018DE_catchSE.tif" "https://aquainfra-aau.a3s.fi/elbe/censusDE_catchSE.gpkg" "https://aquainfra-aau.a3s.fi/elbe/cor2018DE_catchSE.tif.vat.dbf" "/out/weight_table.csv" "/out/weight_table.rds"

Write-Host "--- Step 3: Clean Catchment Geometries ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=clean_catchment_geometry.R d2k-toolbox "https://aquainfra-aau.a3s.fi/elbe/catchsub_ecrins_northsea_elbeSE.gpkg" "/out/catchment_cleaned.gpkg"

Write-Host "--- Step 4: Filter and Clip All Data to Analysis Extent ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=filter_clip_clean_extent.R d2k-toolbox "/out/nuts3_pop_data.gpkg" "https://aquainfra-aau.a3s.fi/elbe/LAUpop2018DE.gpkg" "https://aquainfra-aau.a3s.fi/elbe/catchsub_ecrins_northsea_elbeSE.gpkg" "/out/nuts3_filtered.gpkg" "/out/lau_processed.gpkg" "/out/analysis_extent.gpkg"

Write-Host "--- Step 5: Perform Dasymetric Refinement (Core Step) ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=process_dasymetric_refinement.R d2k-toolbox "/out/nuts3_filtered.gpkg" "/out/weight_table.rds" "/out/analysis_extent.gpkg" "https://aquainfra-aau.a3s.fi/elbe/corDE_nutsSE.gpkg" "/out/ancillary_data.gpkg"

Write-Host "--- Step 6: Interpolate Population to LAU ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=process_interpolate_lau.R d2k-toolbox "/out/ancillary_data.gpkg" "/out/lau_processed.gpkg" "/out/lau_population_errors.gpkg"

Write-Host "--- Step 7: Interpolate Population to Subbasins ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=process_interpolate_subbasins.R d2k-toolbox "/out/ancillary_data.gpkg" "/out/catchment_cleaned.gpkg" "/out/subbasin_population_density.gpkg"

Write-Host "--- Step 8: Create Final Visualizations ---"
docker run -it --rm -v ./out:/out -e R_SCRIPT=process_create_visualizations.R d2k-toolbox "/out/weight_table.rds" "/out/lau_population_errors.gpkg" "/out/subbasin_population_density.gpkg" "/out/visual_weight_table.csv" "/out/visual_lau_error_map.html" "/out/visual_subbasin_density_map.html"

Write-Host "--- Workflow Complete ---"