clear;clc;close all;
load("\\223.194.32.78\Digital_Lab\Personals\Subin_Moon\Radar\0_MovingData\TwoMenRun\twomen_CUBE.mat");
load("\\223.194.32.78\Digital_Lab\Personals\Subin_Moon\Radar\0_MovingData\TwoMenRun\twomen_RAW.mat");

objectNum = 2;

%parameters
chirpsIdx=1;
chanIdx=1;
frame_number=90;

numrangeBins=256;
NChirp=128;
NChan=4;
NSample=256;
Nframe = 256;                        % 프레임 수
pri=76.51e-6;                        %ramp end tiem + idle time
prf=1/pri;
start_frequency = 77e9;              % 시작 주파수 (Hz)
slope = 32.7337;                     % 슬로프 (MHz/s)
samples_per_chirp = 256;             % 하나의 칩에서의 샘플 수
chirps_per_frame = 128;              % 프레임 당 chirps 수
sampling_rate = 5e9;                 % 샘플링 속도 (Hz)
% 대역폭 = sampling time*frequency slope (sampling time = samples / sample rate)
bandwidth = 1.6760e9;                % 대역폭 (Hz)
%거리 해상도 = c/(2*bandwidth)
range_resolution = 0.0894;           % 거리 해상도 (m)
%속도 해상도 = wavelength/(2*pri*Nchirp)
velocity_resolution = 0.1991;        % 속도 해상도 (m/s)
sampling_time = NSample/sampling_rate; % 샘플링 타임 (s)
c = 3e8;                             % 빛의 속도 (미터/초)
wavelength = c / start_frequency;    % 파장(lambda)
max_vel = wavelength/(4*pri);        % 최대 속도
max_range = sampling_rate*c/(2*slope); %최대 거리

% 전체 걸린 시간 frame periodicity : 40ms -> 40ms*256 = 10.24s

%% Time domain output

% adcRawData -> adc_raw_data1
adc_raw_data1 = adcRawData.data{frame_number};

% adc_raw_data1->uint type 이기때문에 double type으로 바꿔줘야 연산 가능
adc_raw_data = cast(adc_raw_data1,"double");

% unsigned => signed
signed_adc_raw_data = adc_raw_data - 65536 * (adc_raw_data > 32767);

%IIQQ data 
re_adc_raw_data4=reshape(signed_adc_raw_data,[4,length(signed_adc_raw_data)/4]);
rawDataI = reshape(re_adc_raw_data4(1:2,:), [], 1);
rawDataQ = reshape(re_adc_raw_data4(3:4,:), [], 1);

frameData = [rawDataI, rawDataQ];
frameCplx = frameData(:,1) + 1i*frameData(:,2);
frameComplex = single(zeros(NChirp, NChan, NSample));

% IIQQ->IQ smaple->channel->chirp
temp = reshape(frameCplx, [NSample * NChan, NChirp]).';
for chirp=1:NChirp                            
    frameComplex(chirp,:,:) = reshape(temp(chirp,:), [NSample, NChan]).';
end 
rawFrameData = frameComplex;

currChDataQ = real(rawFrameData(chirpsIdx,chanIdx,:));
currChDataI = imag(rawFrameData(chirpsIdx,chanIdx,:));

% t=linspace(0,NSample-1,NSample);
t=linspace(0,sampling_time,NSample);

figure('Position', [300,100, 1200, 800]);
tiledlayout(2,2);

%% FFT Range Profile
% Range FFT
% pre allocation
radarCubeData_demo = zeros(128,4,256);
for chirpIdx = 1:128
    for chIdx = 1:4
        win = rectwin(256);
        frameData1(1,:) = frameComplex(chirpIdx, chIdx, :);
        frameData2 = fft(frameData1 .* win', 256);
        radarCubeData_demo(chirpIdx, chIdx, :) = frameData2(1,:);
    end
end
rangeProfileData = radarCubeData_demo(chirpsIdx, chanIdx , :);


% linear mode
channelData = abs(rangeProfileData(:));

%Range
%rangeBin = linspace(0, Params.numRangeBins * Params.RFParams.rangeResolutionsInMeters, Params.numRangeBins);
rangeBin = linspace(0,numrangeBins *range_resolution, numrangeBins);

% % not MTI filter range profile plot
% nexttile;
% plot(rangeBin,channelData)
% xlabel('Range (m)');                  
% ylabel('Range FFT output (dB)');        
% title('Range Profile (not MTI)');
% grid on;

%% Doppler FFT

%-----------------------------------------------------------------------------------------------------------
% MTI filter - range FFT 된 data에 대해
% single delay line canceller
% range에 대해 fft된 data를 chirp끼리 비교
radarCubeData_mti = zeros(128,4,256);
radarCubeData_mti(1,:,:) = radarCubeData_demo(1,:,:);
for chirpidx = 1:127
radarCubeData_mti(chirpidx+1,:,:) = radarCubeData_demo(chirpidx,:,:)-radarCubeData_demo(chirpidx+1,:,:);
end
% double delay line canceller
radarCubeData_mti2 = zeros(128,4,256);
radarCubeData_mti2(1,:,:) = radarCubeData_mti(1,:,:);
for chirpidx = 1:127
radarCubeData_mti2(chirpidx+1,:,:) = radarCubeData_mti(chirpidx,:,:)-radarCubeData_mti(chirpidx+1,:,:);
end

%MTI filter range profile plot
rangeProfileData_mti = radarCubeData_mti(chirpsIdx, chanIdx , :);
channelData_mti = abs(rangeProfileData_mti(:));
% nexttile;
% plot(rangeBin,channelData_mti)
% xlabel('Range (m)');                  
% ylabel('Range FFT output (dB)');        
% title('Range Profile (MTI)');
% grid on;
%-----------------------------------------------------------------------------------------------------------

N=length(adc_raw_data);
win_dop = hann(128);
% pre allocation
doppler = zeros(128,4,256);
for rangebin_size = 1:256
    for chIdx = 1:4
        win_dop = hann(128);
        DopData1 = squeeze(radarCubeData_mti(:, chIdx, rangebin_size)); %여기 radarCubeData_mti->radarCubeData_demo
        DopData = fftshift(fft(DopData1 .* win_dop, 128));
        doppler(:, chIdx, rangebin_size) = DopData;
    end
end      
%여기서 채널idx바꿀 수 있음.
doppler1 =  doppler(:,chanIdx,:);
doppler1_128x256 = squeeze(doppler1);
db_doppler = 10*log10(abs(doppler1_128x256'));

%가장 큰 값의 인덱스
[maxValue, linearIndex] = max(db_doppler(:));
[max_row, max_col] = ind2sub(size(db_doppler), linearIndex);

%% Range Doppler map

% 속도,range 계산
velocityAxis = -max_vel:velocity_resolution:max_vel;

nexttile;
imagesc(velocityAxis,rangeBin,db_doppler);
xlabel('Velocity (m/s)');
ylabel('Range (m)');
yticks(0:2:max(rangeBin));
title('Range-Doppler Map');
colorbar;
axis xy

% %2DFFT surface
% nexttile;
% surf(velocityAxis, rangeBin, db_doppler);
% xlabel('Velocity (m/s)');
% ylabel('Range (m)');
% yticks(0:1:max(rangeBin));
% title('Range-Doppler Map');
% colorbar;
% axis xy

%% Range-Angle FFT

% matlab example - plot_range_azimuth_2D
%parameter
minRangeBinKeep = 0;
rightRangeBinDiscard = 1;
log_plot = 1;
STATIC_ONLY = 0;

radar_data_pre_3dfft = permute(doppler,[3,1,2]);
dopplerFFTSize = size(radar_data_pre_3dfft,2);
rangeFFTSize = size(radar_data_pre_3dfft,1);
angleFFTSize = 256;

% ratio used to decide engergy threshold used to pick non-zero Doppler bins
ratio = 0.5;
DopplerCorrection = 0;

%-------------------------------------------------------------------------------------------
% DopplerCorrection=0해당 if문은 실행x
if DopplerCorrection == 1
    % add Doppler correction before generating the heatmap
    % pre allocation
    radar_data_pre_3dfft_DopCor= zeros(256,128,4);
    for dopplerInd = 1: dopplerFFTSize
        deltaPhi = 2*pi*(dopplerInd-1-dopplerFFTSize/2)/( TDM_MIMO_numTX*dopplerFFTSize);
        sig_bin_org =squeeze(radar_data_pre_3dfft(:,dopplerInd,:));
        for i_TX = 1:TDM_MIMO_numTX
            RX_ID = (i_TX-1)*numRxAnt+1 : i_TX*numRxAnt;
            corVec = repmat(exp(-1j*(i_TX-1)*deltaPhi), rangeFFTSize, numRxAnt);
            radar_data_pre_3dfft_DopCor(:,dopplerInd, RX_ID)= sig_bin_org(:,RX_ID ).* corVec;
        end
    end
    
    radar_data_pre_3dfft = radar_data_pre_3dfft_DopCor;
end
%--------------------------------------------------------------------------------------------

%% 1D CFAR
input = zeros(size(channelData_mti));

for n = 1:256
    input(n)=abs(channelData_mti(n));
end

%% CFAR PARAMETER
input_sz = size(input);

no_tcell = 20;
no_gcell = 2;
window_sz= no_gcell + no_tcell + 1 ;

beta = 0.1;

%% MTI filter
filtered_input = mti_filter(input, beta);

%% CA INIT
th_CA = zeros(input_sz);
factor_CA = 5;

%% OS INIT
th_OS = zeros(input_sz);
factor_OS = 5;
arr_sz = window_sz-no_gcell-1;

%% CA CFAR window
for cutIdx = 1:256
    cut = filtered_input(cutIdx);
    for windowIdx = 1:window_sz
    sum = 0;
    cnt = 0;
    for i = (no_tcell/2):-1:1
        if (cutIdx-i > 0)
            sum = sum + filtered_input(cutIdx-i);
            cnt = cnt+1;
        end
    end
    for j = 1:(no_tcell/2)
        if ((cutIdx+no_gcell+j) <= 256)
        sum = sum + filtered_input(cutIdx+no_gcell+j);
        cnt = cnt+1;
        end
    end
    mean = sum/cnt;
    th_CA(cutIdx) = (mean)*factor_CA;
    end
end

% 
% while true
%     detected_points_CA = find(filtered_input > th_CA);
%     [~, objectCnt_CA] = size(detected_points_CA);
% 
%     if objectCnt_CA == objectNum
%         break;
%     end
% 
%     factor_CA = factor_CA + 0.1;
% 
%     for cutIdx = 1:256
%         cut = filtered_input(cutIdx);
%         for windowIdx = 1:window_sz
%             sum = 0;
%             cnt = 0;
%             for i = (no_tcell/2):-1:1
%                 if (cutIdx-i > 0)
%                     sum = sum + filtered_input(cutIdx-i);
%                     cnt = cnt+1;
%                 end
%             end
%             for j = 1:(no_tcell/2)
%                 if ((cutIdx+no_gcell+j) <= 256)
%                     sum = sum + filtered_input(cutIdx+no_gcell+j);
%                     cnt = cnt+1;
%                 end
%             end
%             mean = sum/cnt;
%             th_CA(cutIdx) = (mean)*factor_CA;
%         end
%     end
% end

%% CA CFAR DETECTOR
detected_points_CA = find(filtered_input > th_CA);
[~, objectCnt_CA] = size(detected_points_CA);

%% OS CFAR 
for cutIdx = 1:256
    cut = filtered_input(cutIdx);
    arr = zeros(1,arr_sz);
    sorted_arr = zeros(1,arr_sz);
    cnt = 1;
    for windowIdx = 1:window_sz
        
        for i = (no_tcell/2):-1:1
            if (cutIdx-i > 0)
                arr(1,cnt) = filtered_input(cutIdx-i);
                cnt = cnt + 1;
            end
        end
        for j = 1:(no_tcell/2)
            if ((cutIdx+no_gcell+j) <= 256)
                arr(1,cnt) = filtered_input(cutIdx+no_gcell+j);
                cnt = cnt + 1;
            end
        end
        sorted_arr = sort(arr);
        id = ceil(3*cnt/4);
        th_OS(cutIdx) = sorted_arr(id)*factor_OS;
    end
end
% 
% 
% while true
%     detected_points_OS = find(filtered_input > th_OS);
%     [~, objectCnt_OS] = size(detected_points_OS);
% 
%     if objectCnt_OS == objectNum
%         break;
%     end
% 
%     factor_OS = factor_OS + 0.1;
% 
%     for cutIdx = 1:256
%         cut = filtered_input(cutIdx);
%         arr = zeros(1,arr_sz);
%         sorted_arr = zeros(1,arr_sz);
%         cnt = 1;
%         for windowIdx = 1:window_sz
% 
%             for i = (no_tcell/2):-1:1
%                 if (cutIdx-i > 0)
%                     arr(1,cnt) = filtered_input(cutIdx-i);
%                     cnt = cnt + 1;
%                 end
%             end
%             for j = 1:(no_tcell/2)
%                 if ((cutIdx+no_gcell+j) <= 256)
%                     arr(1,cnt) = filtered_input(cutIdx+no_gcell+j);
%                     cnt = cnt + 1;
%                 end
%             end
%             sorted_arr = sort(arr);
%             id = ceil(3*cnt/4);
%             th_OS(cutIdx) = sorted_arr(id)*factor_OS;
%         end
%     end
% end

%% OS CFAR DETECTOR
detected_points_OS = find(filtered_input > th_OS);
[~, objectCnt_OS] = size(detected_points_OS);

nexttile;
plot(rangeBin, filtered_input, 'LineWidth', 0.5);
hold on;
plot(rangeBin, th_CA, 'Color', 'r', 'LineWidth', 1.5);
plot(rangeBin, th_OS, 'LineStyle', '--', 'Color', 'b', 'LineWidth', 1.5);
mylinestyles = ["-"; "--"];
ax = gca; 
ax.LineStyleOrder = mylinestyles;
plot(rangeBin(detected_points_CA), filtered_input(detected_points_CA), 'o', 'MarkerSize', 8, 'Color', 'r');
hold on;
plot(rangeBin(detected_points_OS), filtered_input(detected_points_OS), 'o', 'MarkerSize', 7, 'Color', 'b');

legend('Range Profile', 'CA-CFAR Threshold', 'OS-CFAR Threshold', 'CA detect data', 'OS detect data');
xlabel('Range (m)');
ylabel('Power (dB)');
titleStr = sprintf('CFAR Detection\nNumber of detections: %d', length(detected_points_OS));
title(titleStr);

for i = 1:length(detected_points_OS)
    text(rangeBin(detected_points_OS(i)), filtered_input(detected_points_OS(i)), [num2str(rangeBin(detected_points_OS(i))), 'm'], 'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
end

%% 2D CFAR input
sz_c = size(db_doppler,1);
sz_r = size(db_doppler,2);

for i = 1:sz_c
    for j = 1:sz_r
        input(i , j) = db_doppler(i, j);
    end
end
 
%% CA CFAR PARAMETER
input_sz = size(input);

Nt = 32;
Ng = 4;
window_sz= Ng + Nt + 1 ;
window = zeros(window_sz);
th = zeros(input_sz);
factor = 4;
beta = 0.1;

%% 2D CA-OS CFAR Algorithm
for cutRIdx = 1:sz_r
    for cutCIdx = 1:sz_c
        cut = input(cutCIdx, cutRIdx);
        arr = zeros(1, window_sz);
        %cnt_OS = 1;
        for windowCIdx = 1:window_sz
            for i = (Nt/2):-1:1
                if (windowCIdx-i > 0)
                    arr(1, windowCIdx-i) = input(windowCIdx-i,cutRIdx);
                    %cnt_OS = cnt_OS+1;
                end
            end
            for j = 1:(Nt/2)
                if ((windowCIdx+Ng+j) <= 256)
                    arr(1, windowCIdx+Ng+j) = input(windowCIdx+Ng+j,cutRIdx);
                    %cnt_OS = cnt_OS+1;
                end
            end
            sorted_arr = sort(arr);
            size_arr = size(sorted_arr);
            id = ceil(3*(size_arr(2))/4);
            value_OS = sorted_arr(id)*1.2;
        end

        for windowRIdx = 1:window_sz
            sum = 0;
            cnt_CA = 0;
            for i = (Nt/2):-1:1
                if (cutRIdx-i > 0)
                    sum = sum + input(cutCIdx, cutRIdx-i);
                    cnt_CA = cnt_CA+1;
                end
            end
            for j = 1:(Nt/2)
                if ((cutRIdx+Ng+j) <= 128)
                sum = sum + input(cutCIdx, cutRIdx+Ng+j);
                cnt_CA = cnt_CA+1;
                end
            end
            mean = sum/cnt_CA;
            value_CA = mean*1.2;

        end

        if value_CA > value_OS
            th(cutCIdx, cutRIdx) = value_CA;
        else
            th(cutCIdx, cutRIdx) = value_OS;
        end
    end 
end



%% detect
detected_points = zeros(input_sz);

for cutRIdx = 1:sz_r
    for cutCIdx = 1:sz_c
        cut = input(cutCIdx, cutRIdx);
        compare = th(cutCIdx, cutRIdx);
        if(cut > compare)
            detected_points(cutCIdx, cutRIdx) = cut;
        end
        if(cut <= compare)
            detected_points(cutCIdx, cutRIdx) = 0;
        end
    end
end

nexttile;
imagesc(velocityAxis,rangeBin,detected_points);
xlabel('Velocity (m/s)');
ylabel('Range (m)');
yticks(0:2:max(rangeBin));
title('2D CFAR Target Detect');
colorbar;
axis xy

%% Data clustering
non_zero_indices = find(detected_points ~= 0);
sz_data = size(non_zero_indices(1));
size_data = sz_data(1);
data = zeros(size_data, 2);
cnt = 1;

for ynum = 1: 128
    for xnum = 1:256
        if(detected_points(xnum, ynum) ~= 0)
            data(cnt, 1) = ynum;
            data(cnt, 2) = xnum;
        end

        cnt = cnt + 1;
    end
end

nexttile;

k = 4;
[idx, centers] = kmeans(data, k);

for i = 1:k
    % 현재 클러스터링 군집에 속하는 인덱스 추출
    cluster_indices = find(idx == i);
    % 현재 클러스터링 군집의 점의 수 계산
    num_points = length(cluster_indices);
    % 현재 클러스터링 군집의 점의 수 출력
    disp(['Cluster ' num2str(i) ' has ' num2str(num_points) ' points.']);
end

% 클러스터 표기
gscatter(data(:,1), data(:,2), idx);
gscatter(data(:,1), data(:,2), idx);

hold on;

for i = 1:k
    center = centers(i,:);
    radius = 5; 
    theta = linspace(0, 2*pi, 100);
    x_circle = center(1) + radius * cos(theta);
    y_circle = center(2) + radius * sin(theta);
    plot(x_circle, y_circle, 'k--'); 

    % % 중심점 표시 (x로)
    % plot(center(1), center(2), 'rx', 'MarkerSize', 10);
    % 
    % % 중심점 좌표 표시
    % text(center(1), center(2), ['(' num2str(center(1)) ',' num2str(center(2)) ')'], 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
end


%axis equal;
legend('data1', 'data2', 'data3', 'data4');

% xlim([min(velocityAxis), max(velocityAxis)]);
% ylim([min(rangeBin), max(rangeBin)]);
xlabel('Velocity (m/s)');
ylabel('Range (m)');
title('Data Clustering');

hold off;



%% filter function
function filtered_input = mti_filter(rangeprofile, beta)
    len = length(rangeprofile);
    filtered_input = zeros(size(rangeprofile));
    for i = 2:len
        filtered_input(i) = beta * filtered_input(i-1) + (1 - beta) * rangeprofile(i);
    end
end