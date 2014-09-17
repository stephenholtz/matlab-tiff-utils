function [stack,stackLocs] = readTiffStackFolder(folder,fNums,castType)
%function [stack,stackLocs] = readTiffStackFolder(folder,[fNums=inf],[castType='double'])
%
% folder:   a folder with only tiff stacks in it
% fNums:    the numbers of the frames w/rt the entire appended set
%           defaults to all frames
% castType: class of data to import as
%           defaults to double
%
% folder needs to have frameInfo.mat file with these fields:
%   fileName
%   stackNum
%   frameNums
%   nTotalFrames
%   fileSource
%   movFrameNum
%
% SLH 2014

% Determine the frame numbers in each stack from frameInfo.mat
frameInfoFname = fullfile(folder,'frameInfo.mat');
load(frameInfoFname);

if ~exist('fNums','var') 
    % Default to all frames
    fNums = 1:frameInfo(1).nTotalFrames;
elseif numel(fNums) == 1 && (fNums == inf || fNums == 0)
    fNums = 1:frameInfo(1).nTotalFrames;
elseif numel(fNums) > 1 && (sum(diff(fNums) > 0) ~= numel(fNums) - 1)
    % Make sure the frame numbers given are increasing, otherwise finding frames breaks
    error('Requested frame numbers must be increasing')
end

% Find where each frame is in the stacks
iFrame = 1;
iStack = 1;
stackLocs = zeros(numel(fNums),2);
framesToFind = fNums;

while ~isempty(framesToFind)
    if framesToFind(1) > frameInfo(iStack).frameNums(end)
        % increment stack when needed
        iStack = iStack + 1;
    else
        % store the location in the stack and stack for each frame
        stackLocs(iFrame,:) = [iStack (1 + framesToFind(1) - frameInfo(iStack).frameNums(1))];
        framesToFind = framesToFind(2:end);
        iFrame = iFrame + 1;
    end
end

% use tiffRead to get all of the images in memory
stackImInfo = imfinfo(fullfile(folder,frameInfo(1).fileName));
stack = zeros(stackImInfo(1).Height,stackImInfo(1).Width,numel(fNums));

% Only one call to tiffRead per stack requested, more efficient
framesRead = 0;
for iStack = unique(stackLocs(:,1))';
    framesInStack = stackLocs(stackLocs(:,1)==iStack,2);
    stackFileName = fullfile(folder,frameInfo(iStack).fileName);
    stack(:,:,framesRead+1:framesRead+numel(framesInStack)) = tiffRead(stackFileName,framesInStack,castType);
    framesRead = framesRead + numel(framesInStack);
end
