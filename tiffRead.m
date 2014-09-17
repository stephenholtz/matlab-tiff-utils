function varargout = tiffRead(fPath,frames,castType)
% img = tiffLoad(fPath, [castType]); [img, scanimage] = tiffLoad(fPath);
% 
% Load (big)tiffs with optional scanimage support, using the matlab
% libTiff gateway. 
%
% Only monochrome images supported.
%
% fPath - full path to tiff/tif file 
% castType - data type for the tiff to be read in as
% 
% Modified with permission from the HarveyLab git repo:
%   https://github.com/HarveyLab
%
% SLH 2014

if ~exist('castType', 'var')
    castType = 'double';
end

% Gracefully handle missing extension:
if exist(fPath, 'file') ~= 2
    if exist([fPath, '.tif'], 'file')
        fPath = [fPath, '.tif'];
    elseif exist([fPath, '.tiff'], 'file')
        fPath = [fPath, '.tiff'];
    else
        error(['Could not find ' fPath '.'])
    end
end

% Create Tiff object:
t = Tiff(fPath);

% Get number of directories (= frames):
if exist('frames','var')
    nDirectories = numel(frames);
    % make sure frames is iterable
    frames = squeeze(frames)';
else
    t.setDirectory(1);
    while ~t.lastDirectory
        t.nextDirectory;
    end
    nDirectories = t.currentDirectory;
    frames = 1:nDirectories;
end

% Load all directories (= frames):
img = zeros(t.getTag('ImageLength'),...
    t.getTag('ImageWidth'), ...
    nDirectories, ...
    castType);

% Read in images, formatted progress
nDisp = ceil(nDirectories/100);
nPrt = ceil(log10(nDirectories));
prtStr = ['%' num2str(nPrt+1) '.d / %' num2str(nPrt+1) '.d frames loaded.'];
fprintf(prtStr,0,nDirectories)
i = 1;
for f = frames
    t.setDirectory(f);
    img(:,:,i) = t.read;
    if ~mod(i, nDisp)
        fprintf([repmat('\b',1,length(prtStr)) prtStr], i, nDirectories);
    end
    i = i + 1;
end
fprintf('\n')

varargout{1} = img;

% Scanimage metadata: Tiffs saved by Scanimage contain useful metadata in
% form of a struct. This data can be requested as a second output argument.
%
%%% NOTE: not updated to work with pulling in subsets of directories!!
if nargout > 1
    imgDesc = t.getTag('ImageDescription');
    imgDescC = regexp(imgDesc, 'scanimage\..+? = .+?(?=\n)', 'match');
    imgDescC = strrep(imgDescC, '<nonscalar struct/object>', 'NaN');
    %If it's a scanImage4 file
    if ~isempty(imgDescC) 
        for e = imgDescC;
            eval([e{:} ';']);
        end
        varargout{2} = scanimage;
    else %If it's a scanImage3 file
        lineDesc = regexp(imgDesc,'state.','start');
        lineDesc(end+1) = length(imgDesc)+1;
        for e = 1:length(lineDesc)-1
            eval([imgDesc(lineDesc(e):lineDesc(e+1)-2) ';']);
        end
        varargout{2} = state;
    end
end

% Close:
t.close();
