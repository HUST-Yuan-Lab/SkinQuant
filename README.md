# README: SkinQuant - Quantitative 3D analysis of skin micro-holes and thermal damage based on fMOST

## Author

Wei Ni, Ting Zhu

## Introduction

This repository (SkinQuant) provides an automated quantitative analysis pipeline for skin fractional-laser micro-holes, thermal damage regions, and PI-positive nucleus-like objects based on fMOST three-dimensional fluorescence data. The inputs are ResUNet segmentation results (holes, damage regions, nucleus-like objects) and the raw grayscale volume data. The outputs are per-site (per data block/file) morphological parameters, angular distributions, and color-coded visualizations. The bundled dataset covers three fractional-laser energies (25, 75, and 150 mJ), with two example volumes per energy.

## System requirements

The software was developed and validated on MATLAB under Windows 10 / Windows 11. MATLAB R2025a is the development and validation version, and Image Processing Toolbox is required (`imgaussfilt`, `bwlabeln`, `bwconncomp`, `regionprops3`).

The input data are multi-page TIFF stacks (8-bit grayscale in the bundled dataset). The default voxel resolution is `[1.3, 1.3, 1.0]` μm (x, y, z), corresponding to a voxel volume of 1.69 μm³.

## Dataset

The bundled `Dataset/` folder contains six raw fMOST fluorescence volumes acquired at three fractional-laser energies, with two example volumes per energy. These volumes are a demonstration subset for exercising the workflow; they are not the complete 128-site dataset analysed in the article.

- `25mJ_12.tif`: 1000 × 1000 pixels, 311 slices (153 MB)
- `25mJ_33.tif`: 1000 × 1000 pixels, 289 slices (147 MB)
- `75mJ_27.tif`: 1500 × 1500 pixels, 359 slices (434 MB)
- `75mJ_34.tif`: 1500 × 1500 pixels, 352 slices (404 MB)
- `150mJ_23.tif`: 1000 × 1000 pixels, 499 slices (476 MB)
- `150mJ_31.tif`: 1000 × 1000 pixels, 552 slices (527 MB)

All files are 8-bit multi-page TIFF stacks, 2.1 GB in total. The file name follows `<energy>mJ_<sample>.tif`. These are raw grayscale volumes; the ResUNet segmentation results and damage-region annotations are not included and must be generated before running the full workflow. In the code, the three energy groups are referred to as `25mj`, `75mj`, and `150mj`.

## Installation guide

1. Download the repository.
2. Set the `SkinQuant` folder as the current working directory and run `init` (this adds `utils/`, `analysis/`, `visualization/`, and `extraction/` to the search path).
3. Edit `base_dir`, `datasets`, the parameters, and the `RUN_*` switches at the top of `main_workflow.m`, then run `main_workflow`.

The directory structure is as follows:

```
SkinQuant/
├── init.m                     # Path initialization (adds subfolders to the search path)
├── main_workflow.m            # Main workflow entry (6 steps controlled by switches)
├── Dataset/                   # Raw fMOST volumes (25mJ / 75mJ / 150mJ, two example volumes each)
│   ├── 25mJ_12.tif
│   ├── 25mJ_33.tif
│   ├── 75mJ_27.tif
│   ├── 75mJ_34.tif
│   ├── 150mJ_23.tif
│   └── 150mJ_31.tif
├── utils/                     # General algorithms
│   ├── read_tiff_stack.m      # Read a multi-page TIFF as a 3D matrix
│   ├── save_tiff_stack.m      # Save a 3D matrix as a multi-page TIFF
│   ├── skin_surface.m         # Threshold-based skin surface height map
│   ├── surface_normal.m       # ROI-level outward surface normal
│   ├── pca_analysis.m         # PCA (principal axis from surface normal / Y axis)
│   ├── cross_section.m        # Per-slice convex hull area/perimeter/max envelope radius along the main axis
│   ├── cell_angle.m           # Per-connected-component main-axis angle + angle distribution
│   ├── cell_morphology.m      # Per-site cell count/volume/density/fraction/sphericity
│   ├── largest_cc.m           # Keep the largest connected component
│   ├── central_region.m       # Central square ROI
│   └── bresenham_line.m       # 3D line voxelization (for drawing axes in visualizations)
├── analysis/                  # Batch processing and quantification
│   ├── batch_connectivity_filter.m
│   ├── batch_hole_quantity.m
│   ├── batch_surface_pca.m
│   ├── batch_cell_angle.m
│   ├── batch_cell_morphology.m
│   ├── batch_cell_damage.m
│   ├── surface_extract.m
│   ├── cell_connectivity.m
│   ├── skin_quantify.m        # Single-file hole quantification
│   ├── cell_angle_quantity.m  # Single-file cell angle quantification
│   └── hole_measure_compare.m # Program vs. manual measurement comparison
├── visualization/             # 3D visualization
│   ├── hole_3d_view.m
│   ├── pca_3d_fit.m
│   ├── pca_projection_line.m
│   ├── open_figures.m
│   └── batch_remove_labels.m
└── extraction/                # Data preprocessing (square cropping by Excel coordinates / xz reslicing)
    ├── extract_squares.m
    ├── extract_and_reslice.m
    └── extract_main.m
```

No external dependency installation, compilation, or environment configuration is required (only MATLAB R2025a with Image Processing Toolbox must be pre-installed). The whole installation takes less than 1 second.

## Demo

Run `init` first in the `SkinQuant` folder. The bundled raw volume can be read and used to extract the skin surface directly:

```matlab
init
volume = read_tiff_stack(fullfile('Dataset', '25mJ_12.tif'));
[surface_raw, surface_smoothed] = skin_surface(volume, '25mj', 20);
normal = surface_normal(surface_smoothed, [1.3 1.3 1.0], '25mj');
```

When the ResUNet segmentation results have been generated, a single file can be processed through the complete cell-angle quantification (the paths below refer to the processed-data root described under Input, not the bundled `Dataset/` folder):

```matlab
init
cell_angle_quantity( ...
    'F:/hole_seg/dataset25_75_150/25mj_4d_select_cell_sunshang/25mJ_12.tif', ...
    'F:/hole_seg/dataset25_75_150/25mj_4d_select/25mJ_12.tif', ...
    'tmp/25mJ_12_angle.tif', ...
    'Resolution', [1.3 1.3 1.0], 'Dataset', '25mj', ...
    'Threshold', 20, 'VolumeThreshold', 10);
```

This produces the angle-coded volume `tmp/25mJ_12_angle.tif` and records the angle distribution of this site in `all_datasets_angle_statistics.xlsx`.

Note: Step 4 (cell angle) and Step 4b (cell morphology) read `_4d_select_cell_sunshang`, which is generated by Step 5 `batch_cell_damage`. For the first full run, make sure this folder already exists or run Step 5 once beforehand.

## User data processing instructions

1. **Input**
   The workflow reads a processed-data root specified by `base_dir` (example: `F:\hole_seg\dataset25_75_150`), organized by dataset (`25mj` / `75mj` / `150mj`). The bundled raw volumes are the starting point: copy or preprocess each file from `Dataset/` into the corresponding `<dataset>_4d_select` folder (for example, `Dataset/25mJ_12.tif` → `25mj_4d_select/25mJ_12.tif`), so that each raw file has the same name as its segmentation result. The expected subfolders are:
   - `<dataset>_4d_select`: raw grayscale volume data (external preprocessing)
   - `<dataset>_4d_select_hole_result`: hole segmentation (255 = hole, ResUNet)
   - `<dataset>_4d_select_hole_liantongyu`: largest connected component within the central ROI (0/255, produced by `batch_connectivity_filter`)
   - `<dataset>_4d_select_surface`: surface/main-axis label map (252/253/254/255, produced by `batch_surface_pca`)
   - `<dataset>_4d_select_surface_visualization`: 3D rendering (produced by `batch_surface_pca`)
   - `<dataset>_4d_select_sunshang_liantongyu`: damage-region overlay (255 = damage region, 254 = PCA line, all other pixels are raw grayscale/2; produced by external damage segmentation)
   - `<dataset>_4d_select_cell_sunshang`: nucleus-like objects ∩ damage region (non-zero = object, produced by `batch_cell_damage`)
   - `<dataset>_4d_select_cell_angle`: angle-coded cell volume (pixel value = angle, produced by `batch_cell_angle`)

   For the damage-region overlay, the mask must be extracted with `==255`, not `>0`; otherwise the entire raw grayscale volume would be treated as damage region.

2. **Parameters instruction**
   Configure the following parameters before execution:
   - Resolution: voxel resolution, default `[1.3, 1.3, 1.0]` μm
   - RegionSize: side length of the central ROI for hole analysis, default 750 pixels
   - Threshold: skin surface grayscale threshold (applied to the raw 8-bit image), default 20
   - VolumeThreshold: minimum number of voxels for a nucleus-like object, default 10 (smaller objects are treated as fragments)
   - ShallowRatio: shallow-depth ratio, default 1 (full depth)
   - Number of slices: number of equally spaced slices along the main axis in `cross_section`, default 100, each slice taken with a ±2.0 μm thickness
   - Connectivity: 3D connected components, default 26

3. **Run `main_workflow.m`**
   The processing steps are:
   - Step 1 `batch_connectivity_filter`: central ROI + 26-connectivity + keep the largest connected component; outputs `_4d_select_hole_liantongyu`
   - Step 2 `batch_hole_quantity`: hole volume/depth/max cross-sectional area/perimeter/max envelope radius/tilt angle; outputs `hole_quantity_results.xlsx`
   - Step 3 `batch_surface_pca`: surface PCA quantification + surface/main-axis label map + 3D rendering; outputs `surface_pca_results.xlsx` and `_4d_select_surface`
   - Step 4 `batch_cell_angle`: per-object main-axis angle, angle distribution, and angle-coded volume; outputs `all_datasets_angle_statistics.xlsx`
   - Step 4b `batch_cell_morphology`: count/total volume/density/volume fraction/sphericity; outputs `cell_morphology_results.xlsx`
   - Step 5 `batch_cell_damage`: intersection of nucleus-like objects and damage regions; outputs `_4d_select_cell_sunshang`
   - Step 6 `hole_3d_view`: single-file 3D visualization (example); outputs PNG

4. **Output**
   - `hole_quantity_results.xlsx`: one row per site with fields Dataset, Filename, Volume, Depth, MaxArea, MaxPerimeter, MaxRadius, SurfaceAngle
   - `surface_pca_results.xlsx`: one row per site with fields Dataset, Filename (without extension), Volume, Depth, MaxArea, MaxPerimeter, MaxRadius, SurfaceAngle
   - `all_datasets_angle_statistics.xlsx`: 3 worksheets named `AngleDistribution(ByComponent)`, `AngleDistribution(ByVoxel)`, and `SummaryStatistics`; the angle columns cover 0°–90° (91 columns)
   - `cell_morphology_results.xlsx`: one row per site with fields ObjectCount, TotalVolume, Density, VolumeFraction, MeanSphericity, StdSphericity, InjuryVolume, MeanAngle_deg, and WeightedMeanAngle_deg

   All hole and injury-region parameters in `hole_quantity_results.xlsx` and `surface_pca_results.xlsx` are computed with the automatic depth-axis selection; see "Axis selection and operator-adjusted axes" below.

   `batch_hole_quantity` supports resuming from a checkpoint: it skips already processed rows using `dataset|filename` as the key, so re-runs will not miss files that share the same name in different datasets.

5. **Algorithm definitions**
   Surface extraction: scan downward column by column from the top of the image (from the bottom for `150mj`) and take the first pixel above the threshold; smooth with `imgaussfilt(...,2)`. The normal is obtained by per-column `surfnorm`, then averaged over the whole image and normalized, pointing outward from the skin surface (−Y for 25/75mj, +Y for 150mj).

   Angle definitions (unified for cells and holes):
   - Micro-hole / damage region: among the three PCA axes, the one with the smallest angle to the ROI surface normal is taken as the depth axis, `θ = 90° − arccos(|MM·MS|) = arcsin(|MM·MS|)`; 0° means the axis is parallel to the surface and 90° means perpendicular.
   - Nucleus-like object: the first principal axis corresponding to the largest eigenvalue, `θ = arcsin(|MC·MS|)`; 0° means the main axis is parallel to the surface and 90° means perpendicular.
   - Both use the absolute value of the dot product with the normal, so the sign of the principal axis does not affect the angle.
   - The first principal axis (largest eigenvalue) is deliberately not used for holes: the first principal axis of a shallow dish-shaped hole often lies in the surface plane and its projected length cannot represent depth, so the axis closest to the normal is used as the depth axis instead. This is the default and the only axis-selection rule in the public batch code; see "Axis selection and operator-adjusted axes" below.

   Morphology definitions:
   - Volume = number of voxels × `prod(resolution)`
   - Depth = peak-to-peak projection along the depth axis (not Euclidean length)
   - Max cross-sectional area / perimeter / max envelope radius = over 100 slices along the main axis, the `polyarea` / convex-hull perimeter / maximum distance from the hull centroid to a vertex of each slice within the shallow range
   - Sphericity = `(36πV²)^(1/3) / S`, where S is converted from the SurfaceArea returned by `regionprops3` using `(dx·dy·dz)^(2/3)`; the result is clipped to ≤1
   - Density = number of objects / damage-region volume; volume fraction = total object volume / damage-region volume

## Axis selection and operator-adjusted axes

The depth axis is selected automatically: among the three PCA axes of each micropore, the axis forming the smallest angle with the ROI-level surface normal is used. All batch functions (`batch_hole_quantity`, `batch_surface_pca`) therefore report the automatic result, and the public code contains no step that imports an operator-defined axis.

For five 75 mJ/pixel sites reported in the accompanying article (sites 12, 14, 15, 21 and 26), the depth axis was replaced after three-dimensional review because the automatically selected axis did not follow the visible channel lumen. Each replaced axis is stored as two endpoints in the physical coordinate system of the corresponding data block (voxel index multiplied by the voxel resolution). The five axis records, the automatic and reported depth and angle values, and the script used to recompute the depth, cross-section and angle from these axes are available from the corresponding author upon reasonable request; they are not included in this repository.

The final statistics in the article were computed from the corrected site-level workbook, whose `AxisSource(auto/manual)` field flags the five adjusted rows; all other 123 rows are automatic. The automatic values before adjustment were archived separately and are reproduced in Table S4(C) of the article; they cannot be derived from the final workbook. The `hole_quantity_results.xlsx` and `surface_pca_results.xlsx` files produced by this repository do not contain the `AxisSource` field, and they always contain the automatic values.

Running the recalculation requires the corresponding hole-segmentation blocks and raw volumes, which are also available from the corresponding author upon reasonable request (see Data Availability in the article).

Note: `skin_quantify.m` is a legacy single-file helper. It selects the depth axis relative to the Y axis, uses 45 sections, and reports `max_radius = MaxPerimeter/(2*pi)`; these definitions differ from the article. Use `batch_hole_quantity` or `batch_surface_pca` when the article's definitions are required.

## Contact

If you have any questions, please contact yuanj@hust.edu.cn for help.
