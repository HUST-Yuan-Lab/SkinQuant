function volume = read_tiff_stack(filepath)
    % Read a multi-page TIFF file as a 3D matrix [height, width, numSlices]
    info = imfinfo(filepath);
    numSlices = numel(info);
    width = info(1).Width;
    height = info(1).Height;
    volume = zeros(height, width, numSlices, 'uint8');
    for k = 1:numSlices
        volume(:,:,k) = imread(filepath, k);
    end
end
