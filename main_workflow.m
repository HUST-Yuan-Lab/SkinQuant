% ============================================================
% SkinQuant skin hole quantitative analysis - main program
% Integrates connectivity filtering, hole quantification, surface PCA, cell angles, and visualization
% ============================================================
clear; clc;

%% Initialize paths
root_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(root_dir, 'utils'));
addpath(fullfile(root_dir, 'analysis'));
addpath(fullfile(root_dir, 'visualization'));
addpath(fullfile(root_dir, 'extraction'));

%% ======================== Parameter configuration ========================
base_dir   = 'F:\hole_seg\dataset25_75_150';  % Processed data root (not the bundled Dataset folder)
datasets   = {'25mj', '75mj', '150mj'};        % Dataset list
resolution = [1.3, 1.3, 1.0];                  % [x,y,z] resolution (μm/pixel)
region_sz  = 750;                               % Central region size (pixels)
surface_thre = 20;                              % Skin surface threshold
volume_thre  = 10;                              % Cell voxel filtering threshold

%% ======================== Pipeline switches ========================
%  Set to true to run the corresponding step, false to skip
RUN_CONNECTIVITY_FILTER = true;   % Step 1: connectivity filtering
RUN_HOLE_QUANTITY       = true;   % Step 2: hole/damage quantification (volume/depth/area)
RUN_SURFACE_PCA         = true;   % Step 3: surface PCA analysis (hole angle)
RUN_CELL_ANGLE          = true;   % Step 4: cell angle analysis
RUN_CELL_MORPHOLOGY     = true;   % Step 4b: cell morphology quantification (count/density/fraction/sphericity)
RUN_CELL_DAMAGE         = false;  % Step 5: cell-damage intersection (requires damage data first)
RUN_VISUALIZATION       = false;  % Step 6: 3D visualization (single-file mode)

%% ==========================================================
%% Step 1: connectivity filtering - remove specks and keep the largest hole in the central region
%% ==========================================================
if RUN_CONNECTIVITY_FILTER
    fprintf('\n========== Step 1: Connectivity filtering ==========\n');
    input_dirs  = cell(1, length(datasets));
    output_dirs = cell(1, length(datasets));
    for d = 1:length(datasets)
        input_dirs{d}  = fullfile(base_dir, [datasets{d} '_4d_select_hole_result']);
        output_dirs{d} = fullfile(base_dir, [datasets{d} '_4d_select_hole_liantongyu']);
    end
    batch_connectivity_filter(input_dirs, output_dirs, ...
        'RegionSize', region_sz, 'Connectivity', 26);
end

%% ==========================================================
%% Step 2: hole/damage quantification - volume/depth/max cross-sectional area/perimeter/radius
%% ==========================================================
if RUN_HOLE_QUANTITY
    fprintf('\n========== Step 2: Hole quantification ==========\n');
    batch_hole_quantity(base_dir, datasets, ...
        'Resolution', resolution, ...
        'RegionSize', region_sz, ...
        'Threshold', surface_thre, ...
        'ShallowRatio', 1, ...
        'DrawPCA', true, ...
        'ExcelPath', fullfile(base_dir, 'hole_quantity_results.xlsx'));
end

%% ==========================================================
%% Step 3: surface PCA analysis - angle between the hole PCA axis and the skin surface
%% ==========================================================
if RUN_SURFACE_PCA
    fprintf('\n========== Step 3: Surface PCA analysis ==========\n');
    batch_surface_pca(base_dir, datasets, ...
        'Resolution', resolution, ...
        'RegionSize', region_sz, ...
        'Threshold', surface_thre, ...
        'IncludeQuantity', true, ...
        'ExcelPath', fullfile(base_dir, 'surface_pca_results.xlsx'));
end

%% ==========================================================
%% Step 4: cell angle analysis - angle between the cell main axis and the skin surface (same definition as the hole PCA angle)
%% ==========================================================
if RUN_CELL_ANGLE
    fprintf('\n========== Step 4: Cell angle analysis ==========\n');

    % Angle range is unified to 0-90° (the cell main axis has no direction)
    batch_cell_angle(base_dir, datasets, ...
        'Resolution', resolution, ...
        'Threshold', surface_thre, ...
        'VolumeThreshold', volume_thre, ...
        'OutputSuffix', '_cell_angle');
end

%% ==========================================================
%% Step 4b: cell morphology quantification - count/total volume/density/volume fraction/sphericity
%% ==========================================================
if RUN_CELL_MORPHOLOGY
    fprintf('\n========== Step 4b: Cell morphology quantification ==========\n');
    batch_cell_morphology(base_dir, datasets, ...
        'Resolution', resolution, ...
        'VolumeThreshold', volume_thre, ...
        'ExcelPath', fullfile(base_dir, 'cell_morphology_results.xlsx'), ...
        'AngleExcel', fullfile(base_dir, 'all_datasets_angle_statistics.xlsx'));
end

%% ==========================================================
%% Step 5: cell-damage intersection - compute cells within the damage region
%% ==========================================================
if RUN_CELL_DAMAGE
    fprintf('\n========== Step 5: Cell-damage intersection analysis ==========\n');
    cell_folders = cell(length(datasets), 3);
    for d = 1:length(datasets)
        cell_folders{d,1} = [datasets{d} '_4d_select_cell_result'];
        cell_folders{d,2} = [datasets{d} '_4d_select_sunshang_liantongyu'];
        cell_folders{d,3} = [datasets{d} '_4d_select_cell_sunshang'];
    end
    batch_cell_damage(base_dir, cell_folders);
end

%% ==========================================================
%% Step 6: single-file 3D visualization (example)
%% ==========================================================
if RUN_VISUALIZATION
    fprintf('\n========== Step 6: 3D visualization ==========\n');
    % Change to the actual file paths
    sample_original  = fullfile(base_dir, '25mj_4d_select', '25mJ_12.tif');
    sample_segmented = fullfile(base_dir, '25mj_4d_select_hole_result', '25mJ_12.tif');
    vis_output_dir   = fullfile(base_dir, 'visualization_output');

    if exist(sample_original, 'file') && exist(sample_segmented, 'file')
        hole_3d_view(sample_original, sample_segmented, vis_output_dir, ...
            'Resolution', resolution, 'RegionSize', region_sz, 'SaveFig', true);
        fprintf('Visualization results saved to: %s\n', vis_output_dir);
    else
        fprintf('Visualization skipped: example file does not exist; please update the sample_original/sample_segmented paths\n');
    end
end

%% ==========================================================
fprintf('\n========== All steps completed ==========\n');
fprintf('Quantitative results Excel files are located at: %s\n', base_dir);
