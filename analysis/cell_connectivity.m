function cell_connectivity(result_dir, output_dir)
    % Connected-component analysis and statistics of 3D cell segmentation results
    %   result_dir: root directory containing the *_result subfolders
    %   output_dir: output directory (default result_dir/cell_analysis_results)
    if nargin < 2
        output_dir = fullfile(result_dir, 'cell_analysis_results');
    end
    if ~exist(output_dir, 'dir'); mkdir(output_dir); end

    stats_table = table('Size', [0, 5], ...
        'VariableTypes', {'string','double','double','double','double'}, ...
        'VariableNames', {'Sample','CellCount','AvgVolume','MinVolume','MaxVolume'});

    result_folders = dir(fullfile(result_dir, '*_result'));
    result_folders = result_folders([result_folders.isdir]);

    for i = 1:length(result_folders)
        folder_name = result_folders(i).name;
        sample_name = strrep(folder_name, '_result', '');
        fprintf('Processing sample: %s\n', sample_name);

        tif_files = dir(fullfile(result_dir, folder_name, '*.tif*'));
        for j = 1:length(tif_files)
            file_name = tif_files(j).name;
            file_path = fullfile(result_dir, folder_name, file_name);
            fprintf('  Loading: %s\n', file_name);

            seg_result = tiffreadVolume(file_path);
            bw = seg_result == 255;
            cc = bwconncomp(bw, 26);
            stats = regionprops3(cc, 'Volume', 'Centroid', 'BoundingBox');

            min_vol = 4;
            valid_idx = [stats.Volume] >= min_vol;
            stats = stats(valid_idx, :);

            cell_count = size(stats, 1);
            avg_vol = mean(stats.Volume);
            min_vol_val = min(stats.Volume);
            max_vol_val = max(stats.Volume);

            stats_table = [stats_table; {[sample_name '_' strrep(file_name,'.tif','')], ...
                cell_count, avg_vol, min_vol_val, max_vol_val}];

            visualize_cells(bw, stats, sample_name, file_name, output_dir);
        end
    end

    writetable(stats_table, fullfile(output_dir, 'cell_statistics.csv'));
    fprintf('Analysis complete, results: %s\n', output_dir);
end

function visualize_cells(bw, stats, sample_name, file_name, output_dir)
    sample_dir = fullfile(output_dir, sample_name);
    if ~exist(sample_dir, 'dir'); mkdir(sample_dir); end

    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 500]);

    subplot(1,2,1);
    MIP = max(bw, [], 3);
    imshow(MIP, []);
    title(['MIP - ' sample_name ' - ' file_name]);

    subplot(1,2,2);
    if ~isempty(stats)
        labeled = zeros(size(bw));
        for k = 1:size(stats,1)
            c = round(stats.Centroid(k,:));
            labeled(c(2), c(1), c(3)) = k;
        end
        p = patch(isosurface(bw, 0.5));
        isonormals(bw, p);
        p.FaceColor = 'red'; p.EdgeColor = 'none';
        daspect([1 1 1]); view(3); axis tight;
        camlight; lighting gouraud;
        title(['3D - ' num2str(size(stats,1)) ' cells']);
        hold on;
        for k = 1:size(stats,1)
            c = stats.Centroid(k,:);
            text(c(1), c(2), c(3), num2str(k), 'Color','white','FontSize',8,'FontWeight','bold');
        end
    end

    out_name = strrep(file_name, '.tif', '');
    saveas(fig, fullfile(sample_dir, [out_name '_visualization.png']));
    close(fig);

    if ~isempty(stats)
        cell_tbl = table((1:size(stats,1))', stats.Volume, stats.Centroid, ...
            'VariableNames', {'CellID','Volume','Centroid'});
        writetable(cell_tbl, fullfile(sample_dir, [out_name '_cell_details.csv']));
    end
end
