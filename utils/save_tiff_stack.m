function save_tiff_stack(volume, filepath, compression)
    % Save a 3D matrix as a multi-page TIFF file
    %   volume: 3D matrix [height, width, numSlices]
    %   filepath: output path
    %   compression: compression method, defaults to 'none'
    if nargin < 3
        compression = 'none';
    end
    if exist(filepath, 'file')
        delete(filepath);
    end
    numSlices = size(volume, 3);
    for k = 1:numSlices
        if k == 1
            imwrite(volume(:,:,k), filepath, 'Compression', compression);
        else
            imwrite(volume(:,:,k), filepath, 'WriteMode', 'append', 'Compression', compression);
        end
    end
end
