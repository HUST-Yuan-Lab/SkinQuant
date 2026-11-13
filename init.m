% SkinQuant initialization script - add utility function paths to the MATLAB search path
root_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(root_dir, 'utils'));
addpath(fullfile(root_dir, 'analysis'));
addpath(fullfile(root_dir, 'visualization'));
addpath(fullfile(root_dir, 'extraction'));
fprintf('SkinQuant paths initialized\n');
