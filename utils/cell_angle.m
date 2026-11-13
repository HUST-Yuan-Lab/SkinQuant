function [all_angles, all_volumes, angle_distribution, weighted_distribution, resultVolume] = ...
        cell_angle(binaryVolume, surface_normal, resolution, volume_threshold)
    % Compute the angle between the main axis of each 3D connected component and the skin surface (unified to 0-90°)
    %   The sign of the main axis is arbitrary, so the absolute value of the dot product with the normal is used
    %   0° = main axis parallel to the surface, 90° = main axis perpendicular to the surface (same definition as the hole PCA angle)
    %   binaryVolume: 3D binary cell data
    %   surface_normal: surface normal vector [nx, ny, nz]
    %   resolution: [x, y, z] resolution
    %   volume_threshold: voxel-count threshold (smaller objects ignored), default 10
    %   Returns:
    %     all_angles: angle of each connected component
    %     all_volumes: voxel count of each connected component
    %     angle_distribution: angle distribution counted by connected component
    %     weighted_distribution: angle distribution weighted by voxel count
    %     resultVolume: color-coded 3D volume (angle encoded as color index)
    if nargin < 4; volume_threshold = 10; end

    labeledVolume = bwlabeln(binaryVolume, 26);
    numRegions = max(labeledVolume(:));
    resultVolume = zeros(size(binaryVolume), 'uint8');

    all_angles = [];
    all_volumes = [];
    num_bins = 90;   % angle range 0-90° (angle to the surface plane)
    angle_distribution = zeros(num_bins + 1, 1);
    weighted_distribution = zeros(num_bins + 1, 1);

    if numRegions == 0
        return;
    end

    % Group voxel indices by connected component in advance to avoid scanning the whole volume for each component
    vol_sz = size(labeledVolume);
    lin_idx = find(labeledVolume > 0);
    lab_vals = labeledVolume(lin_idx);
    counts = accumarray(lab_vals, 1, [numRegions, 1]);
    offsets = [0; cumsum(counts)];
    [~, sort_pos] = sort(lab_vals);          % sorted positions by label (indices into lin_idx)

    for i = 1:numRegions
        voxel_count = counts(i);
        if voxel_count < volume_threshold
            continue;
        end

        idx = lin_idx(sort_pos(offsets(i)+1:offsets(i+1)));
        [y_c, x_c, z_c] = ind2sub(vol_sz, idx);
        x_phys = x_c * resolution(1);
        y_phys = y_c * resolution(2);
        z_phys = z_c * resolution(3);

        centroid = [mean(x_phys), mean(y_phys), mean(z_phys)];
        coords_centered = [x_phys - centroid(1), y_phys - centroid(2), z_phys - centroid(3)];
        cov_mat = coords_centered' * coords_centered / size(coords_centered, 1);
        [eig_vecs, eig_vals] = eig(cov_mat);
        [~, max_idx] = max(diag(eig_vals));
        orient_vec = eig_vecs(:, max_idx)' / norm(eig_vecs(:, max_idx));

        dot_val = dot(orient_vec, surface_normal);
        if isnan(dot_val)
            angle_deg = 90; color_idx = 90;
        else
            % Angle to the surface plane = 90° - angle to the normal = asin(|dot(main axis, normal)|)
            sin_angle = max(0, min(1, abs(dot_val)));
            angle_deg = min(rad2deg(asin(sin_angle)), 90);
            color_idx = max(1, min(num_bins, round(angle_deg)));
        end

        all_angles = [all_angles; angle_deg];
        all_volumes = [all_volumes; voxel_count];
        bin_idx = min(num_bins, max(0, round(angle_deg))) + 1;
        angle_distribution(bin_idx) = angle_distribution(bin_idx) + 1;
        weighted_distribution(bin_idx) = weighted_distribution(bin_idx) + voxel_count;
        resultVolume(idx) = color_idx;
    end
end
