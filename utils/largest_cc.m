function [cleanedVolume, numObjects] = largest_cc(binaryVolume, connectivity)
    % Connected-component analysis: keep the largest component and remove specks
    %   binaryVolume: 3D binary matrix
    %   connectivity: connectivity (6/18/26), default 26
    %   Returns:
    %     cleanedVolume: binary matrix containing only the largest connected component
    %     numObjects: total number of connected components
    if nargin < 2
        connectivity = 26;
    end
    cc = bwconncomp(binaryVolume, connectivity);
    numObjects = cc.NumObjects;
    if numObjects == 0
        cleanedVolume = false(size(binaryVolume));
        return;
    end
    regionSizes = cellfun(@numel, cc.PixelIdxList);
    [~, largestIdx] = max(regionSizes);
    cleanedVolume = false(size(binaryVolume));
    cleanedVolume(cc.PixelIdxList{largestIdx}) = true;
end
