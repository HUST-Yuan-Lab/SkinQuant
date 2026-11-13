function [skin_surface, skin_surface_smoothed] = skin_surface(originalVolume, dataset, thre)
    % Extract the skin surface from the raw 3D data
    %   originalVolume: raw 3D data [height, width, numSlices]
    %   dataset: dataset name (determines the extraction direction); '150mj' scans from the bottom up, others from the top down
    %   thre: threshold, default 20
    %   Returns:
    %     skin_surface: raw surface [width, numSlices]
    %     skin_surface_smoothed: smoothed surface
    if nargin < 3
        thre = 20;
    end
    [height, width, numSlices] = size(originalVolume);
    skin_surface = zeros(width, numSlices);

    if strcmp(dataset, '150mj')
        % Scan from the bottom up (negative Y direction)
        for i = 1:width
            for j = 1:numSlices
                depth_idx = find(originalVolume(:,i,j) > thre, 1, 'last');
                if ~isempty(depth_idx)
                    skin_surface(i,j) = depth_idx;
                else
                    skin_surface(i,j) = NaN;
                end
            end
        end
    else
        % Scan from the top down (positive Y direction)
        for i = 1:width
            for j = 1:numSlices
                depth_idx = find(originalVolume(:,i,j) > thre, 1, 'first');
                if ~isempty(depth_idx)
                    skin_surface(i,j) = depth_idx;
                else
                    skin_surface(i,j) = NaN;
                end
            end
        end
    end
    skin_surface_smoothed = imgaussfilt(skin_surface, 2);
end
