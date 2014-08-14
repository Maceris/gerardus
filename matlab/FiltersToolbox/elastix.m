function [t, movingReg, iterInfo] = elastix(regParam, fixed, moving, param)
% elastix  Matlab interface to the image registration program "elastix".
%
% elastix is a simple interface to the command line program "elastix"
%
%   http://elastix.isi.uu.nl/
%
% Command-line "elastix" is a powerful rigid and nonrigid registration
% program, but it requires that input images are provided as files, and
% returns the results (transform parameters, registered image, etc) as
% files in a directory. This is not so convenient when using Matlab, so
% this interface function allows to pass images either as filenames or as
% image arrays, and transparently takes care of creating temporary files
% and directories, reading the result to Matlab variables, and cleaning up
% afterwards.
%
% Note: Currently this function as been tested only with a single-level
% registration.
%
% [T, MOVINGREG, ITERINFO] = elastix(REGPARAM, FIXED, MOVING, PARAM)
%
%   REGPARARM is a string with the path and name of a text file with the
%   registration parameters for elastix, e.g.
%   '/path/to/ParametersTranslation2D.txt'.
%
%   FIXED, MOVING are the images to register. They can be given as file
%   names or as image arrays, e.g. 'im1.png' or im = checkerboard(10).
%
%   PARAM is an optional struct with fields
%
%     verbose: (def 0) If 0, it hides all the elastix command output to the
%              screen.
%
%     outfile: (def '') Path and name of output image file to save
%              registered image to. This option is ignored when MOVING is
%              an image array.
%
%   T is a struct with the contents of the parameter transform file
%   (OUTDIR/TransformParameters.0.txt), e.g.
%
%                             Transform: 'TranslationTransform'
%                    NumberOfParameters: 2
%                   TransformParameters: [-2.4571 0.3162]
%    InitialTransformParametersFileName: 'NoInitialTransform'
%                HowToCombineTransforms: 'Compose'
%                   FixedImageDimension: 2
%                  MovingImageDimension: 2
%           FixedInternalImagePixelType: 'float'
%          MovingInternalImagePixelType: 'float'
%                                  Size: [2592 1944]
%                                 Index: [0 0]
%                               Spacing: [1 1]
%                                Origin: [0 0]
%                             Direction: [1 0 0 1]
%                   UseDirectionCosines: 'true'
%                  ResampleInterpolator: 'FinalBSplineInterpolator'
%        FinalBSplineInterpolationOrder: 3
%                             Resampler: 'DefaultResampler'
%                     DefaultPixelValue: 0
%                     ResultImageFormat: 'png'
%                  ResultImagePixelType: 'unsigned char'
%                   CompressResultImage: 'false'
%
%   MOVINGREG is the result of registering MOVING onto FIXED. MOVINGREG is
%   the same type as MOVING (i.e. image array or path and filename). In the
%   path and filename case, an image file will we created with path and
%   name MOVINGREG=PARAM.outfile. If PARAM.outfile is not provided or
%   empty, then the registered image is deleted and MOVINGREG=''.
%
%   ITERINFO is a struct with the details of the elastix optimization
%   (OUTDIR/IterationInfo.0.R0.txt), e.g.
%
%        ItNr: [10x1 double]
%      Metric: [10x1 double]
%    stepSize: [10x1 double]
%    Gradient: [10x1 double]
%        Time: [10x1 double]
%
% See also: elastix_read_reg_output, , blockface_find_frame_shifts.

% Author: Ramon Casero <rcasero@gmail.com>
% Copyright © 2014 University of Oxford
% Version: 0.1.0
% $Rev$
% $Date$
% 
% University of Oxford means the Chancellor, Masters and Scholars of
% the University of Oxford, having an administrative office at
% Wellington Square, Oxford OX1 2JD, UK. 
%
% This file is part of Gerardus.
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details. The offer of this
% program under the terms of the License is subject to the License
% being interpreted in accordance with English Law and subject to any
% action against the University of Oxford being under the jurisdiction
% of the English Courts.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

% check arguments
narginchk(3, 4);
nargoutchk(0, 3);

if (isempty(regParam) || ~ischar(regParam) || isempty(dir(regParam)))
    error('PARAM must be a valid .txt file with the registration parameters for elastix')
end

% defaults
if (nargin < 4 || isempty(param))
    % capture the elastix output so that it's not output on the screen
    param.verbose = 0;
end

% if images are given as arrays instead of filenames, we need to create 
% temporary files with the images so that elastix can work with them
[fixedfile, delete_fixedfile] = create_temp_file_if_array_image(fixed);
[movingfile, delete_movingfile] = create_temp_file_if_array_image(moving);

if (ischar(moving))
    
    % if moving image is given as a filename, then we'll save the
    % registered image to the path provided by the user. If the user has
    % not provided an output name, then the result image will not be
    % returned. This is useful when we only need the transformation
    if (~isfield(param, 'outfile'))
        param.outfile = '';
    end
    
else
    
    % if moving image was provided as an image, the output will be an
    % image array in memory, and we can ignore the output directory, as it
    % will not be saved to a file
    param.outfile = '';
    
end

% create temp directory for output
tempoutdir = tempname;
success = mkdir(tempoutdir);
if (~success)
    error(['Cannot create temp directory for registration output: ' tempoutdir])
end

% register images
if (param.verbose)
    status = system([...
        'elastix ' ...
        ' -f ' fixedfile ...
        ' -m ' movingfile ...
        ' -out ' tempoutdir ...
        ' -p ' regParam
        ]);
else
    % hide command output from elastix
    [status, ~] = system([...
        'elastix ' ...
        ' -f ' fixedfile ...
        ' -m ' movingfile ...
        ' -out ' tempoutdir ...
        ' -p ' regParam
        ]);
end
if (status)
    error('Registration failed')
end

if (ischar(moving))
    
    % output registered image can have a different extension from the
    % moving image, so we have to check what's the actuall full name of the
    % output file
    regfile = dir([tempoutdir filesep 'result.0.*']);
    if (isempty(regfile))
        error('Elastix did not produce an output registration')
    end
    
    % read elastix result
    [t, ~, iterInfo] = elastix_read_reg_output(tempoutdir);
    
    % check that the output file extension matches the extension of the
    % output filename, and give a warning if they don't match
    if (~isempty(param.outfile))
        
        [~, ~, regfile_ext] = fileparts(regfile.name);
        [~, ~, outfile_ext] = fileparts(param.outfile);
        if (~strcmpi(regfile_ext, outfile_ext))
            warning('Gerardus:BadFileExtension', ...
                [ 'Elastix produced a ' regfile_ext ...
                ' image, but user asked to save to format ' outfile_ext])
        end
        
        % the first output argument will be the path to the output file,
        % rather than the image itself
        movingReg = param.outfile;
        
        % move the result image to the directory requested by the user
        movefile([tempoutdir filesep regfile.name], movingReg);
        
    else
        
        % the first output argument will be the path to the output file, rather
        % than the image itself
        movingReg = '';
        
    end
    
    
else
    
    % read elastix result
    [t, movingReg, iterInfo] = elastix_read_reg_output(tempoutdir);
    
end

% delete temp files and directories
if (delete_fixedfile)
    delete(fixedfile)
end
if (delete_movingfile)
    delete(movingfile)
end
rmdir(tempoutdir, 's')

end

% create_temp_file_if_array_image
%
% check whether an input image is provided as an array or as a path to a
% file. If the former, then save the image to a temp file so that it can be
% processed by elastix
function [filename, delete_tempfile] = create_temp_file_if_array_image(file)

if (ischar(file))

    % input is a filename already, thus we don't need to create a temp file
    delete_tempfile = false;
    filename = file;
    
else
    
    % create a temp file for the image
    delete_tempfile = true;
    [pathstr, name] = fileparts(tempname);
    filename = [pathstr filesep name '.png'];
    imwrite(file, filename);
    
end

end
