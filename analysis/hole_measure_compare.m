function hole_measure_compare()
    % Comparison of hole quantification statistics: program-calculated vs. manual measurements
    ID = [1, 5, 16];
    metrics = {'Depth', 'Perimeter', 'Volume'};

    calc_values = [207, 870, 2178352;
                   248, 821, 1716843;
                   170, 954, 2458755];

    manual_values = [204, 836, 2325654;
                     255, 831, 1584016;
                     163, 988, 2802216];

    errors = [1.45, 3.91, 6.76;
              2.75, 1.20, 8.39;
              4.29, 3.44, 12.26];

    figure('Position', [100, 100, 1200, 600]);
    t = tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

    for m = 1:length(metrics)
        nexttile; hold on;
        bar_width = 0.4;
        x_pos = 1:length(ID);
        x1 = x_pos - bar_width/2; x2 = x_pos + bar_width/2;

        b1 = bar(x1, calc_values(:,m), bar_width, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
        b2 = bar(x2, manual_values(:,m), bar_width, 'FaceColor', [0.8 0.4 0.1], 'EdgeColor', 'k');

        for i = 1:length(ID)
            text(x2(i), manual_values(i,m), sprintf('%.2f%%', errors(i,m)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontSize', 12, 'Color', 'k', 'FontWeight', 'bold');
        end

        title(metrics{m});
        set(gca, 'XTick', x_pos, 'XTickLabel', ID);
        xlabel('Sample ID');
        if m == 3; ylabel('Volume (μm^3)'); ytickformat('%g');
        else; ylabel([metrics{m} ' (μm)']); end
        grid on; set(gca, 'FontSize', 12);
    end

    lgd = legend([b1, b2], {'Program-calculated', 'Manual measurement'}, 'Orientation', 'horizontal');
    lgd.Layout.Tile = 'north';
    title(t, 'Hole quantification comparison', 'FontSize', 14, 'FontWeight', 'bold');
end
