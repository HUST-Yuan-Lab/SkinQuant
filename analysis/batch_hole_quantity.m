function batch_hole_quantity(base_dir, datasets, varargin)
    % Batch hole quantification
    %   base_dir: root data directory
    %   datasets: cell array of dataset names, e.g. {'25mj','75mj','150mj'}
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RegionSize', sz - central region size, default 750
    %     'Threshold', t - skin surface threshold, default 20
    %     'ShallowRatio', r - shallow-depth ratio, default 1
    %     'ExcelPath', path - Excel output path
    %     'DrawPCA', true/false - whether to draw the PCA axis on the output image, default true
    %   The quantification method is identical to batch_surface_pca: the depth axis is selected from the measured surface normal, and cross_section uses per-slice convex hulls
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'Threshold', 20);
    addParameter(p, 'ShallowRatio', 1);
    addParameter(p, 'ExcelPath', '');
    addParameter(p, 'DrawPCA', true);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    region_size = p.Results.RegionSize;
    thre = p.Results.Threshold;
    shallow_ratio = p.Results.ShallowRatio;
    draw_pca = p.Results.DrawPCA;

    if isempty(p.Results.ExcelPath)
        excel_path = fullfile(base_dir, 'hole_quantity_analysis.xlsx');
    else
        excel_path = p.Results.ExcelPath;
    end

    voxel_volume = prod(resolution);
    results = table('Size', [0, 8], ...
        'VariableTypes', {'string','string','double','double','double','double','double','double'}, ...
        'VariableNames', {'Dataset','Filename','Volume','Depth','MaxArea','MaxPerimeter','MaxRadius','SurfaceAngle'});

    % Load the existing Excel file (checkpoint resume: use dataset|filename as the key so same-named files in different datasets are not skipped by mistake)
    if exist(excel_path, 'file')
        existing_data = readtable(excel_path);
        if ismember('Dataset', existing_data.Properties.VariableNames)
            processed = string(existing_data.Dataset) + "|" + string(existing_data.Filename);
        else
            processed = strings(0, 1);
        end
    else
        existing_data = table();
        processed = strings(0, 1);
    end

    for ds_idx = 1:length(datasets)
        dataset = datasets{ds_idx};
        fprintf('\n===== Processing dataset: %s =====\n', dataset);

        original_dir = fullfile(base_dir, [dataset '_4d_select']);
        segmented_dir = fullfile(base_dir, [dataset '_4d_select_hole_result']);
        output_dir = fullfile(base_dir, [dataset '_4d_select_hole_liantongyu']);

        if ~exist(output_dir, 'dir'); mkdir(output_dir); end

        original_files = dir(fullfile(original_dir, '*.tif'));
        for file_idx = 1:length(original_files)
            [~, name, ext] = fileparts(original_files(file_idx).name);
            filename = [name ext];

            current_key = string(dataset) + "|" + string(filename);
            if any(processed == current_key)
                fprintf('File %s (dataset %s) already processed, skipping\n', filename, dataset);
                continue;
            end

            fprintf('Processing: %s (%d/%d)\n', filename, file_idx, length(original_files));
            original_path = fullfile(original_dir, filename);
            segmented_path = fullfile(segmented_dir, filename);

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
            if numObj == 0
                warning('No hole found in the central region of file %s, skipping', filename);
                continue;
            end

            % Extract coordinates
            [y, x, z] = ind2sub(size(cleanedVolume), find(cleanedVolume));
            coords = [x*resolution(1), y*resolution(2), z*resolution(3)];

            % ROI-level surface normal (same source as the surface PCA analysis)
            [~, skin_smoothed] = skin_surface(originalVolume, dataset, thre);
            normal = surface_normal(skin_smoothed, resolution, dataset);

            % PCA: take the principal axis closest to the surface normal as the depth axis
            [centroid, ~, ~, selected_PC, min_angle] = pca_analysis(coords, 'SurfaceNormal', normal);
            projections = (coords - centroid) * selected_PC';
            min_proj = min(projections);
            max_proj = max(projections);
            hole_depth = max_proj - min_proj;
            total_volume = sum(cleanedVolume(:)) * voxel_volume;
            % Tilt angle: 0° = axis parallel to the surface, 90° = axis perpendicular to the surface
            surface_angle = 90 - min_angle;

            % Shallow-slice parameters (per-slice convex hull, identical to batch_surface_pca)
            shallow_depth = min_proj + shallow_ratio * hole_depth;
            shallow_coords = coords(projections <= shallow_depth, :);
            if size(shallow_coords, 1) >= 3
                [~, areas, perimeters, radii] = cross_section(coords, centroid, selected_PC, 100);
                shallow_idx = linspace(min_proj, max_proj, 100) <= shallow_depth;
                valid_a = areas(shallow_idx); valid_a = valid_a(valid_a > 0);
                valid_p = perimeters(shallow_idx); valid_p = valid_p(valid_p > 0);
                valid_r = radii(shallow_idx); valid_r = valid_r(valid_r > 0);
                max_area = max(valid_a); if isempty(valid_a); max_area = 0; end
                perimeter = max(valid_p); if isempty(valid_p); perimeter = 0; end
                max_radius = max(valid_r); if isempty(valid_r); max_radius = 0; end
            else
                max_area = 0; perimeter = 0; max_radius = 0;
            end

            % Create the output image
            if draw_pca
                max_val = double(max(originalVolume(:)));
                if max_val == 0; max_val = 1; end
                output_volume = uint8(double(originalVolume) / max_val * 200);
                output_volume(cleanedVolume) = 255;

                lineStart = centroid + selected_PC * min_proj;
                lineEnd = centroid + selected_PC * max_proj;
                for k = 1:numSlices
                    z_pos = k * resolution(3);
                    t = (z_pos - lineStart(3)) / (lineEnd(3) - lineStart(3));
                    if t < 0 || t > 1; continue; end
                    ix = lineStart(1) + t*(lineEnd(1)-lineStart(1));
                    iy = lineStart(2) + t*(lineEnd(2)-lineStart(2));
                    px = max(1, min(width, round(ix/resolution(1))));
                    py = max(1, min(height, round(iy/resolution(2))));
                    ll = round(sqrt(sum(cleanedVolume(:))) / 10);
                    for dx = max(1,px-ll):min(width,px+ll)
                        if py>=1 && py<=height; output_volume(py,dx,k)=254; end
                    end
                    for dy = max(1,py-ll):min(height,py+ll)
                        if px>=1 && px<=width; output_volume(dy,px,k)=254; end
                    end
                end
                save_tiff_stack(output_volume, fullfile(output_dir, filename));
            end

            % Record the result
            new_row = {dataset, filename, total_volume, hole_depth, max_area, perimeter, max_radius, surface_angle};
            results = [results; new_row];
            if isempty(existing_data)
                writetable(cell2table(new_row, 'VariableNames', results.Properties.VariableNames), excel_path);
                existing_data = cell2table(new_row, 'VariableNames', results.Properties.VariableNames);
            else
                combined = [existing_data; cell2table(new_row, 'VariableNames', results.Properties.VariableNames)];
                writetable(combined, excel_path);
                existing_data = combined;
            end
            processed(end+1, 1) = current_key;

            fprintf('  Volume:%.0f Depth:%.0f Area:%.0f Perimeter:%.0f Radius:%.0f Surface angle:%.1f°\n', ...
                total_volume, hole_depth, max_area, perimeter, max_radius, surface_angle);
        end
    end
    fprintf('\nAll datasets processed, results: %s\n', excel_path);
end
