function batch_cell_morphology(base_path, datasets, varargin)
    % Batch morphological quantification of cells (PI-positive nucleus-like objects): count/total volume/density/volume fraction/sphericity
    %   base_path: root data directory
    %   datasets: cell array of dataset names, e.g. {'25mj','75mj','150mj'}
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'VolumeThreshold', v - minimum voxel count, default 10
    %     'ExcelPath', path - output Excel, default <base_path>/cell_morphology_results.xlsx
    %     'AngleExcel', path - cell angle summary table used to merge site-level angles; NaN is used if it does not exist
    %   The denominator for density and volume fraction is the damage-region volume (damage-region folder)
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'VolumeThreshold', 10);
    addParameter(p, 'ExcelPath', '');
    addParameter(p, 'AngleExcel', '');
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    vol_thre = p.Results.VolumeThreshold;

    if isempty(p.Results.ExcelPath)
        excel_path = fullfile(base_path, 'cell_morphology_results.xlsx');
    else
        excel_path = p.Results.ExcelPath;
    end
    if isempty(p.Results.AngleExcel)
        angle_excel = fullfile(base_path, 'all_datasets_angle_statistics.xlsx');
    else
        angle_excel = p.Results.AngleExcel;
    end

    % Preload the angle summary (avoids reading from disk for every file)
    angle_map = load_angle_summary(angle_excel);

    var_names = {'Dataset','Filename','ObjectCount','TotalVolume_um3', ...
                 'Density_per_um3','VolumeFraction','MeanSphericity','StdSphericity', ...
                 'InjuryVolume_um3','MeanAngle_deg','WeightedMeanAngle_deg'};
    var_types = repmat({'double'}, 1, numel(var_names));
    var_types(1:2) = {'string'};
    results = table('Size', [0, numel(var_names)], ...
        'VariableTypes', var_types, 'VariableNames', var_names);

    voxel_volume = prod(resolution);

    for ds_idx = 1:length(datasets)
        dataset = datasets{ds_idx};
        fprintf('\n===== Processing dataset: %s =====\n', dataset);

        cell_dir = fullfile(base_path, [dataset '_4d_select_cell_sunshang']);
        injury_dir = fullfile(base_path, [dataset '_4d_select_sunshang_liantongyu']);

        if ~exist(cell_dir, 'dir')
            warning('Cell folder does not exist, skipping: %s', cell_dir);
            continue;
        end

        cell_files = dir(fullfile(cell_dir, '*.tif'));
        for fIdx = 1:length(cell_files)
            filename = cell_files(fIdx).name;
            fprintf('Processing: %s (%d/%d)\n', filename, fIdx, length(cell_files));

            injury_path = fullfile(injury_dir, filename);
            if ~exist(injury_path, 'file')
                fprintf('  Warning: damage file does not exist; density and volume fraction set to NaN\n');
                injuryVolume = [];
            else
                injuryVolume = read_tiff_stack(injury_path);
            end

            try
                cellVolume = read_tiff_stack(fullfile(cell_dir, filename));
                [obj_count, total_volume, density, vol_fraction, ...
                    mean_sph, std_sph, ~, ~, injury_volume_um3] = ...
                    cell_morphology(cellVolume, injuryVolume, resolution, vol_thre);
            catch ME
                fprintf('  Error processing %s: %s\n', filename, ME.message);
                continue;
            end

            if isempty(injuryVolume)
                injury_volume_um3 = NaN;
            end

            key = sprintf('%s_%s', dataset, filename);
            if isKey(angle_map, key)
                mean_angle = angle_map(key).mean_angle;
                w_mean_angle = angle_map(key).w_mean_angle;
            else
                mean_angle = NaN; w_mean_angle = NaN;
            end

            new_row = {dataset, filename, obj_count, total_volume, density, ...
                vol_fraction, mean_sph, std_sph, injury_volume_um3, ...
                mean_angle, w_mean_angle};
            results = [results; new_row]; %#ok<AGROW>

            fprintf('  Objects:%d Total volume:%.0f Density:%.6f Fraction:%.4f Sphericity:%.3f±%.3f Angle:%.1f°\n', ...
                obj_count, total_volume, density, vol_fraction, mean_sph, std_sph, mean_angle);
        end
    end

    writetable(results, excel_path);
    fprintf('\nResults saved: %s\n', excel_path);
end

function angle_map = load_angle_summary(angle_excel)
    % Read the cell angle summary table and build a "dataset_filename" -> angle mapping
    angle_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
    if ~exist(angle_excel, 'file')
        fprintf('Note: angle summary table not found; angle columns will be NaN: %s\n', angle_excel);
        return;
    end
    try
        T = readtable(angle_excel, 'Sheet', 'SummaryStatistics', 'VariableNamingRule', 'preserve');
        names = T.Properties.VariableNames;
        keys = string(T.(names{1})) + "_" + string(T.(names{2}));
        mean_col = find(contains(names, 'MeanAngle'), 1);
        w_col = find(contains(names, 'WeightedMean'), 1);
        for i = 1:height(T)
            rec.mean_angle = T{i, mean_col};
            rec.w_mean_angle = T{i, w_col};
            angle_map(char(keys(i))) = rec;
        end
    catch ME
        fprintf('Note: failed to read the angle summary table (%s); angle columns will be NaN\n', ME.message);
    end
end
