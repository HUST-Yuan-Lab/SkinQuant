function results = skin_quantify(filename, varargin)
    % Single-file hole quantification: PCA + cross-sectional area/perimeter/depth/volume
    %   filename: path to the segmentation result TIFF (holes marked as 255)
    %   Optional parameters:
    %     'Resolution', [x,y,z] - resolution, default [1.3,1.3,1.0]
    %     'ShallowRatio', r - shallow-depth ratio, default 1
    %   Returns:
    %     results: struct containing the quantitative results
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'ShallowRatio', 1);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    shallow_ratio = p.Results.ShallowRatio;

    % Read the TIFF
    volumeData = read_tiff_stack(filename);

    % Connected-component analysis - keep the largest hole
    binaryVolume = volumeData == 255;
    [cleanedVolume, ~] = largest_cc(binaryVolume, 26);
    volumeData = uint8(cleanedVolume) * 255;

    % Extract coordinates and convert to physical coordinates
    [y, x, z] = ind2sub(size(volumeData), find(volumeData == 255));
    coords = [x*resolution(1), y*resolution(2), z*resolution(3)];

    % PCA (select the axis with the smallest angle to the Y axis)
    [centroid, ~, ~, selected_PC] = pca_analysis(coords, 'YAxis', true);

    % Project and correct the direction
    projections = (coords - centroid) * selected_PC';
    R = corrcoef(projections, coords(:,2));
    if R(1,2) < 0
        selected_PC = -selected_PC;
        projections = -projections;
    end
    min_proj = min(projections);
    max_proj = max(projections);
    hole_depth = max_proj - min_proj;

    % Cross-section analysis
    [~, areas, perimeters, ~] = cross_section(coords, centroid, selected_PC, 45);

    % Shallow-layer statistics
    shallow_end = min_proj + shallow_ratio * hole_depth;
    depth_positions = linspace(min_proj, max_proj, 45);
    shallow_idx = depth_positions >= min_proj & depth_positions <= shallow_end;
    valid_areas = areas(shallow_idx); valid_areas = valid_areas(valid_areas > 0);
    valid_perims = perimeters(shallow_idx); valid_perims = valid_perims(valid_perims > 0);

    % Volume
    voxel_volume = prod(resolution);
    total_volume = sum(volumeData(:) == 255) * voxel_volume;

    % Output results
    results = struct();
    results.volume = total_volume;
    results.depth = hole_depth;
    results.max_area = max(valid_areas); if isempty(valid_areas); results.max_area = 0; end
    results.max_perimeter = max(valid_perims); if isempty(valid_perims); results.max_perimeter = 0; end
    results.max_radius = results.max_perimeter / (2 * pi);
    results.depth_positions = depth_positions;
    results.areas = areas;
    results.perimeters = perimeters;
    results.coords = coords;
    results.centroid = centroid;
    results.selected_PC = selected_PC;
    results.min_proj = min_proj;
    results.max_proj = max_proj;
    results.shallow_range = [min_proj, shallow_end];
    results.resolution = resolution;

    % Print summary
    fprintf('Total hole volume: %.2f μm³\n', total_volume);
    fprintf('Hole depth: %.2f μm\n', hole_depth);
    fprintf('Max cross-sectional area: %.2f μm²\n', results.max_area);
    fprintf('Max cross-sectional perimeter: %.2f μm\n', results.max_perimeter);
    fprintf('Max cross-sectional radius: %.2f μm\n', results.max_radius);
end
