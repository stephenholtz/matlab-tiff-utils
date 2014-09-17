function tiffWrite(img, fileName, filePath, option)
% tiffWrite(img, [fileName], [filePath], [bitDepth/append/compression])

if ~isa(img, 'numeric')
    error('First argument must be numeric (image to save).');
end

if ~exist('fileName', 'var') || isempty(fileName)
    fileName = inputname(1);
end

if ~exist('filePath', 'var') || isempty(filePath)
    filePath = cd;
end

if ~exist('option', 'var')
    % uint16 default type
    option.BitsPerSample = 32;
    option.Float = false;
    % 'Deflate' as default Compression
    option.Compression = 32946;
    option.Append = false;
    option.BigTiff= false;
end
if ~isfield(option,'Append')
    option.Append = false;
end
if ~isfield(option,'Compression')
    option.Compression = 'None';
end
if ~isfield(option,'BitsPerSample')
    option.BitsPerSample = 16;
end
if ~isfield(option,'BigTiff')
    option.BigTiff = false;
end
if ~isfield(option,'Float')
    option.Float = false;
end
% Add extension:
if isempty(regexp(fileName, '\.tiff?$', 'ignorecase'))
    fileName = [fileName, '.tif'];
end

% Create folder if necessary:
if exist(filePath, 'dir') ~= 7
   mkdir(filePath);
end

% Create Tiff object:
if option.Append
    if ~exist(fullfile(filePath, fileName), 'file')
        error('File to be appended on does not exist.')
    end
    
    t = Tiff(fullfile(filePath, fileName), 'r+');
    option = t.getTag('BitsPerSample');
    
    % Check for consistency:
    if ~strcmp(t.getTag('Software'), ['MATLAB:' mfilename])
        warning('The file to which data is to be appended was not written by this MATLAB function. Unexpected outcomes might result.');
    end
    
    if t.getTag('ImageLength') ~= size(img, 1)
        error('Image to be appended does not match length of tiff image.');
    end
    if t.getTag('ImageWidth') ~= size(img, 2)
        error('Image to be appended does not match length of tiff image.');
    end
    
    % Write directory for first appended frame:
    t.writeDirectory();
    
else
    switch option.BigTiff
        case true
            t = Tiff(fullfile(filePath, fileName), 'w8'); 
        case false
            t = Tiff(fullfile(filePath, fileName), 'w'); 
    end
end 

% Convert input image to desired bitDepth:
switch option.BitsPerSample
    case 8
        format = Tiff.SampleFormat.Int;
        img = uint8(img);
        bitsPerSample = 8;
    case {16,14,12}
        format = Tiff.SampleFormat.Int;
        img = uint16(img);
        bitsPerSample = 16;
    case 32
        bitsPerSample = 32;
        if option.Float
            format = Tiff.SampleFormat.IEEEFP;
            img = single(img);
        else
            format = Tiff.SampleFormat.Int;
            img = single(img);
        end
    case 64 
        bitsPerSample = 64;
        if option.Float
            format = Tiff.SampleFormat.IEEEFP;
            img = double(img);
        else
            format = Tiff.SampleFormat.Int;
            img = double(img);
        end
    otherwise
        error('Unsupported bit depth.');
end

% Use compression
switch lower(option.Compression)
    case {'deflate'}
        option.Compression = Tiff.Compression.Deflate;
    case {'packbits'}
        option.Compression = Tiff.Compression.PackBits;
    case {'lzw'} 
       option.Compression = Tiff.Compression.LZW; 
    case {'jpeg'} 
       option.Compression = Tiff.Compression.JPEG; 
    case {'none'} 
       option.Compression = Tiff.Compression.None;
    otherwise
        error('Unsupported compression.');
end


% Get size
[h, w, z] = size(img);

% Set tiff tags:
tagStruct.ImageLength = h;
tagStruct.ImageWidth = w;
tagStruct.Photometric = Tiff.Photometric.MinIsBlack;
tagStruct.SampleFormat = format;
tagStruct.BitsPerSample = bitsPerSample;
tagStruct.SamplesPerPixel = 1;
tagStruct.Compression = option.Compression;
tagStruct.Software = ['MATLAB:' mfilename];
tagStruct.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
t.setTag(tagStruct);

% Write all frames:
t.write(img(:,:,1)); % First frame;

fprintf('\tframes written: ')
for i = 2:z
    t.writeDirectory();
    t.setTag(tagStruct);
    t.write(img(:,:,i));
    if ~mod(i, 200)
        fprintf('%1.0f ', i);
    end
end
fprintf('\n')

t.close();
