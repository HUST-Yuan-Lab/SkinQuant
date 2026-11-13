function cell_angle_quantity(inputPath, originalPath, outputPath, varargin)
    % Single-file cell angle quantification: compute the angle between each cell main axis and the skin surface (0° = parallel, 90° = perpendicular)
    %   inputPath: path to the binarized cell TIFF
    %   originalPath: path to the raw data TIFF (used to extract the skin surface)
    %   outputPath: output path of the color-coded result
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'Dataset', str - dataset name (determines the surface direction)
    %     'Threshold', t - surface threshold, default 30
    %     'VolumeThreshold', v - voxel filtering threshold, default 10
    %   Angles are unified to 0-90° (angle between the cell main axis and the skin surface: 0° = parallel to the surface, 90° = perpendicular)
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'Dataset', '25mj');
    addParameter(p, 'Threshold', 30);
    addParameter(p, 'VolumeThreshold', 10);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    dataset = p.Results.Dataset;
    thre = p.Results.Threshold;
    vol_thre = p.Results.VolumeThreshold;

    % Read data
    binaryVolume = read_tiff_stack(inputPath) > 0;
    originalVolume = read_tiff_stack(originalPath);

    % Extract the skin surface and compute the normal vector
    [~, skin_smoothed] = skin_surface(originalVolume, dataset, thre);
    normal = surface_normal(skin_smoothed, resolution, dataset);
    fprintf('Surface normal: [%.3f, %.3f, %.3f]\n', normal);

    % Compute cell angles
    [all_angles, all_volumes, angle_dist, weighted_dist, resultVolume] = ...
        cell_angle(binaryVolume, normal, resolution, vol_thre);

    % Save the color-coded result
    save_tiff_stack(resultVolume, outputPath);
    fprintf('Results saved: %s\n', outputPath);

    % Statistical summary
    if ~isempty(all_angles)
        total_voxels = sum(all_volumes);
        fprintf('\n=== Angle statistics summary ===\n');
        fprintf('Total components: %d\n', length(all_angles));
        fprintf('Total voxels: %d\n', total_voxels);
        fprintf('Mean angle: %.2f°\n', mean(all_angles));
        fprintf('Angle variance: %.2f\n', var(all_angles));
        fprintf('Weighted mean: %.2f°\n', sum(all_angles.*all_volumes)/total_voxels);
    end

    % Save the Excel statistics
    [~, name] = fileparts(inputPath);
    excelPath = fullfile(fileparts(outputPath), [name '_angle_stats.xlsx']);
    save_angle_excel(excelPath, all_angles, all_volumes, angle_dist, weighted_dist);
end

function save_angle_excel(path, angles, volumes, dist, wdist)
    num_bins = length(dist) - 1;
    data = cell(num_bins + 3, 3);
    data{1,1} = 'AngleRange'; data{1,2} = 'ComponentCount'; data{1,3} = 'VoxelCount';
    for i = 0:num_bins
        data{i+2,1} = sprintf('%d°', i);
        data{i+2,2} = dist(i+1);
        data{i+2,3} = wdist(i+1);
    end
    total_vox = sum(volumes);
    data{num_bins+3,1} = 'MeanAngle'; data{num_bins+3,2} = mean(angles);
    data{num_bins+4,1} = 'WeightedMean'; data{num_bins+4,2} = sum(angles.*volumes)/total_vox;
    T = cell2table(data(2:end,:), 'VariableNames', {'AngleRange','ComponentCount','VoxelCount'});
    writetable(T, path);
end
