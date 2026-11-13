function [obj_count, total_volume_um3, density, volume_fraction, ...
          mean_sphericity, std_sphericity, obj_volumes_um3, obj_sphericity, ...
          injury_volume_um3] = ...
          cell_morphology(binaryVolume, injuryVolume, resolution, volume_threshold)
    % Morphological quantification of cells (PI-positive nucleus-like objects): count/volume/density/volume fraction/sphericity
    %   binaryVolume: binary cell volume (logical or numeric, >0 treated as object)
    %   injuryVolume: binary damage-region volume (numeric, ==255 or >0 treated as damage region)
    %   resolution: [x, y, z] resolution (μm/pixel)
    %   volume_threshold: minimum voxel count, default 10 (per the paper: fewer than 10 voxels is treated as a fragment)
    %   Returns:
    %     obj_count: number of objects after filtering
    %     total_volume_um3: total object volume (μm³)
    %     density: number of objects / damage-region volume (objects/μm³)
    %     volume_fraction: total object volume / damage-region volume
    %     mean_sphericity / std_sphericity: mean and standard deviation of sphericity
    %     obj_volumes_um3 / obj_sphericity: per-object volume and sphericity
    %     injury_volume_um3: damage-region volume (denominator for density and volume fraction)
    if nargin < 3 || isempty(resolution)
        resolution = [1.3, 1.3, 1.0];
    end
    if nargin < 4 || isempty(volume_threshold)
        volume_threshold = 10;
    end

    voxel_volume = prod(resolution);

    obj_count = 0;
    total_volume_um3 = 0;
    density = 0;
    volume_fraction = 0;
    mean_sphericity = 0;
    std_sphericity = 0;
    obj_volumes_um3 = [];
    obj_sphericity = [];

    % Damage-region volume (denominator)
    %   Note: <dataset>_4d_select_sunshang_liantongyu is an overlay image
    %   (raw grayscale/2 + 254 PCA line + 255 damage label), so the damage region must be extracted with ==255;
    %   if a pure binary mask is passed in, fall back to >0
    injury_volume_um3 = 0;
    if ~isempty(injuryVolume)
        if islogical(injuryVolume) || max(injuryVolume(:)) <= 1
            injury_mask = injuryVolume > 0;
        else
            injury_mask = (injuryVolume == 255);
        end
        injury_volume_um3 = nnz(injury_mask) * voxel_volume;
    end

    labeled = bwlabeln(binaryVolume > 0, 26);
    if max(labeled(:)) == 0
        return;
    end

    % A single regionprops3 call to get the voxel count (Volume) and surface area (SurfaceArea, in voxel units)
    stats = regionprops3(labeled, 'Volume', 'SurfaceArea');
    voxel_counts = double(stats.Volume);
    keep = voxel_counts >= volume_threshold;
    if ~any(keep)
        return;
    end

    voxel_counts = voxel_counts(keep);
    surface_vox = double(stats.SurfaceArea(keep));

    obj_count = numel(voxel_counts);
    obj_volumes_um3 = voxel_counts * voxel_volume;
    total_volume_um3 = sum(obj_volumes_um3);

    % Convert surface area to physical units: isotropic approximation (dx*dy*dz)^(2/3)
    surface_um2 = surface_vox * voxel_volume^(2/3);

    % Sphericity = (36*pi*V^2)^(1/3) / S; closer to 1 means closer to a sphere
    obj_sphericity = zeros(size(obj_volumes_um3));
    valid = obj_volumes_um3 > 0 & surface_um2 > 0;
    obj_sphericity(valid) = (36 * pi * obj_volumes_um3(valid).^2).^(1/3) ./ surface_um2(valid);
    obj_sphericity = min(obj_sphericity, 1);

    mean_sphericity = mean(obj_sphericity);
    std_sphericity = std(obj_sphericity);

    % Density and volume fraction; the denominator is the damage-region volume
    if injury_volume_um3 > 0
        density = obj_count / injury_volume_um3;
        volume_fraction = total_volume_um3 / injury_volume_um3;
    else
        density = NaN;
        volume_fraction = NaN;
    end
end
