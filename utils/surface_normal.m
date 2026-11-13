function surface_normal = surface_normal(skin_surface, resolution, dataset)
    % Compute the mean normal vector of the skin surface
    %   skin_surface: surface height map [width, numSlices]
    %   resolution: [x, y, z] resolution (μm/pixel)
    %   dataset: dataset name, determines the direction the normal points to
    %   Returns:
    %     surface_normal: unit normal vector [nx, ny, nz], pointing outward from the skin (away from the tissue)
    %       for 25mj/75mj the surface is at the top of the image (scanned top-down), so the outward normal is -Y
    %       for 150mj the surface is at the bottom of the image (scanned bottom-up), so the outward normal is +Y
    if nargin < 3
        dataset = '';
    end
    [width, numSlices] = size(skin_surface);
    [X_grid, Z_grid] = meshgrid(1:width, 1:numSlices);
    X_phys = X_grid' * resolution(1);
    Z_phys = Z_grid' * resolution(3);
    Y_phys = skin_surface * resolution(2);

    [nx, ny, nz] = surfnorm(X_phys, Y_phys, Z_phys);
    valid_mask = ~isnan(nx) & ~isnan(ny) & ~isnan(nz);

    if any(valid_mask(:))
        surface_normal = [mean(nx(valid_mask)), mean(ny(valid_mask)), mean(nz(valid_mask))];
        surface_normal = surface_normal / norm(surface_normal);

        % Make sure the normal points outward from the skin (consistent with the scan start of skin_surface)
        if strcmp(dataset, '150mj')
            if surface_normal(2) < 0
                surface_normal = -surface_normal;
            end
        else
            if surface_normal(2) > 0
                surface_normal = -surface_normal;
            end
        end
    else
        warning('Unable to compute the surface normal; using the default direction');
        if strcmp(dataset, '150mj')
            surface_normal = [0, 1, 0];
        else
            surface_normal = [0, -1, 0];
        end
    end
end
