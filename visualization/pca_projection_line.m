function pca_projection_line(originalFile, segFile, outputFile, varargin)
    % Mark the PCA projection line on the original image (merges show_skin v1 and v2)
    %   originalFile: path to the original TIFF
    %   segFile: path to the segmentation result TIFF
    %   outputFile: output TIFF path
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RegionSize', sz - default 750
    %     'Mode', 'line'|'point' - 'line' (v1: PC1 projection line) / 'point' (v2: PC1 intersection markers), default 'line'
    %     'PCIndex', idx - PC component to use (1/2/3), default 1
    %     'MarkRadius', r - intersection marker radius (v2 mode), default 20
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RegionSize', 750);
    addParameter(p, 'Mode', 'line');
    addParameter(p, 'PCIndex', 1);
    addParameter(p, 'MarkRadius', 20);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    region_size = p.Results.RegionSize;
    mode = p.Results.Mode;
    pc_idx = p.Results.PCIndex;
    mark_radius = p.Results.MarkRadius;

    info = imfinfo(originalFile);
    numSlices = numel(info);
    width = info(1).Width; height = info(1).Height;
    [x_start, x_end, y_start, y_end] = central_region(width, height, region_size);

    originalVolume = read_tiff_stack(originalFile);
    segVolume = read_tiff_stack(segFile);

    % Connected-component analysis
    binaryVolume = false(size(segVolume));
    binaryVolume(y_start:y_end, x_start:x_end, :) = segVolume(y_start:y_end, x_start:x_end, :) == 255;
    [cleanedVolume, ~] = largest_cc(binaryVolume, 26);

    % Extract hole coordinates
    [y, x, z] = ind2sub(size(segVolume), find(segVolume == 255));
    coords = [x*resolution(1), y*resolution(2), z*resolution(3)];

    % PCA
    [centroid, eigenVectors, eigenValues] = pca_analysis(coords);
    selected_PC = eigenVectors(:, pc_idx)';

    % Create the output
    newVolume = originalVolume;

    if strcmp(mode, 'line')
        % v1 mode: draw the PC projection segment across the whole image
        axisLength = 0.8 * max(range(coords));
        lineStart = centroid - axisLength * selected_PC;
        lineEnd = centroid + axisLength * selected_PC;

        for k = 1:numSlices
            z_phy = k * resolution(3);
            if z_phy < min(lineStart(3), lineEnd(3)) || z_phy > max(lineStart(3), lineEnd(3))
                continue;
            end

            if lineEnd(3) ~= lineStart(3)
                t = (z_phy - lineStart(3)) / (lineEnd(3) - lineStart(3));
            else
                t = 0.5;
            end

            intersectX = lineStart(1) + t*(lineEnd(1)-lineStart(1));
            intersectY = lineStart(2) + t*(lineEnd(2)-lineStart(2));
            ix_px = intersectX / resolution(1);
            iy_px = intersectY / resolution(2);

            % Segment from the left to the right boundary of the image
            x1_px = 1;
            y1_px = iy_px + (x1_px-ix_px)*(lineEnd(2)-lineStart(2))/(lineEnd(1)-lineStart(1));
            x2_px = width;
            y2_px = iy_px + (x2_px-ix_px)*(lineEnd(2)-lineStart(2))/(lineEnd(1)-lineStart(1));

            y1_px = max(1, min(height, round(y1_px)));
            y2_px = max(1, min(height, round(y2_px)));

            % Draw the line with Bresenham
            [x_line, y_line] = bresenham_2d(x1_px, y1_px, x2_px, y2_px);
            valid = x_line>=1 & x_line<=width & y_line>=1 & y_line<=height;
            for i = 1:length(x_line)
                if valid(i)
                    newVolume(y_line(i), x_line(i), k) = 255;
                end
            end
        end
    else
        % v2 mode: draw a circular marker at the PC1 intersection on each slice
        for k = 1:numSlices
            z_phys = k * resolution(3);
            t = (z_phys - centroid(3)) / selected_PC(3);
            x_phys = centroid(1) + t*selected_PC(1);
            y_phys = centroid(2) + t*selected_PC(2);
            x_pix = round(x_phys / resolution(1));
            y_pix = round(y_phys / resolution(2));

            if x_pix>0 && x_pix<=width && y_pix>0 && y_pix<=height
                [X, Y] = meshgrid(1:width, 1:height);
                mask = (X-x_pix).^2 + (Y-y_pix).^2 <= mark_radius^2;
                slice = newVolume(:,:,k);
                slice(mask) = 255;
                newVolume(:,:,k) = slice;
            end
        end
    end

    % Save
    if exist(outputFile, 'file'); delete(outputFile); end
    for k = 1:numSlices
        imwrite(newVolume(:,:,k), outputFile, 'WriteMode', 'append', 'Compression', 'none');
    end
    fprintf('Annotated image saved: %s\n', outputFile);

    % Console output
    fprintf('PCA centroid: [%.2f, %.2f, %.2f] μm\n', centroid);
    fprintf('Selected PC%d direction: [%.4f, %.4f, %.4f]\n', pc_idx, selected_PC);
    fprintf('Explained variance: %.1f%%\n', 100*eigenValues(pc_idx)/sum(eigenValues));
end

function [x, y] = bresenham_2d(x1, y1, x2, y2)
    x1=round(x1); y1=round(y1); x2=round(x2); y2=round(y2);
    dx=abs(x2-x1); dy=abs(y2-y1);
    steep = dy>dx;
    if steep; [x1,y1]=deal(y1,x1); [x2,y2]=deal(y2,x2); end
    if x1>x2; [x1,x2]=deal(x2,x1); [y1,y2]=deal(y2,y1); end
    dx=x2-x1; dy=abs(y2-y1);
    err=dx/2; ystep=sign(y2-y1); y=y1;
    x_out=x1:x2; y_out=zeros(1,length(x_out));
    for i=1:length(x_out)
        if steep; y_out(i)=x_out(i); x_out(i)=y;
        else; y_out(i)=y; end
        err=err-dy; if err<0; y=y+ystep; err=err+dx; end
    end
    x=x_out; y=y_out;
end
