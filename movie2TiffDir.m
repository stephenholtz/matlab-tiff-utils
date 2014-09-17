function movie2TiffDir(inFiles,inDir,tiffName,tiffDir,imgsPerStack,compression,useBigTiff)
%function movie2TiffDir(inFiles,inDir,tiffName,tiffDir,[imgsPerStack=1000],[compression='PackBits'],[useBigTiff=false])
%  
%   inFiles - cell array of filenames for all movie files
%   inDir - directory where movie file(s) are located
%   tiffName - base name that will be prepended
%   tiffDir - dir that tiff stacks will be written to
%   compression - use  'PackBits' (preferred lossless), 'JPEG' or 'LZW'
%
%   Does not have much input error checking, careful!
%  
% SLH 2014
%#ok<*NBRAK,*UNRCH,*AGROW>
verbose = 1;
if verbose
    fprintf('\nConverting movie files to tiff stacks!\n');
end

%% Create AVI objects
if verbose
    fprintf('Creating VideoReader objects\n');
end
if ~exist('imgsPerStack','var')
    imgsPerStack = 1000;
end
if ~exist('compression','var')
    compression = 'Deflate';
end
if ~exist('useBigTiff','var')
    useBigTiff = false;
end
if ~iscell(inFiles) && ischar(inFiles)
    inFiles = {inFiles};
elseif ~iscell(inFiles)
    error('Expects cell array or characters for inFiles');
end

for i = 1:numel(inFiles)
    vObj(i) = VideoReader(fullfile(inDir,inFiles{i}));
    [~] = read(vObj(i),inf);
    nFrames(i) = vObj(i).NumberOfFrames;
end

% Assume all movies are the same dims
nRows = vObj(1).Height;
nCols = vObj(1).Width;

% Limited videoformat options for our data:
% flag take3rdDim is a more efficient version of rgb2gray
switch vObj(1).VideoFormat
    case {'RGB24'}
        % This is UINT8x3 off the pointgrey camera
        BitsPerPixel= 8;
        take3rdDim = 1;
    case {'Mono16','Mono14','Mono12'}
        % probably a motion jpeg 2000 file
        BitsPerPixel = 16;
        take3rdDim = 0;
    case {'Grayscale'}
        % AKA default grayscale AVI from the epi camera
        BitsPerPixel = vObj(1).BitsPerPixel;
        take3rdDim = 0;
    otherwise
        error('VideoFormat not accounted for')
end

% Write stacks from the movies to a folder, with a frameInfo.mat file for lookup
nPerStack   = imgsPerStack;
totalFrames = sum(nFrames);
framesLeft  = 1:totalFrames;

%% Make a struct with information on each stack and the frames within
iStack = 1;

if verbose
    fprintf('Creating frameInfo.mat struct\n')
end

while ~isempty(framesLeft)

    % Update the current frames
    if numel(framesLeft) < nPerStack
        currFrames = framesLeft;
    else
        currFrames = framesLeft(1:nPerStack);
    end

    % Set up the name of the stack
    prepend = num2str(iStack);
    while numel(prepend) < 4
        prepend =['0' prepend];
    end

    firstFrame = num2str(currFrames(1));
    while numel(firstFrame) < 6 
        firstFrame =['0' firstFrame];
    end

    lastFrame = num2str(currFrames(end));
    while numel(lastFrame) < 6
        lastFrame =['0' lastFrame];
    end

    frameInfo(iStack).fileName = [prepend '_s' firstFrame '_e' lastFrame '_' tiffName];
    frameInfo(iStack).stackNum = iStack;
    frameInfo(iStack).frameNums = currFrames;
    frameInfo(iStack).nTotalFrames = totalFrames;

    % Store the names of the movies that the frames came from
    movieUsed = zeros(numel(currFrames),1);
    iter = 1;
    for iFrame = currFrames
        movieUsed(iter) = find(cumsum(nFrames) >= iFrame, 1, 'first');
        iter = iter + 1;
    end 
    frameInfo(iStack).fileSource = inFiles(unique(movieUsed));

    % Store the inds of the movies that the frames came from (clunky)
    for i = 1:numel(frameInfo(iStack).fileSource)
        frameIter = 1;
        for iFrame = currFrames 
            movieUsed(iter) = find(cumsum(nFrames) >= iFrame, 1, 'first');
            movFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));
            frameInfo(iStack).movFrameNum{i}(frameIter) = movFrame;
            frameIter = frameIter + 1;
        end
    end

    % Update frames left
    if numel(framesLeft) >= nPerStack
        framesLeft = framesLeft(nPerStack+1:end);
    else
        framesLeft = [];
    end
    iStack = iStack + 1;
end 

if ~exist(tiffDir,'dir')
    mkdir(tiffDir)
end

% Save the frameInfo.mat file for later use (reduntant with filenames)
save(fullfile(tiffDir,'frameInfo.mat'),'frameInfo','-v7.3')
if verbose
    fprintf('Saved: %s\n',fullfile(tiffDir,'frameInfo.mat'))
end

% Anon func for grabbing that is faster than RGB conversion
takeOne3rdDim = @(x)(squeeze(x(:,:,1,:)));

% Loop over all of the stacks in one process
stacksToWrite = 1:numel(frameInfo);
for iStack = stacksToWrite

    frameIter = 1;

    % Which frames will be used in the stack
    framesInStack = frameInfo(iStack).frameNums;
    switch BitsPerPixel
        case 8
            rawFrames = uint8(zeros(nRows,nCols,numel(frameInfo(iStack).frameNums)));
        case 16
            rawFrames = uint16(zeros(nRows,nCols,numel(frameInfo(iStack).frameNums)));
        case 32
            rawFrames = uint32(zeros(nRows,nCols,numel(frameInfo(iStack).frameNums)));
    end
    
    % Print output
    if verbose; 
        fprintf('\nMovie loading for stack %d / %d',iStack,numel(stacksToWrite));
        fprintf('\n\tMovie frame %8.d / %8.d',frameIter,numel(framesInStack));
    end

    for iFrame = framesInStack
        if verbose && ~mod(frameIter,ceil(nPerStack/10));
            fprintf([repmat('\b',1,31) 'Movie frame %8.d / %8.d'],frameIter,numel(framesInStack));
        end

        % Look up which movie object should be used
        iMov = find(cumsum(nFrames) >= iFrame, 1, 'first');
        movFrame = iFrame - sum(nFrames(cumsum(nFrames) < iFrame));

        if take3rdDim
            rawFrames(:,:,frameIter) = takeOne3rdDim(read(vObj(iMov),movFrame));        
        else
            rawFrames(:,:,frameIter) = (read(vObj(iMov),movFrame));        
        end
        frameIter = frameIter + 1;
    end

    if verbose
        fprintf('\nTiff writing for stack %d of %d\n',iStack,numel(stacksToWrite));
    end

    % Use modified Harvey Lab writer (cleaner than mine)
    option.BitsPerSample = BitsPerPixel;
    option.Append = false;
    option.Compression = compression;
    option.BigTiff = useBigTiff;

    tiffWrite(rawFrames,frameInfo(iStack).fileName,tiffDir,option)
end
