# Deployment

Merret Buurman, IGB Berlin, 2025-11-19

Add to `pygeoapi-config.yml`:

```
    combine-eurostat-data:
        type: process
        processor:
            name: CombineEurostatDataProcessor

    weighting-functions:
        type: process
        processor:
            name: WeightingFunctionsProcessor

    clean-catchment-geometry:
        type: process
        processor:
            name: CleanCatchmentGeometryProcessor

    filter-clip-clean-extent:
        type: process
        processor:
            name: FilterClipCleanExtentProcessor

    process-create-visualizations:
        type: process
        processor:
            name: ProcessCreateVisualizationsProcessor

    process-dasymetric-refinement:
        type: process
        processor:
            name: ProcessDasymetricRefinementProcessor

    process-interpolate-lau:
        type: process
        processor:
            name: ProcessInterpolateLauProcessor

    process-interpolate-subbasins:
        type: process
        processor:
            name: ProcessInterpolateSubbasinsProcessor
```

Add to `plugins.py`:

```
        'CombineEurostatDataProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.combine_eurostat_data.CombineEurostatDataProcessor',
        'WeightingFunctionsProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.weighting_functions.WeightingFunctionsProcessor',
        'CleanCatchmentGeometryProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.clean_catchment_geometry.CleanCatchmentGeometryProcessor',
        'FilterClipCleanExtentProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.filter_clip_clean_extent.FilterClipCleanExtentProcessor',
        'ProcessDasymetricRefinementProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.process_dasymetric_refinement.ProcessDasymetricRefinementProcessor',
        'ProcessInterpolateLauProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.process_interpolate_lau.ProcessInterpolateLauProcessor',
        'ProcessInterpolateSubbasinsProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.process_interpolate_subbasins.ProcessInterpolateSubbasinsProcessor',
        'ProcessCreateVisualizationsProcessor': 'pygeoapi.process.aquainfra-usecase-elbe.src.ogc.process_create_visualizations.ProcessCreateVisualizationsProcessor',
```
