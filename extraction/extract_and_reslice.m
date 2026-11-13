function extract_and_reslice(folder1, folder2, excel_path, square_size)
    % Extract square regions from TIFFs, reslice along xz, rotate 90° clockwise, and save as 3D TIFFs
    %   folder1: path to the input TIFF folder
    %   folder2: path to the output folder
    %   excel_path: path to the Excel file
    %   square_size: side length of the square (pixels)
    if ~exist(folder2, 'dir'); mkdir(folder2); end

    xy_resolution = 3.25;
    z_resolution_original = 2;
    z_resolution_target = 2;

    data = readtable(excel_path);

    for i = 1:height(data)
        row = data(i,:);
        point_id = num2str(row{1,1});
        x_center = int32(row{1,2});
        y_center = int32(row{1,3});
        start_z = row{1,4};
        end_z = row{1,5} + 50;

        half_size = square_size / 2;
        x_start = x_center - half_size;
        x_end = x_center + half_size - 1;
        y_start = y_center - half_size;
        y_end = y_center + half_size - 1;

        z_layers = end_z - start_z + 1;
        cube = zeros(square_size, square_size, z_layers, 'uint8');
        valid_layers = 0;

        tif_files = dir(fullfile(folder1, '*.tif'));

        for z = start_z:end_z
            if z > length(tif_files); continue; end
            tif_path = fullfile(folder1, tif_files(z).name);
            try
                image = imread(tif_path) / 255;
                if x_start<1 || x_end>size(image,2) || y_start<1 || y_end>size(image,1)
                    y_e = min(y_end, size(image,1)); x_e = min(x_end, size(image,2));
                    x_s = max(x_start, 1); y_s = max(y_start, 1);
                    extracted = image(y_s:y_e, x_s:x_e);
                    tmp = zeros(square_size, square_size, 'uint8');
                    y_off = y_s - y_start + 1; x_off = x_s - x_start + 1;
                    tmp(y_off:y_off+size(extracted,1)-1, x_off:x_off+size(extracted,2)-1) = extracted;
                    cube(:,:,valid_layers+1) = tmp;
                else
                    cube(:,:,valid_layers+1) = image(y_start:y_end, x_start:x_end);
                end
                valid_layers = valid_layers + 1;
            catch e
                fprintf('Error processing %s: %s\n', tif_path, e.message);
            end
        end

        if valid_layers > 0
            output_cube = cube(:,:,1:valid_layers);

            % Interpolation along z
            [ys, xs, zs] = size(output_cube);
            z_target = round(zs * z_resolution_original / z_resolution_target);
            interp_cube = zeros(ys, xs, z_target, 'uint8');
            for y = 1:ys
                for x = 1:xs
                    profile = double(squeeze(output_cube(y,x,:)));
                    interp_profile = interp1(1:zs, profile, linspace(1,zs,z_target), 'spline');
                    interp_profile = max(0, min(255, interp_profile));
                    interp_cube(y,x,:) = uint8(interp_profile);
                end
            end

            % xz reslicing: [y,x,z] -> [x,z,y]
            [ys, xs, zs] = size(interp_cube);
            reslice = zeros(xs, zs, ys, 'uint8');
            for y = 1:ys
                reslice(:,:,y) = squeeze(interp_cube(y,:,:));
            end

            % Rotate 90° clockwise: rot90(slice, -1)
            [h, w, d] = size(reslice);
            rotated = zeros(w, h, d, 'uint8');
            for k = 1:d
                rotated(:,:,k) = rot90(reslice(:,:,k), -1);
            end

            output_path = fullfile(folder2, [point_id '.tif']);
            for k = 1:size(rotated,3)
                if k == 1; imwrite(rotated(:,:,k), output_path);
                else; imwrite(rotated(:,:,k), output_path, 'WriteMode', 'append'); end
            end
            fprintf('Saved point %s: %d layers -> interpolated %d layers -> resliced %d layers\n', ...
                point_id, size(output_cube,3), z_target, d);
        else
            fprintf('Warning: point %s has no valid layers\n', point_id);
        end
    end
end
