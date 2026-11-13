function batch_surface_pca(base_dir, datasets, varargin)
    % Batch surface PCA analysis
    %   Computes the angle between the hole PCA axis and the skin surface, along with quantitative parameters
    %   Angle definition: 0° = axis parallel to the surface, 90° = axis perpendicular to the surface
    %   base_dir: root data directory
    %   datasets: cell array of dataset names
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RegionSize', sz - default 750
    %     'Threshold', t - surface threshold, default 20
    %     'ShallowRatio', r - default 1
    %     'ExcelPath', path - Excel output path
    %     'IncludeQuantity', true/false - whether to compute quantitative parameters such as volume/area (v2 mode)
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'Threshold', 20);
    addParameter(p, 'ShallowRatio', 1);
    addParameter(p, 'ExcelPath', '');
    addParameter(p, 'IncludeQuantity', false);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    region_size = p.Results.RegionSize;
    thre = p.Results.Threshold;
    shallow_ratio = p.Results.ShallowRatio;
    include_quant = p.Results.IncludeQuantity;

    if isempty(p.Results.ExcelPath)
        excel_path = fullfile(base_dir, 'surface_pca_analysis.xlsx');
    else
        excel_path = p.Results.ExcelPath;
    end

    if include_quant
        var_names = {'Dataset','Filename','Volume','Depth','MaxArea','MaxPerimeter','MaxRadius','SurfaceAngle'};
        var_types = {'string','string','double','double','double','double','double','double'};
    else
        var_names = {'Filename','Depth','SurfaceAngle'};
        var_types = {'string','double','double'};
    end
    results_table = table('Size', [0, length(var_names)], 'VariableTypes', var_types, 'VariableNames', var_names);

    for ds_idx = 1:length(datasets)
        dataset = datasets{ds_idx};
        fprintf('\n===== Processing dataset: %s =====\n', dataset);

        original_dir = fullfile(base_dir, [dataset '_4d_select']);
        segmented_dir = fullfile(base_dir, [dataset '_4d_select_hole_result']);
        output_dir = fullfile(base_dir, [dataset '_4d_select_surface']);
        vis_dir = fullfile(base_dir, [dataset '_4d_select_surface_visualization']);

        if ~exist(output_dir, 'dir'); mkdir(output_dir); end
        if ~exist(vis_dir, 'dir'); mkdir(vis_dir); end

        files = dir(fullfile(original_dir, '*.tif'));
        for fIdx = 1:length(files)
            [~, name, ext] = fileparts(files(fIdx).name);
            filename = [name ext];
            [~, fname_only] = fileparts(filename);
            fprintf('Processing: %s (%d/%d)\n', filename, fIdx, length(files));

            original_path = fullfile(original_dir, filename);
            segmented_path = fullfile(segmented_dir, filename);
            originalVolume = read_tiff_stack(original_path);
            segmentedVolume = read_tiff_stack(segmented_path);

            [height, width, numSlices] = size(originalVolume);
            [x_start, x_end, y_start, y_end] = central_region(width, height, region_size);

            % Skin surface and normal vector
            [~, skin_smoothed] = skin_surface(originalVolume, dataset, thre);
            normal = surface_normal(skin_smoothed, resolution, dataset);
            fprintf('  Surface normal: [%.3f, %.3f, %.3f]\n', normal);

            % Connected-component analysis
            binaryVolume = false(size(segmentedVolume));
            binaryVolume(y_start:y_end, x_start:x_end, :) = segmentedVolume(y_start:y_end, x_start:x_end, :) == 255;
            [cleanedVolume, numObj] = largest_cc(binaryVolume, 26);
            if numObj == 0
                warning('  No hole found, skipping');
                continue;
            end

            % Extract coordinates and run PCA
            [y, x, z] = ind2sub(size(cleanedVolume), find(cleanedVolume));
            coords = [x*resolution(1), y*resolution(2), z*resolution(3)];
            [centroid, ~, ~, selected_PC, min_angle] = pca_analysis(coords, 'SurfaceNormal', normal);
            % Angle between the PCA axis and the skin surface = 90° - angle between the PCA axis and the normal
            % 0° = axis parallel to the surface, 90° = axis perpendicular to the surface (same definition as the cell angle)
            angle_with_surface = 90 - min_angle;

            projections = (coords - centroid) * selected_PC';
            min_proj = min(projections);
            max_proj = max(projections);
            hole_depth = max_proj - min_proj;

            % Create the annotation output
            outputVolume = originalVolume ./ 2;

            if include_quant
                % Mark the hole region
                hole_region = false(size(segmentedVolume));
                hole_region(y_start:y_end, x_start:x_end, :) = segmentedVolume(y_start:y_end, x_start:x_end, :) == 255;
                outputVolume(hole_region) = 252;
            end

            % Mark the surface
            for k = 1:numSlices
                for xi = 1:width
                    sy = round(skin_smoothed(xi, k));
                    if ~isnan(sy) && sy >= 1 && sy <= height
                        for offset = -2:2
                            yp = sy + offset;
                            if yp >= 1 && yp <= height
                                outputVolume(yp, xi, k) = 253;
                            end
                        end
                    end
                end
            end

            % Mark the PCA axis and the normal axis
            lineStart = centroid - selected_PC * hole_depth;
            lineEnd = centroid + selected_PC * hole_depth;
            normal_length = hole_depth * 2;
            normalStart = centroid - normal * normal_length;
            normalEnd = centroid + normal * normal_length;

            ls_px = round([lineStart(1)/resolution(1), lineStart(2)/resolution(2), lineStart(3)/resolution(3)]);
            le_px = round([lineEnd(1)/resolution(1), lineEnd(2)/resolution(2), lineEnd(3)/resolution(3)]);
            ns_px = round([normalStart(1)/resolution(1), normalStart(2)/resolution(2), normalStart(3)/resolution(3)]);
            ne_px = round([normalEnd(1)/resolution(1), normalEnd(2)/resolution(2), normalEnd(3)/resolution(3)]);

            thickness = 11; half = floor(thickness/2);
            % PCA axis (254)
            line_voxels = bresenham_line(ls_px, le_px);
            for vi = 1:size(line_voxels,1)
                x0 = line_voxels(vi,1); y0 = line_voxels(vi,2); z0 = line_voxels(vi,3);
                for d = -half:half
                    if x0+d>=1&&x0+d<=width&&y0>=1&&y0<=height&&z0>=1&&z0<=numSlices; outputVolume(y0,x0+d,z0)=254; end
                    if x0>=1&&x0<=width&&y0+d>=1&&y0+d<=height&&z0>=1&&z0<=numSlices; outputVolume(y0+d,x0,z0)=254; end
                end
            end
            % Normal axis (255)
            line_voxels = bresenham_line(ns_px, ne_px);
            for vi = 1:size(line_voxels,1)
                x0 = line_voxels(vi,1); y0 = line_voxels(vi,2); z0 = line_voxels(vi,3);
                for d = -half:half
                    if x0+d>=1&&x0+d<=width&&y0>=1&&y0<=height&&z0>=1&&z0<=numSlices; outputVolume(y0,x0+d,z0)=255; end
                    if x0>=1&&x0<=width&&y0+d>=1&&y0+d<=height&&z0>=1&&z0<=numSlices; outputVolume(y0+d,x0,z0)=255; end
                end
            end

            save_tiff_stack(outputVolume, fullfile(output_dir, filename));

            % Quantitative computation (if enabled)
            if include_quant
                voxel_vol = prod(resolution);
                hole_volume = sum(cleanedVolume(:)) * voxel_vol;
                shallow_depth = min_proj + shallow_ratio * hole_depth;
                shallow_coords = coords(projections <= shallow_depth, :);

                if size(shallow_coords,1) >= 3
                    [~, areas, perimeters, radii] = cross_section(coords, centroid, selected_PC, 100);
                    shallow_idx = linspace(min_proj, max_proj, 100) <= shallow_depth;
                    valid_a = areas(shallow_idx); valid_a = valid_a(valid_a>0);
                    valid_p = perimeters(shallow_idx); valid_p = valid_p(valid_p>0);
                    valid_r = radii(shallow_idx); valid_r = valid_r(valid_r>0);
                    max_area = max(valid_a); if isempty(valid_a); max_area=0; end
                    max_perim = max(valid_p); if isempty(valid_p); max_perim=0; end
                    max_rad = max(valid_r); if isempty(valid_r); max_rad=0; end
                else
                    max_area=0; max_perim=0; max_rad=0;
                end

                results_table = [results_table; {dataset, fname_only, hole_volume, hole_depth, ...
                    max_area, max_perim, max_rad, angle_with_surface}];
            else
                results_table = [results_table; {filename, hole_depth, angle_with_surface}];
            end

            fprintf('  Depth:%.0fμm Surface angle:%.1f°\n', hole_depth, angle_with_surface);
        end
    end

    writetable(results_table, excel_path);
    fprintf('\nResults saved: %s\n', excel_path);
end
