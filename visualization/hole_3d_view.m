function hole_3d_view(original_path, segmented_path, output_dir, varargin)
    % 3D hole visualization: PCA analysis + cross-section contour + depth measurement
    %   original_path: path to the original TIFF
    %   segmented_path: path to the segmentation result TIFF
    %   output_dir: output directory
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RegionSize', sz - central region size, default 750
    %     'ShallowRatio', r - default 1
    %     'SaveFig', true/false - whether to save .fig and .png, default true
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'ShallowRatio', 1);
    addParameter(p, 'SaveFig', true);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    region_size = p.Results.RegionSize;
    shallow_ratio = p.Results.ShallowRatio;
    save_fig = p.Results.SaveFig;

    if ~exist(output_dir, 'dir'); mkdir(output_dir); end
    [~, fname_only] = fileparts(segmented_path);

    % Read data
    info = imfinfo(original_path);
    numSlices = numel(info);
    width = info(1).Width; height = info(1).Height;
    [x_start, x_end, y_start, y_end] = central_region(width, height, region_size);

    originalVolume = read_tiff_stack(original_path);
    segmentedVolume = read_tiff_stack(segmented_path);

    % Connected-component analysis
    binaryVolume = false(size(segmentedVolume));
    binaryVolume(y_start:y_end, x_start:x_end, :) = segmentedVolume(y_start:y_end, x_start:x_end, :) == 255;
    [cleanedVolume, numObj] = largest_cc(binaryVolume, 26);
    if numObj == 0; error('No hole found'); end

    volumeData = uint8(cleanedVolume) * 255;

    % Extract coordinates
    [y, x, z] = ind2sub(size(volumeData), find(volumeData == 255));
    coords = [x*resolution(1), y*resolution(2), z*resolution(3)];

    % PCA
    [centroid, ~, ~, selected_PC] = pca_analysis(coords, 'YAxis', true);
    projections = (coords - centroid) * selected_PC';
    R = corrcoef(projections, coords(:,2));
    if R(1,2) < 0; selected_PC = -selected_PC; projections = -projections; end
    min_proj = min(projections); max_proj = max(projections);
    hole_depth = max_proj - min_proj;

    % Cross-section analysis
    [depth_positions, areas, perimeters, ~] = cross_section(coords, centroid, selected_PC, 45);
    shallow_end = min_proj + shallow_ratio * hole_depth;
    shallow_idx = depth_positions <= shallow_end;
    shallow_areas = areas(shallow_idx);
    [max_area, max_area_idx] = max(shallow_areas);
    max_area_depth = depth_positions(shallow_idx);
    max_area_depth = max_area_depth(max_area_idx);

    % Build an orthogonal basis
    ortho1 = cross(selected_PC, [0 0 1]);
    if norm(ortho1) < 1e-6; ortho1 = cross(selected_PC, [0 1 0]); end
    ortho1 = ortho1 / norm(ortho1);
    ortho2 = cross(selected_PC, ortho1) / norm(cross(selected_PC, ortho1));

    voxel_volume = prod(resolution);
    total_volume = sum(volumeData(:) == 255) * voxel_volume;
    max_perimeter = max(perimeters(shallow_idx));
    max_radius = max_perimeter / (2*pi);

    % ---- Figure 1: cross-sectional area/perimeter versus depth ----
    fig1 = figure('Visible', 'off');
    subplot(2,1,1);
    plot(depth_positions, areas, 'b-', 'LineWidth', 2); hold on;
    fill([min_proj, shallow_end, shallow_end, min_proj], [0,0,max(areas),max(areas)], ...
        'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    xlabel('Position along principal axis (μm)'); ylabel('Cross-sectional area (μm²)');
    title(sprintf('Cross-sectional area versus depth (shallow 0-%.0f%%)', shallow_ratio*100));
    grid on;

    subplot(2,1,2);
    plot(depth_positions, perimeters, 'r-', 'LineWidth', 2); hold on;
    fill([min_proj, shallow_end, shallow_end, min_proj], [0,0,max(perimeters),max(perimeters)], ...
        'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    xlabel('Position along principal axis (μm)'); ylabel('Cross-sectional perimeter (μm)');
    title(sprintf('Cross-sectional perimeter versus depth (shallow 0-%.0f%%)', shallow_ratio*100));
    grid on;

    if save_fig
        saveas(fig1, fullfile(output_dir, [fname_only '_cross_section.png']));
        saveas(fig1, fullfile(output_dir, [fname_only '_cross_section.fig']));
    end

    % ---- Figure 2: 3D point cloud + PCA axis + maximum cross-section contour ----
    max_area_nearby = coords(abs(projections - max_area_depth) < 2.0, :);
    proj_pts_area = zeros(size(max_area_nearby,1), 2);
    for j = 1:size(max_area_nearby,1)
        vec = max_area_nearby(j,:) - (centroid + selected_PC * max_area_depth);
        proj_pts_area(j,1) = dot(vec, ortho1);
        proj_pts_area(j,2) = dot(vec, ortho2);
    end
    k_area = convhull(proj_pts_area(:,1), proj_pts_area(:,2));

    fig2 = figure('Visible', 'off', 'Position', [100, 100, 800, 600]);
    scatter3(coords(:,1), coords(:,2), coords(:,3), 10, 'filled', 'MarkerFaceAlpha', 0.3);
    hold on; axis equal;

    start_pt = centroid + selected_PC * min_proj;
    end_pt = centroid + selected_PC * max_proj;
    depth_line = plot3([start_pt(1),end_pt(1)], [start_pt(2),end_pt(2)], [start_pt(3),end_pt(3)], ...
        'm-', 'LineWidth', 2);

    max_center = centroid + selected_PC * max_area_depth;
    contour3d = zeros(length(k_area), 3);
    for j = 1:length(k_area)
        contour3d(j,:) = max_center + ortho1*proj_pts_area(k_area(j),1) + ortho2*proj_pts_area(k_area(j),2);
    end
    patch(contour3d(:,1), contour3d(:,2), contour3d(:,3), 'r', 'FaceAlpha', 0.5, 'EdgeColor', 'r', 'LineWidth', 2);
    scatter3(max_center(1), max_center(2), max_center(3), 100, 'ro', 'filled');

    legend([depth_line], {'Depth measurement'}, 'Location', 'best');
    xlabel('X (μm)'); ylabel('Y (μm)'); zlabel('Z (μm)');
    title(sprintf('3D hole visualization\nDepth: %.0f μm | Max radius: %.0f μm', hole_depth, max_radius));
    grid on; view(3);

    if save_fig
        saveas(fig2, fullfile(output_dir, [fname_only '_3d_visualization.png']));
        saveas(fig2, fullfile(output_dir, [fname_only '_3d_visualization.fig']));
    end

    % Create the overlay image
    overlayVolume = repmat(originalVolume, [1,1,1,3]);
    for k = 1:numSlices
        slice_data = overlayVolume(:,:,k,:);
        red_mask = volumeData(:,:,k) == 255;
        slice_data(:,:,:,1) = slice_data(:,:,:,1) + uint8(red_mask * 100);
        slice_data(:,:,:,2) = slice_data(:,:,:,2) .* uint8(~red_mask);
        slice_data(:,:,:,3) = slice_data(:,:,:,3) .* uint8(~red_mask);
        overlayVolume(:,:,k,:) = min(slice_data, 255);
    end

    overlay_path = fullfile(output_dir, [fname_only '_overlay.tif']);
    for k = 1:numSlices
        rgb_slice = squeeze(overlayVolume(:,:,k,:));
        if k == 1; imwrite(rgb_slice, overlay_path, 'Compression', 'none');
        else; imwrite(rgb_slice, overlay_path, 'WriteMode', 'append', 'Compression', 'none'); end
    end

    % Print results
    fprintf('Total hole volume: %.2f μm³\n', total_volume);
    fprintf('Hole depth: %.2f μm\n', hole_depth);
    fprintf('Max cross-sectional area: %.2f μm²\n', max_area);
    fprintf('Max cross-sectional perimeter: %.2f μm\n', max_perimeter);

    close(fig1); close(fig2);
end
