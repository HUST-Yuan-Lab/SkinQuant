function [depth_positions, areas, perimeters, max_radii] = cross_section(coords, centroid, selected_PC, num_slices)
    % Compute the cross-sectional area, perimeter, and maximum radius along the principal-component axis
    %   coords: N×3 physical coordinates
    %   centroid: centroid
    %   selected_PC: principal-component direction
    %   num_slices: number of slices, default 100
    %   Returns:
    %     depth_positions: depth position of each slice
    %     areas: convex-hull area of each slice
    %     perimeters: convex-hull perimeter of each slice
    %     max_radii: maximum distance from the slice center to a hull vertex
    if nargin < 4
        num_slices = 100;
    end

    projections = (coords - centroid) * selected_PC';
    min_proj = min(projections);
    max_proj = max(projections);

    depth_positions = linspace(min_proj, max_proj, num_slices);
    areas = zeros(1, num_slices);
    perimeters = zeros(1, num_slices);
    max_radii = zeros(1, num_slices);

    % Build an orthogonal basis
    ortho1 = cross(selected_PC, [0 0 1]);
    if norm(ortho1) < 1e-6
        ortho1 = cross(selected_PC, [0 1 0]);
    end
    ortho1 = ortho1 / norm(ortho1);
    ortho2 = cross(selected_PC, ortho1);
    ortho2 = ortho2 / norm(ortho2);

    for i = 1:num_slices
        depth = depth_positions(i);
        nearby = coords(abs(projections - depth) < 2.0, :);
        if size(nearby, 1) < 3
            continue;
        end

        % Project onto the slice plane
        proj_pts = zeros(size(nearby, 1), 2);
        for j = 1:size(nearby, 1)
            vec = nearby(j,:) - (centroid + selected_PC * depth);
            proj_pts(j,1) = dot(vec, ortho1);
            proj_pts(j,2) = dot(vec, ortho2);
        end

        k = convhull(proj_pts(:,1), proj_pts(:,2));
        hull = proj_pts(k,:);
        areas(i) = polyarea(hull(:,1), hull(:,2));
        perimeters(i) = sum(sqrt(sum(diff(hull).^2, 2)));
        center_pt = mean(hull, 1);
        max_radii(i) = max(sqrt(sum((hull - center_pt).^2, 2)));
    end
end
