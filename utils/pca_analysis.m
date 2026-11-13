function [centroid, eigenVectors, eigenValues, selected_PC, min_angle] = pca_analysis(coords, varargin)
    % PCA with multiple principal-component selection strategies
    %   coords: N×3 matrix of physical coordinates
    %   Optional parameters:
    %     'SurfaceNormal', vec - select the principal component with the smallest angle to the surface normal
    %     'YAxis' - select the principal component with the smallest angle to the Y axis
    %   Returns:
    %     centroid: centroid coordinates
    %     eigenVectors: eigenvector matrix (sorted by descending eigenvalue)
    %     eigenValues: eigenvalues (descending)
    %     selected_PC: selected principal-component direction
    %     min_angle: angle between the selected principal component and the reference direction (degrees)
    p = inputParser;
    addParameter(p, 'SurfaceNormal', []);
    addParameter(p, 'YAxis', false);
    parse(p, varargin{:});

    centroid = mean(coords, 1);
    centeredCoords = coords - centroid;
    covariance = cov(centeredCoords);
    [eigenVectors, eigenValues] = eig(covariance, 'vector');
    [eigenValues, idx] = sort(eigenValues, 'descend');
    eigenVectors = eigenVectors(:, idx);

    if ~isempty(p.Results.SurfaceNormal)
        normal = p.Results.SurfaceNormal(:);
        angles = zeros(1, 3);
        for i = 1:3
            angles(i) = acosd(abs(dot(eigenVectors(:,i), normal)));
        end
        [min_angle, min_idx] = min(angles);
        selected_PC = eigenVectors(:, min_idx)';
        if dot(selected_PC, normal) < 0
            selected_PC = -selected_PC;
        end
    elseif p.Results.YAxis
        y_axis = [0 1 0];
        angles = [acosd(abs(dot(eigenVectors(:,1), y_axis))), ...
                  acosd(abs(dot(eigenVectors(:,2), y_axis))), ...
                  acosd(abs(dot(eigenVectors(:,3), y_axis)))];
        [min_angle, min_idx] = min(angles);
        selected_PC = eigenVectors(:, min_idx)';
    else
        selected_PC = eigenVectors(:,1)';
        min_angle = NaN;
    end
end
