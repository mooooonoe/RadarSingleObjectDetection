run('pre_data_load.m');

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

% nexttile;
figure();
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


%% filter function
function filtered_input = mti_filter(rangeprofile, beta)
    len = length(rangeprofile);
    filtered_input = zeros(size(rangeprofile));
    for i = 2:len
        filtered_input(i) = beta * filtered_input(i-1) + (1 - beta) * rangeprofile(i);
    end
end