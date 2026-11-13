function [x_start, x_end, y_start, y_end] = central_region(width, height, region_size)
    % Compute the boundary indices of the central region of the image
    %   width, height: image size (pixels)
    %   region_size: side length of the central square (pixels)
    %   Returns: start and end indices of the central region
    if width < region_size || height < region_size
        warning('Image size (%dx%d) is smaller than the central region size (%d); processing the entire image', ...
            width, height, region_size);
        x_start = 1; x_end = width;
        y_start = 1; y_end = height;
    else
        x_start = floor((width - region_size) / 2) + 1;
        x_end = x_start + region_size - 1;
        y_start = floor((height - region_size) / 2) + 1;
        y_end = y_start + region_size - 1;
    end
end
