function batch_connectivity_filter(input_dirs, output_dirs, varargin)
    % Batch connectivity filtering: keep the largest connected component in the central region and remove specks
    %   input_dirs: cell array of input directories
    %   output_dirs: cell array of output directories
    %   Optional parameters:
    %     'RegionSize', sz - central region size, default 750
    %     'Connectivity', c - connectivity (6/18/26), default 26
    p = inputParser;
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'Connectivity', 26);
    parse(p, varargin{:});
    region_size = p.Results.RegionSize;
    conn = p.Results.Connectivity;

    if length(input_dirs) ~= length(output_dirs)
        error('The number of input and output directories must match');
    end

    for dir_idx = 1:length(input_dirs)
        fprintf('\nProcessing directory: %s\n', input_dirs{dir_idx});

        if ~exist(output_dirs{dir_idx}, 'dir')
            mkdir(output_dirs{dir_idx});
        end

        files = dir(fullfile(input_dirs{dir_idx}, '*.tif'));
        for fIdx = 1:length(files)
            [~, name, ext] = fileparts(files(fIdx).name);
            filename = [name ext];
            fprintf('  Processing: %s (%d/%d)\n', filename, fIdx, length(files));

            segmentedVolume = read_tiff_stack(fullfile(input_dirs{dir_idx}, filename));
            [height, width, numSlices] = size(segmentedVolume);
            [x_start, x_end, y_start, y_end] = central_region(width, height, region_size);

            binaryVolume = false(size(segmentedVolume));
            binaryVolume(y_start:y_end, x_start:x_end, :) = segmentedVolume(y_start:y_end, x_start:x_end, :) == 255;

            [cleanedVolume, numObj] = largest_cc(binaryVolume, conn);
            if numObj == 0
                warning('    No hole found, skipping');
                continue;
            end

            output_volume = uint8(cleanedVolume) * 255;
            save_tiff_stack(output_volume, fullfile(output_dirs{dir_idx}, filename));
            fprintf('    Done\n');
        end
    end
    fprintf('\nAll directories processed!\n');
end
