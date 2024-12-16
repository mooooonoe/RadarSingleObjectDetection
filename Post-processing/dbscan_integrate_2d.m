% run('cfar_perform_2d.m');
run('cfar_optimize_2d.m');

%% dbscan
[row_2d, col_2d] = find(detected_points ~= 0);
sz_data = size(row_2d);
size_data = sz_data(1);
data = zeros(size_data, 2);
cnt = 1;

for idx_cl = 1:size_data
      data(cnt, 1) = col_2d(idx_cl);
      data(cnt, 2) = row_2d(idx_cl);
      cnt = cnt + 1;
end

eps = 2;
MinPts = 10;

[idx, ~] = dbscan(data, eps, MinPts);

clusterGrid = zeros(length(rangeBin), length(velocityAxis));

for i = 1:length(data)
    clusterGrid(data(i,2), data(i,1)) = idx(i);
end

% negative value 
for i = 1:length(data)
    if clusterGrid(data(i,2), data(i,1)) <0
        clusterGrid(data(i,2), data(i,1)) = 0;
    end
end

figure();
imagesc(velocityAxis,rangeBin,clusterGrid);
hold on;
xlabel('Velocity (m/s)');
ylabel('Range (m)');
title('Data Clustering');
axis xy
colorbar;