function batch_cell_damage(base_path, cell_folders)
    % Batch cell-damage intersection analysis: compute the intersection of cell regions and damage regions
    %   base_path: root data directory
    %   cell_folders: N×3 cell array, each row {cell folder, damage folder, output folder}
    %
    %   Example:
    %     cell_folders = {
    %       '25mj_4d_select_cell_result', '25mj_4d_select_sunshang_liantongyu', '25mj_4d_select_cell_sunshang'
    %     };
    %     batch_cell_damage('F:\hole_seg\dataset25_75_150', cell_folders);

    for folder_idx = 1:size(cell_folders, 1)
        cell_folder = cell_folders{folder_idx, 1};
        damage_folder = cell_folders{folder_idx, 2};
        output_folder = cell_folders{folder_idx, 3};

        fprintf('\nProcessing: %s + %s -> %s\n', cell_folder, damage_folder, output_folder);

        cell_path = fullfile(base_path, cell_folder);
        damage_path = fullfile(base_path, damage_folder);
        output_path = fullfile(base_path, output_folder);

        if ~exist(output_path, 'dir'); mkdir(output_path); end

        cell_files = dir(fullfile(cell_path, '*.tif'));
        for fIdx = 1:length(cell_files)
            filename = cell_files(fIdx).name;
            cell_file = fullfile(cell_path, filename);
            damage_file = fullfile(damage_path, filename);
            output_file = fullfile(output_path, filename);

            if ~exist(damage_file, 'file')
                fprintf('  Warning: damage file %s does not exist\n', filename);
                continue;
            end

            try
                process_damage_file(cell_file, damage_file, output_file);
                fprintf('  Done: %s\n', filename);
            catch ME
                fprintf('  Error: %s - %s\n', filename, ME.message);
            end
        end
    end
    fprintf('\nAll processing completed!\n');
end

function process_damage_file(cell_path, damage_path, output_path)
    cell_data = read_tiff_stack(cell_path);
    damage_data = read_tiff_stack(damage_path);

    if ~isequal(size(cell_data), size(damage_data))
        error('Data dimensions do not match');
    end

    if ~islogical(cell_data); cell_binary = cell_data > 0; else; cell_binary = cell_data; end
    damage_binary = damage_data == 255;
    result = cell_binary & damage_binary;

    if ~islogical(cell_data); result = cast(result, class(cell_data)) .* cell_data; end
    save_tiff_stack(result, output_path);
end
