function pca_3d_fit(filename, varargin)
    % 3D hole PCA fitting visualization (with rotation display)
    %   filename: path to the segmentation result TIFF (holes marked as 255)
    %   Optional parameters:
    %     'Resolution', [x,y,z] - default [1.3,1.3,1.0]
    %     'RotationSpeed', deg - rotation speed (°/frame), default 1
    p = inputParser;
    addParameter(p, 'Resolution', [1.3, 1.3, 1.0]);
    addParameter(p, 'RotationSpeed', 1);
    parse(p, varargin{:});
    resolution = p.Results.Resolution;
    rotationSpeed = p.Results.RotationSpeed;

    volumeData = read_tiff_stack(filename);
    [y, x, z] = ind2sub(size(volumeData), find(volumeData == 255));
    coords = [x*resolution(1), y*resolution(2), z*resolution(3)];

    % Maximum projections
    maxProjXY = max(volumeData, [], 3);
    maxProjXZ = squeeze(max(volumeData, [], 1))';
    maxProjYZ = squeeze(max(volumeData, [], 2))';

    % PCA
    [centroid, eigenVectors, eigenValues] = pca_analysis(coords);
    PC1 = eigenVectors(:,1)'; PC2 = eigenVectors(:,2)'; PC3 = eigenVectors(:,3)';
    axisLength = 0.8 * max(range(coords));
    axisEndPC1 = centroid + axisLength * PC1;
    axisEndPC2 = centroid + axisLength * PC2;
    axisEndPC3 = centroid + axisLength * PC3;

    mainFig = figure('Position', [100, 100, 1400, 800], 'Name', '3D hole PCA');

    % 1. Original hole point cloud
    subplot(2,3,1);
    h1 = scatter3(coords(:,1), coords(:,2), coords(:,3), 10, 'filled');
    title('Hole point cloud (3D view)');
    xlabel('X (μm)'); ylabel('Y (μm)'); zlabel('Z (μm)');
    axis equal tight; grid on; view(3);
    h1.Parent.Tag = '3DView';

    % 2. Point cloud with principal components
    subplot(2,3,2);
    h2 = scatter3(coords(:,1), coords(:,2), coords(:,3), 10, 'filled'); hold on;
    plot3([centroid(1),axisEndPC1(1)], [centroid(2),axisEndPC1(2)], [centroid(3),axisEndPC1(3)], 'r-', 'LineWidth', 3);
    plot3([centroid(1),axisEndPC2(1)], [centroid(2),axisEndPC2(2)], [centroid(3),axisEndPC2(3)], 'g-', 'LineWidth', 3);
    plot3([centroid(1),axisEndPC3(1)], [centroid(2),axisEndPC3(2)], [centroid(3),axisEndPC3(3)], 'b-', 'LineWidth', 3);
    quiver3(centroid(1), centroid(2), centroid(3), axisLength, 0, 0, 'k--', 'LineWidth', 1);
    quiver3(centroid(1), centroid(2), centroid(3), 0, axisLength, 0, 'k--', 'LineWidth', 1);
    quiver3(centroid(1), centroid(2), centroid(3), 0, 0, axisLength, 'k--', 'LineWidth', 1);
    title('Point cloud with principal components'); xlabel('X'); ylabel('Y'); zlabel('Z');
    axis equal tight; grid on; view(3);
    h2.Parent.Tag = '3DView';

    % 3. Principal-component axes
    subplot(2,3,3); hold on;
    plot3([centroid(1),axisEndPC1(1)], [centroid(2),axisEndPC1(2)], [centroid(3),axisEndPC1(3)], 'r-', 'LineWidth', 3);
    plot3([centroid(1),axisEndPC2(1)], [centroid(2),axisEndPC2(2)], [centroid(3),axisEndPC2(3)], 'g-', 'LineWidth', 3);
    plot3([centroid(1),axisEndPC3(1)], [centroid(2),axisEndPC3(2)], [centroid(3),axisEndPC3(3)], 'b-', 'LineWidth', 3);
    quiver3(centroid(1), centroid(2), centroid(3), axisLength, 0, 0, 'k--');
    quiver3(centroid(1), centroid(2), centroid(3), 0, axisLength, 0, 'k--');
    quiver3(centroid(1), centroid(2), centroid(3), 0, 0, axisLength, 'k--');
    text(centroid(1)+axisLength, centroid(2), centroid(3), 'X', 'Color','k','FontSize',12);
    text(centroid(1), centroid(2)+axisLength, centroid(3), 'Y', 'Color','k','FontSize',12);
    text(centroid(1), centroid(2), centroid(3)+axisLength, 'Z', 'Color','k','FontSize',12);
    title('Principal-component axes (3D)'); legend('PC1','PC2','PC3','Location','best');
    axis equal tight; grid on; view(3);
    gca().Tag = '3DView';

    % 4-6: three projection planes
    [height, width, numSlices] = size(volumeData);

    subplot(2,3,4); hold on;
    imagesc([1,width]*resolution(1), [1,height]*resolution(2), maxProjXY);
    colormap(gray); alpha(0.3);
    plot([centroid(1),axisEndPC1(1)], [centroid(2),axisEndPC1(2)], 'r-', 'LineWidth', 2);
    plot([centroid(1),axisEndPC2(1)], [centroid(2),axisEndPC2(2)], 'g-', 'LineWidth', 2);
    plot([centroid(1),axisEndPC3(1)], [centroid(2),axisEndPC3(2)], 'b-', 'LineWidth', 2);
    quiver(centroid(1), centroid(2), axisLength, 0, 'k--');
    quiver(centroid(1), centroid(2), 0, axisLength, 'k--');
    title('XY plane'); xlabel('X'); ylabel('Y');
    axis equal tight; grid on; set(gca, 'YDir', 'normal');

    subplot(2,3,5); hold on;
    imagesc([1,width]*resolution(1), [1,numSlices]*resolution(3), maxProjXZ);
    colormap(gray); alpha(0.3);
    plot([centroid(1),axisEndPC1(1)], [centroid(3),axisEndPC1(3)], 'r-', 'LineWidth', 2);
    plot([centroid(1),axisEndPC2(1)], [centroid(3),axisEndPC2(3)], 'g-', 'LineWidth', 2);
    plot([centroid(1),axisEndPC3(1)], [centroid(3),axisEndPC3(3)], 'b-', 'LineWidth', 2);
    quiver(centroid(1), centroid(3), axisLength, 0, 'k--');
    quiver(centroid(1), centroid(3), 0, axisLength, 'k--');
    title('XZ plane'); xlabel('X'); ylabel('Z');
    axis equal tight; grid on; set(gca, 'YDir', 'normal');

    subplot(2,3,6); hold on;
    imagesc([1,height]*resolution(2), [1,numSlices]*resolution(3), maxProjYZ);
    colormap(gray); alpha(0.3);
    plot([centroid(2),axisEndPC1(2)], [centroid(3),axisEndPC1(3)], 'r-', 'LineWidth', 2);
    plot([centroid(2),axisEndPC2(2)], [centroid(3),axisEndPC2(3)], 'g-', 'LineWidth', 2);
    plot([centroid(2),axisEndPC3(2)], [centroid(3),axisEndPC3(3)], 'b-', 'LineWidth', 2);
    quiver(centroid(2), centroid(3), axisLength, 0, 'k--');
    quiver(centroid(2), centroid(3), 0, axisLength, 'k--');
    title('YZ plane'); xlabel('Y'); ylabel('Z');
    axis equal tight; grid on; set(gca, 'YDir', 'normal');

    % Rotation controls
    uicontrol('Style', 'pushbutton', 'String', 'Start rotation', 'Position', [20,20,100,30], ...
        'Callback', @(~,~)setappdata(mainFig,'rotActive',true));
    uicontrol('Style', 'pushbutton', 'String', 'Stop rotation', 'Position', [140,20,100,30], ...
        'Callback', @(~,~)setappdata(mainFig,'rotActive',false));
    setappdata(mainFig, 'rotActive', false);

    h3DViews = findobj(mainFig, 'Type', 'axes', 'Tag', '3DView');
    for i = 1:length(h3DViews)
        h = rotate3d(h3DViews(i));
        h.ActionPostCallback = @(src,~)sync_views(src, h3DViews);
        h.Enable = 'on';
    end

    % Print results
    fprintf('===== PCA results =====\n');
    fprintf('Centroid: [%.2f, %.2f, %.2f] μm\n', centroid);
    fprintf('PC1: [%.4f,%.4f,%.4f] explained variance:%.1f%%\n', PC1, 100*eigenValues(1)/sum(eigenValues));
    fprintf('PC2: [%.4f,%.4f,%.4f] explained variance:%.1f%%\n', PC2, 100*eigenValues(2)/sum(eigenValues));
    fprintf('PC3: [%.4f,%.4f,%.4f] explained variance:%.1f%%\n', PC3, 100*eigenValues(3)/sum(eigenValues));
    fprintf('X range:%.2f Y range:%.2f Z range:%.2f μm\n', range(coords(:,1)), range(coords(:,2)), range(coords(:,3)));
end

function sync_views(src, allViews)
    try
        [az, el] = view(src.Axes);
        for i = 1:length(allViews)
            if isvalid(allViews(i)) && allViews(i) ~= src.Axes
                view(allViews(i), az, el);
            end
        end
    catch
    end
end
