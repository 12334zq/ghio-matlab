% [R, Sup, M] = gshrinkwrap(Fabs, n, checker, gen, n2, rep, varargin) 
% varargin = {alpha, sigma, cutoff1, cutoff2}
% GUIDED shrink-wrap 2-D HIO written by Po-Nan Li @ Academia Sinica 2014
% reference: 
% [1] Marchesini et al., 
%    ��X-ray image reconstruction from a diffraction pattern alone,��
%     Phys. Rev. B 68, 140101 (2003).
% [2] Chen et al.,
%     
% v.1 2014/06/03 : multiple seed
% v.2 2014/06/06 : multiple following runs

function [R, Sup, M] = gshrinkwrap(Fabs, n, checker, gen, n2, rep, varargin) 


% default parameters;
alpha = [];
sig = 3;
cutoff1 = 0.04;
cutoff2 = 0.2;


% handle additional aruguments
if ~isempty(varargin)
    alpha = varargin{1};
    if length(varargin) > 1
        sig = varargin{2};
        if length(varargin) > 2
            cutoff1 = varargin{3};
            if length(varargin) > 3
                cutoff2 = varargin{4};
            end
        end
    end
end

S = fftshift( ifft2(abs(Fabs).^2, 'symmetric') );
S = S > cutoff1*max(S(:));

% pre-allocated spaces
R   = zeros( size(Fabs, 1), size(Fabs, 2), gen+1);
Sup = false( size(Fabs, 1), size(Fabs, 2), gen+1);
Sup(:,:,1) = S;

% pre-allocated spaces for parallel
Rtmp = zeros( size(Fabs, 1), size(Fabs, 2), rep);
Ftmp = zeros( size(Fabs, 1), size(Fabs, 2), rep);
Mtmp = zeros( size(Fabs, 1), size(Fabs, 2), rep);
Stmp = false( size(Fabs, 1), size(Fabs, 2), rep);
efs = zeros(1, rep);


% first run with initial support from auto-correlation map
parfor r = 1:rep
    Rtmp(:,:,r) = hio2d(Fabs, S, n, checker, alpha);
    Ftmp(:,:,r) = fft2( Rtmp(:,:,r) );
    efs(r) = ef(Fabs, Ftmp(:,:,r), Fabs == 0), 
end
[my, mx] = min(efs);
disp('seed:');
disp(['replica #' int2str(mx) ' with EF = ' num2str(my) ' selected']);
R(:,:,1) = Rtmp(:,:,mx);

% make Gaussian kernel
% fwhm = 8;
% sig = fwhm / 2.355;
x = (1:size(S,2)) - size(S,2)/2;
y = (1:size(S,1)) - size(S,1)/2;
[X, Y] = meshgrid(x, y);
rad = sqrt(X.^2 + Y.^2);


% shrink-wrap
for g = 1:gen
    parfor r = 1:rep
        G = exp(-(rad./sqrt(2)./sig).^2);
        Mtmp(:,:,r) = fftshift( ifft2( fft2(Rtmp(:,:,r)) .* fft2(G), 'symmetric') );
        Stmp(:,:,r) = ( Mtmp(:,:,r) >= cutoff2*max(max(Mtmp(:,:,r))) );
        Rtmp(:,:,r) = hio2d(fft2(Rtmp(:,:,r)), Stmp(:,:,r), n2, checker, alpha);
        % Fourier transform for EF
        Ftmp(:,:,r) = fft2( Rtmp(:,:,r) );
        efs(r) = ef(Fabs, Ftmp(:,:,r), Fabs == 0), 
    end
    % EF analysis
    [my, mx] = min(efs);
    disp(['after generation ' int2str(g) ':']);
    disp(['replica #' int2str(mx) ' with EF = ' num2str(my) ' selected']);
    R(:,:,g+1) = Rtmp(:,:,mx);
    Sup(:,:,g+1) = Stmp(:,:,mx);
    
    if sig > 1.5
        sig = sig * 0.99;
    end
end

M = Mtmp(:,:,1);