function batch_cell_angle(basePath, datasets, varargin)
    % Batch cell angle quantification
    %   basePath: root data directory
    %   datasets: cell array of dataset names
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'Threshold', t - surface threshold, default 30
    %     'VolumeThreshold', v - voxel filtering threshold, default 10
    %     'OutputSuffix', str - output folder suffix, default '_cell_angle'
    %   Angles are unified to 0-90° (angle between the cell main axis and the skin surface: 0° = parallel to the surface, 90° = perpendicular)
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'Threshold', 30);
    addParameter(p, 'VolumeThreshold', 10);
    addParameter(p, 'OutputSuffix', '_cell_angle');
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    thre = p.Results.Threshold;
    vol_thre = p.Results.VolumeThreshold;
    out_suffix = p.Results.OutputSuffix;

    num_bins = 90;   % angle range 0-90°

    % Initialize global statistics
    all_dist_stats = cell(0, num_bins+2);
    all_weighted_stats = cell(0, num_bins+2);
    all_summary = cell(0, 8);

    % Table headers
    dist_header = cell(1, num_bins+2); dist_header{1} = 'File';
    for i = 0:num_bins; dist_header{i+2} = sprintf('%d°', i); end
    summary_header = {'Dataset','Filename','ComponentCount','TotalVoxels','MeanAngle','AngleVariance','WeightedMean','WeightedVariance'};

    for d = 1:length(datasets)
        dataset = datasets{d};
        fprintf('\n=== Processing dataset: %s ===\n', dataset);

        binaryFolder = fullfile(basePath, [dataset '_4d_select_cell_sunshang']);
        originalFolder = fullfile(basePath, [dataset '_4d_select']);
        outputFolder = fullfile(basePath, [dataset out_suffix]);

        if ~exist(outputFolder, 'dir'); mkdir(outputFolder); end

        tifFiles = dir(fullfile(binaryFolder, '*.tif'));
        for fIdx = 1:length(tifFiles)
            fileName = tifFiles(fIdx).name;
            fprintf('Processing: %s (%d/%d)\n', fileName, fIdx, length(tifFiles));
            inputPath = fullfile(binaryFolder, fileName);
            originalPath = fullfile(originalFolder, fileName);
            outputPath = fullfile(outputFolder, fileName);

            if ~exist(originalPath, 'file')
                fprintf('Warning: original file %s does not exist\n', originalPath);
                continue;
            end

            try
                binaryVolume = read_tiff_stack(inputPath) > 0;
                originalVolume = read_tiff_stack(originalPath);

                [~, skin_smoothed] = skin_surface(originalVolume, dataset, thre);
                normal = surface_normal(skin_smoothed, resolution, dataset);

                [all_angles, all_volumes, angle_dist, weighted_dist, resultVolume] = ...
                    cell_angle(binaryVolume, normal, resolution, vol_thre);

                save_tiff_stack(resultVolume, outputPath);

                if ~isempty(all_angles)
                    total_vox = sum(all_volumes);
                    mean_a = mean(all_angles); var_a = var(all_angles);
                    w_mean = sum(all_angles.*all_volumes)/total_vox;
                    w_var = sum(all_volumes.*(all_angles-w_mean).^2)/total_vox;

                    dist_row = cell(1, num_bins+2); dist_row{1} = sprintf('%s_%s', dataset, fileName);
                    w_row = cell(1, num_bins+2); w_row{1} = sprintf('%s_%s', dataset, fileName);
                    for i = 0:num_bins
                        dist_row{i+2} = angle_dist(i+1);
                        w_row{i+2} = weighted_dist(i+1);
                    end
                    all_dist_stats = [all_dist_stats; dist_row];
                    all_weighted_stats = [all_weighted_stats; w_row];
                    all_summary = [all_summary; {dataset, fileName, length(all_angles), total_vox, mean_a, var_a, w_mean, w_var}];

                    fprintf('  Components:%d Mean angle:%.1f° Weighted mean:%.1f°\n', length(all_angles), mean_a, w_mean);
                end
            catch ME
                fprintf('Error processing %s: %s\n', fileName, ME.message);
            end
        end
    end

    % Save the Excel file
    if ~isempty(all_dist_stats)
        excelPath = fullfile(basePath, 'all_datasets_angle_statistics.xlsx');
        writetable(cell2table(all_dist_stats, 'VariableNames', dist_header), excelPath, 'Sheet', 'AngleDistribution(ByComponent)');
        writetable(cell2table(all_weighted_stats, 'VariableNames', dist_header), excelPath, 'Sheet', 'AngleDistribution(ByVoxel)');
        writetable(cell2table(all_summary, 'VariableNames', summary_header), excelPath, 'Sheet', 'SummaryStatistics');
        fprintf('\nStatistics saved: %s\n', excelPath);
    end
end
