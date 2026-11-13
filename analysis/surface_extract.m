function surface_extract(base_dir, datasets, varargin)
    % Batch extraction of the skin surface and generation of annotation images
    %   base_dir: root data directory
    %   datasets: cell array of dataset names
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RegionSize', sz - central region size, default 750
    %     'Threshold', t - surface threshold, default 20
    %     'MarkHole', true/false - whether to mark the hole region, default false
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'Threshold', 20);
    addParameter(p, 'MarkHole', false);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    region_size = p.Results.RegionSize;
    thre = p.Results.Threshold;
    mark_hole = p.Results.MarkHole;

    for ds_idx = 1:length(datasets)
        dataset = datasets{ds_idx};
        fprintf('\n===== Processing dataset: %s =====\n', dataset);

        original_dir = fullfile(base_dir, [dataset '_4d_select']);
        output_dir = fullfile(base_dir, [dataset '_4d_select_surface']);
        hole_dir = fullfile(base_dir, [dataset '_4d_select_hole_result']);

        if ~exist(output_dir, 'dir'); mkdir(output_dir); end
        have_hole = exist(hole_dir, 'dir') && mark_hole;

        files = dir(fullfile(original_dir, '*.tif'));
        for fIdx = 1:length(files)
            [~, name, ext] = fileparts(files(fIdx).name);
            filename = [name ext];
            fprintf('Processing: %s (%d/%d)\n', filename, fIdx, length(files));

            originalVolume = read_tiff_stack(fullfile(original_dir, filename));
            [height, width, numSlices] = size(originalVolume);
            [x_start, x_end, y_start, y_end] = central_region(width, height, region_size);

            % Extract the skin surface
            [~, skin_smoothed] = skin_surface(originalVolume, dataset, thre);

            % Create the output
            outputVolume = originalVolume ./ 2;

            % Mark the hole
            if have_hole
                hole_path = fullfile(hole_dir, filename);
                if exist(hole_path, 'file')
                    holeVol = read_tiff_stack(hole_path);
                    hole_region = false(size(holeVol));
                    hole_region(y_start:y_end, x_start:x_end, :) = holeVol(y_start:y_end, x_start:x_end, :) == 255;
                    outputVolume(hole_region) = 253;
                end
            end

            % Mark the surface line
            for z = 1:numSlices
                for x = 1:width
                    sy = round(skin_smoothed(x, z));
                    if ~isnan(sy) && sy >= 1 && sy <= height
                        for offset = -2:2
                            yp = sy + offset;
                            if yp >= 1 && yp <= height
                                outputVolume(yp, x, z) = 252;
                            end
                        end
                    end
                end
            end

            save_tiff_stack(outputVolume, fullfile(output_dir, filename));
            fprintf('  Saved: %s\n', fullfile(output_dir, filename));
        end
    end
end
