function extract_squares(folder1, folder2, excel_path, square_size)
    % Extract square regions centered on Excel coordinate points from TIFF files and save them as 3D TIFFs
    %   folder1: path to the input TIFF folder
    %   folder2: path to the output folder
    %   excel_path: path to the Excel file
    %   square_size: side length of the square (pixels); odd values are recommended
    if ~exist(folder2, 'dir'); mkdir(folder2); end

    data = readtable(excel_path);
    tif_files = dir(folder1);

    for i = 1:height(data)
        row = data(i,:);
        point_id = num2str(row{1,1});
        x_center = int32(row{1,2});
        y_center = int32(row{1,3});
        start_z = row{1,4};
        end_z = row{1,5};

        half_size = square_size / 2;
        x_start = x_center - half_size;
        x_end = x_center + half_size - 1;
        y_start = y_center - half_size;
        y_end = y_center + half_size - 1;

        z_layers = end_z - start_z + 1;
        cube = zeros(square_size, square_size, z_layers, 'uint8');
        valid_layers = 0;

        for z = start_z:end_z
            if z > length(tif_files)
                fprintf('Warning: z=%d is out of file range\n', z);
                continue;
            end

            tif_path = fullfile(folder1, tif_files(z).name);
            try
                info = imfinfo(tif_path);
                if info.BitDepth == 8
                    image = imread(tif_path);
                else
                    image = imread(tif_path) / 255;
                end

                if x_start < 1 || x_end > size(image,2) || y_start < 1 || y_end > size(image,1)
                    y_end_adj = min(y_end, size(image,1));
                    x_end_adj = min(x_end, size(image,2));
                    x_start_adj = max(x_start, 1);
                    y_start_adj = max(y_start, 1);
                else
                    x_start_adj = x_start; x_end_adj = x_end;
                    y_start_adj = y_start; y_end_adj = y_end;
                end

                valid_layers = valid_layers + 1;
                cube(1:y_end_adj-y_start_adj+1, 1:x_end_adj-x_start_adj+1, valid_layers) = ...
                    image(y_start_adj:y_end_adj, x_start_adj:x_end_adj);
            catch e
                fprintf('Error processing %s: %s\n', tif_path, e.message);
            end
        end

        if valid_layers > 0
            output_cube = cube(:,:,1:valid_layers);
            output_path = fullfile(folder2, [point_id '.tif']);
            for k = 1:size(output_cube,3)
                if k == 1; imwrite(output_cube(:,:,k), output_path);
                else; imwrite(output_cube(:,:,k), output_path, 'WriteMode', 'append'); end
            end
            fprintf('Saved point %s: %d layers\n', point_id, valid_layers);
        else
            fprintf('Warning: point %s has no valid layers\n', point_id);
        end
    end
end
