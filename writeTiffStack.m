function writeTiffStack(img, filename, options)
arguments
    img      (:,:,1,:)   uint16
    filename (1,:)       char = 'img.tif'
    options.compression = 'deflate'
end
imwrite(img(:, :, 1, 1), filename, 'compression', options.compression); 
n_frames = size(img,4);
for i=2:n_frames
    imwrite(img(:, :, 1, i),  filename, 'writemode', 'append', 'compression', options.compression); 
end
