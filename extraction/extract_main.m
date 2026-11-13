% Main entry point - TIFF square extraction (by Excel coordinates)
% Modify the parameters below and run
clear; clc;

%% Parameter settings
square_size = 1000;                          % Square side length (pixels)
folder1 = '';                                % Input TIFF folder path
folder2 = '';                                % Output folder path
excel_path = '';                             % Excel coordinate file path

%% Select the extraction mode
%   'simple'  - Extract squares directly (extract_squares)
%   'reslice' - Extract, reslice along xz, and rotate (extract_and_reslice)
mode = 'simple';

%% Run the extraction
if ~isempty(folder1) && ~isempty(folder2) && ~isempty(excel_path)
    switch mode
        case 'simple'
            extract_squares(folder1, folder2, excel_path, square_size);
        case 'reslice'
            extract_and_reslice(folder1, folder2, excel_path, square_size);
    end
else
    fprintf('Please set the folder1, folder2, and excel_path parameters first\n');
end
