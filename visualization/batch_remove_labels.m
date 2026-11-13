function batch_remove_labels(basePath, datasets, varargin)
    % Batch removal of figure titles and legends, then re-save
    %   basePath: root data directory
    %   datasets: cell array of dataset names
    %   Optional parameters:
    %     'InputSuffix', str - input folder suffix, default '_visualization2'
    %     'OutputSuffix', str - output folder suffix, default '_visualization3'
    p = inputParser;
    addParameter(p, 'InputSuffix', '_4d_select_sunshang_visualization2');
    addParameter(p, 'OutputSuffix', '_4d_select_sunshang_visualization3');
    parse(p, varargin{:});
    in_suffix = p.Results.InputSuffix;
    out_suffix = p.Results.OutputSuffix;

    for d = 1:length(datasets)
        dataset = datasets{d};
        fprintf('\n=== Processing dataset: %s ===\n', dataset);

        in_dir = fullfile(basePath, [dataset in_suffix]);
        out_dir = fullfile(basePath, [dataset out_suffix]);
        if ~exist(out_dir, 'dir'); mkdir(out_dir); end

        files = dir(fullfile(in_dir, '*.fig'));
        for fIdx = 1:length(files)
            [~, name, ext] = fileparts(files(fIdx).name);
            filename = [name ext];
            [~, fname_only] = fileparts(filename);
            fprintf('Processing: %s (%d/%d)\n', filename, fIdx, length(files));

            fig = openfig(fullfile(in_dir, filename), 'invisible');
            title('');
            legend off;
            saveas(fig, fullfile(out_dir, [fname_only '.fig']));
            saveas(fig, fullfile(out_dir, [fname_only '.png']));
            close(fig);
        end
    end
    fprintf('\nProcessing complete!\n');
end
