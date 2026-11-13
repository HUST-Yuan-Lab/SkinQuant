function open_figures(fig_paths)
    % Open .fig files (3D visualization figures)
    %   fig_paths: cell array of fig file paths, or a single string
    %   Example:
    %     open_figures('F:\hole_seg\...\19_2_3d_visualization.fig')
    %     open_figures({'path1.fig', 'path2.fig'})
    if ischar(fig_paths) || isstring(fig_paths)
        fig_paths = {fig_paths};
    end
    for i = 1:length(fig_paths)
        fprintf('Opening: %s\n', fig_paths{i});
        openfig(fig_paths{i}, 'visible');
    end
end
