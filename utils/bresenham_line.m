function line = bresenham_line(p1, p2)
    % 3D Bresenham line algorithm; returns the coordinates of all voxels the line passes through
    %   p1, p2: 3D coordinate points [x, y, z]
    %   Returns:
    %     line: N×3 matrix, each row is the [x, y, z] coordinate of one point on the line
    x1 = p1(1); y1 = p1(2); z1 = p1(3);
    x2 = p2(1); y2 = p2(2); z2 = p2(3);

    dx = abs(x2 - x1); dy = abs(y2 - y1); dz = abs(z2 - z1);
    xs = sign(x2 - x1); ys = sign(y2 - y1); zs = sign(z2 - z1);

    if (dx >= dy) && (dx >= dz)
        line = bresenham_drive(x1, y1, z1, dx, dy, dz, xs, ys, zs, 1);
    elseif (dy >= dx) && (dy >= dz)
        line = bresenham_drive(y1, x1, z1, dy, dx, dz, ys, xs, zs, 2);
    else
        line = bresenham_drive(z1, x1, y1, dz, dx, dy, zs, xs, ys, 3);
    end
end

function line = bresenham_drive(x1, y1, z1, dx, dy, dz, xs, ys, zs, axis)
    p1 = 2 * dy - dx;
    p2 = 2 * dz - dx;
    line = zeros(dx + 1, 3);
    x = x1; y = y1; z = z1;
    for i = 0:dx
        switch axis
            case 1; line(i+1, :) = [x, y, z];
            case 2; line(i+1, :) = [y, x, z];
            case 3; line(i+1, :) = [z, x, y];
        end
        x = x + xs;
        if p1 >= 0; y = y + ys; p1 = p1 - 2 * dx; end
        if p2 >= 0; z = z + zs; p2 = p2 - 2 * dx; end
        p1 = p1 + 2 * dy;
        p2 = p2 + 2 * dz;
    end
end
