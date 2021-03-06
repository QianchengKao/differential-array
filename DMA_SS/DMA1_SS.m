function [ y,Y12] = DMA1_SS( x,spacing)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DMAs for Sepctral-Subtraction
% refer to
% [1]."Sound Source Separation Using Null-Beamforming and Spectral Subtraction
%  for mobileDevice"
% [2]."differential microphone arrays"
%
% example Usage:
%   y = DMA1_SS( x,0.02)
%
% Inputs:
%   x        dual-mic input data,[samples,channel]
%   spacing  mic spacing     
%
% Outputs:
%   y            processed data
%
% Created by Wang wei
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fs = 16000;
N_FFT = 1024;
frameLength = 512;
inc = 256;
c = 340;
tao0 = spacing/c;
win = sqrt(hann(frameLength+1));
win = win(1:end-1);
X = stft(x,N_FFT,frameLength,inc,win);
% output spectral
Y = squeeze(X(:,1,:));
y = zeros(size(x,1),1);
L = size(x,1);
frameNum = fix((L - (frameLength-inc))/inc);

half_bin = N_FFT/2+1;

 
theta = linspace(0,2*pi,360);   % scaning angle

HL = zeros(1,half_bin);

H_1st_f = zeros(2,half_bin);
H_1st_b = zeros(2,half_bin);
H_1st_n = zeros(2,half_bin);
HL_f = zeros(1,half_bin);
HL_b = zeros(1,half_bin);
HL_n = zeros(1,half_bin);

Cf = zeros(2,half_bin);
Cb = zeros(2,half_bin);
Cn = zeros(2,half_bin);

B12 = zeros(length(theta),half_bin); % beamformer output
B21 = zeros(length(theta),half_bin); % beamformer output
N12 = zeros(length(theta),half_bin); % beamformer output
M12 = zeros(length(theta),half_bin); % beamformer output
Y12_2 = zeros(length(theta),half_bin); % beamformer output
Y12 = zeros(length(theta),half_bin); % beamformer output

eps = 1e-8;
% calculate fixed beamformer weights
for k = 2:half_bin
    omega_k = 2*pi*(k-1)*fs/N_FFT; % normalized digital angular frequency
    
    % forward
    theta_target = 0*pi/180;
    theta_null = 180*pi/180;
    HL_f(k) = 1/(1-exp(1j*omega_k*tao0*(cos(theta_null)-cos(theta_target))));        
    % HL_f(k) = 1j/(omega_k*tao0*(cos(theta_null)-cos(theta_target)));  % approximating e^x with 1+x
    H_1st_f(:,k) = [1;
                -exp(1j*omega_k*tao0*cos(theta_null))];                
    Cf(:,k) = H_1st_f(:,k);%.*HL_f(k);
    
    % backward
    theta_target = 180*pi/180;
    theta_null = 0*pi/180;
    HL_b(k) = 1/(1-exp(1j*omega_k*tao0*(cos(theta_null)-cos(theta_target))));
    % HL_b(k) = 1j/(omega_k*tao0*(cos(theta_null)-cos(theta_target)));  % approximating e^x with 1+x
    H_1st_b(:,k) = [1;
                -exp(1j*omega_k*tao0*cos(theta_null))];              
    Cb(:,k) = H_1st_b(:,k);%.*HL_b(k);

    % reference noise
    theta_target = 0*pi/180;
    theta_null = 90*pi/180;
    HL_n(k) = 1/(1-exp(1j*omega_k*tao0*(cos(theta_null)-cos(theta_target))));
    % HL_n(k) = 1j/(omega_k*tao0*(cos(theta_null)-cos(theta_target)));  % approximating e^x with 1+x
    H_1st_n(:,k) = [1;
                -exp(1j*omega_k*tao0*cos(theta_null))];
    Cn(:,k) = H_1st_n(:,k);%.*HL_n(k);

    % compensation filter for spectral-subtrctive output
    HL(k) = 1/(sqrt(2*(1-cos(omega_k*tao0)))+eps);
end 
 
% calculate beampattern
 for ang = 1:length(theta)
     for k = 2:half_bin
        omega_k = 2*pi*(k-1)*fs/N_FFT; % normalized digital angular frequency
        a = [1,exp(-1j*omega_k*tao0*cos(theta(ang)))];  % signal model,steering vector        
        B12(ang,k) = a*Cf(:,k);
        B21(ang,k) = a*Cb(:,k);
        N12(ang,k) = a*Cn(:,k);
        M12(ang,k) = min(abs(B12(ang,k)),abs(B21(ang,k)));
        Y12_2(ang,k) = max(abs(M12(ang,k))^2-abs(N12(ang,k))^2,0);
        Y12(ang,k) = sqrt(Y12_2(ang,k))*HL(k);
    end 
  
 end
% draw beampattern
if(nargout==2)
    k = 96;
    figure,polarplot(linspace(0,2*pi,360),abs(B12(:,k)));%rlim([-1 1])
    hold on,polarplot(linspace(0,2*pi,360),abs(B21(:,k)));
    hold on,polarplot(linspace(0,2*pi,360),abs(N12(:,k)));
    hold on,polarplot(linspace(0,2*pi,360),abs(M12(:,k)));
    hold on,polarplot(linspace(0,2*pi,360),abs(Y12(:,k)));
    legend('B12','B21','N12','M12','Y12'); 
end

B12 = zeros(frameNum,half_bin); % beamformer output
B21 = zeros(frameNum,half_bin); % beamformer output
N12 = zeros(frameNum,half_bin); % beamformer output
M12 = zeros(frameNum,half_bin); % beamformer output
Y12_2 = zeros(frameNum,half_bin); % beamformer output
Y12 = zeros(frameNum,half_bin); % beamformer output

for frameIndex = 1:frameNum
    d = squeeze(X(frameIndex,:,1:half_bin));
    
    for k = 2:half_bin
        a = d(:,k); % [1,exp(-1j*omega(k)*sin0)],input signal broadside
        
        % fixed beamformer
        B12(frameIndex,k) = a.'*Cf(:,k);
        B21(frameIndex,k) = a.'*Cb(:,k);
        N12(frameIndex,k) = a.'*Cn(:,k);
        % spectral-subtraction
        M12(frameIndex,k) = min(abs(B12(frameIndex,k)),abs(B21(frameIndex,k)));
        alpha_ss = 1.5;
        beta_ss = 0.001;
        if(abs(M12(frameIndex,k))^2>(alpha_ss+beta_ss)*abs(N12(frameIndex,k))^2)
            Y12_2(frameIndex,k) = abs(M12(frameIndex,k))^2 - alpha_ss*abs(N12(frameIndex,k))^2;
        else
            Y12_2(frameIndex,k) = beta_ss*abs(N12(frameIndex,k))^2;
        end
        phase = angle(B12(frameIndex,k));
        Y(frameIndex,k) = sqrt(Y12_2(frameIndex,k))*HL(k)*(cos(phase)+1j*(sin(phase)));
%         Y(frameIndex,k) = abs(N12(frameIndex,k));   
%         Y(frameIndex,k) = M12(frameIndex,k);
%         Y(frameIndex,k) = Y(frameIndex,k)*(cos(phase)+1j*(sin(phase)));   
    end
end
    y = istft(Y,N_FFT,frameLength,inc);
    y = real(y);
end


