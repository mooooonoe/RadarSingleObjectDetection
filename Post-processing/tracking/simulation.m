clear; clc; close all;
% MATLAB code to integrate provided data for tracking maneuvering targets

% Define the scenario
t = linspace(0, 2*pi, 500);  % Time vector
dt = t(2) - t(1);  % Time step

% Position (S-shaped trajectory)
x = t;  % Linear progression for x (S-shape)
y = 0.5 * sin(t);  % Reduced amplitude for y (flatter S-shape)

% Velocity (derivative of position)
dxdt = ones(size(t));  % Constant velocity for x
dydt = 0.5 * cos(t);  % Derivative of 0.5*sin(t) for velocity in y

% Acceleration (second derivative of position)
d2xdt2 = zeros(size(t));  % Zero acceleration in x (constant velocity)
d2ydt2 = -0.5 * sin(t);  % Second derivative of 0.5*sin(t) for acceleration in y

% Angular speed (scalar)
omega = (dxdt .* d2ydt2 - dydt .* d2xdt2) ./ (dxdt.^2 + dydt.^2);

% Speed (scalar)
speed = sqrt(dxdt.^2 + dydt.^2);

% Measurement error
gps_sig = 0.2;  % Base noise level
additional_noise_factor = 0.3; % Additional noise factor

% Add random noise with varying levels
x_gps = x + gps_sig * randn(size(x)) + additional_noise_factor * randn(size(x));
y_gps = y + gps_sig * randn(size(y)) + additional_noise_factor * randn(size(y));
omega_sens = omega + (gps_sig + additional_noise_factor) * randn(size(omega));
speed_sens = speed + (gps_sig + additional_noise_factor) * randn(size(speed));

% Plotting the position
figure;
scatter(x_gps, y_gps, 5, 'red', 'filled', 'DisplayName', 'Position estimation');
xlabel('x');
ylabel('y');
legend;
hold on;

% Integrate generated data into tracking filters

% Define measurements to be the position with noise
measPos = [x_gps; y_gps; zeros(size(x_gps))];

% Define the initial state and covariance
positionSelector = [1 0 0 0 0 0; 0 0 1 0 0 0; 0 0 0 0 1 0]; % Position from state
initialState = positionSelector' * measPos(:,1);
initialCovariance = diag([1, 1e4, 1, 1e4, 1, 1e4]); % Velocity is not measured

% Moving average for velocity calculation (to estimate velocity fluctuation)
windowSize = 5; % A small window size to compute the moving average velocity
smooth_dxdt = smooth(dxdt, windowSize);
smooth_dydt = smooth(dydt, windowSize);

% Calculate the mobility in horizontal (x) and vertical (y) directions
horizontal_mobility = std(smooth_dxdt);  % Horizontal mobility (based on x velocity)
vertical_mobility = std(smooth_dydt);  % Vertical mobility (based on y velocity)

% Dynamically adjust ProcessNoise based on calculated mobility
% Here we multiply the mobility by a scaling factor to control the process noise
horizontal_process_noise = horizontal_mobility * 100;  % Larger value for horizontal mobility
vertical_process_noise = vertical_mobility * 1;  % Smaller value for vertical mobility

% % Print the calculated mobility values for verification
% disp(['Horizontal mobility (standard deviation of dx/dt): ', num2str(horizontal_mobility)]);
% disp(['Vertical mobility (standard deviation of dy/dt): ', num2str(vertical_mobility)]);

% Create a constant-velocity trackingEKF
cvekf = trackingEKF(@constvel, @cvmeas, initialState, ...
    'StateTransitionJacobianFcn', @constveljac, ...
    'MeasurementJacobianFcn', @cvmeasjac, ...
    'StateCovariance', initialCovariance, ...
    'HasAdditiveProcessNoise', false, ...
    'ProcessNoise', diag([vertical_process_noise, horizontal_process_noise, 0.05])); % Use calculated mobility for process noise

% Track using the constant-velocity filter
numSteps = numel(t);
dist = zeros(1, numSteps);
estPos = zeros(3, numSteps);
for i = 2:numSteps
    predict(cvekf, dt);
    dist(i) = distance(cvekf, measPos(:,i)); % Distance from true position
    estPos(:,i) = positionSelector * correct(cvekf, measPos(:,i));
end
hold on;
plot(estPos(1,:), estPos(2,:), '.g', 'DisplayName', 'CV Low PN');
title('True and Estimated Positions with CV Filter');
axis equal;
legend;

% Increase the process noise for the constant-velocity filter
cvekf2 = trackingEKF(@constvel, @cvmeas, initialState, ...
    'StateTransitionJacobianFcn', @constveljac, ...
    'MeasurementJacobianFcn', @cvmeasjac, ...
    'StateCovariance', initialCovariance, ...
    'HasAdditiveProcessNoise', false, ...
    'ProcessNoise', diag([1, 100, 0.05])); % Large uncertainty in the horizontal acceleration

dist = zeros(1, numSteps);
estPos = zeros(3, numSteps);
for i = 2:numSteps
    predict(cvekf2, dt);
    dist(i) = distance(cvekf2, measPos(:,i)); % Distance from true position
    estPos(:,i) = positionSelector * correct(cvekf2, measPos(:,i));
end
hold on;
plot(estPos(1,:), estPos(2,:), '.c', 'DisplayName', 'CV High PN');
title('True and Estimated Positions with Increased Process Noise');
axis equal;
legend;

% Use an interacting multiple-model (IMM) filter
imm = trackingIMM('TransitionProbabilities', 0.19); % Default IMM with three models
initialize(imm, initialState, initialCovariance);

% Track using the IMM filter
dist = zeros(1, numSteps);
estPos = zeros(3, numSteps);
modelProbs = zeros(3, numSteps);
modelProbs(:,1) = imm.ModelProbabilities;
for i = 2:numSteps
    predict(imm, dt);
    dist(i) = distance(imm, measPos(:,i)); % Distance from true position
    estPos(:,i) = positionSelector * correct(imm, measPos(:,i));
    modelProbs(:,i) = imm.ModelProbabilities;
end

windowSize = 100; % Size of the moving average window
smoothedEstPos = zeros(size(estPos));
for dim = 1:3
    smoothedEstPos(dim, :) = movmean(estPos(dim, :), windowSize);
end

% Plot the results
hold on;
title('True and Estimated Positions with IMM Filter');
plot(smoothedEstPos(1,:), smoothedEstPos(2,:), '.b', 'DisplayName', 'IMM');
axis equal;
legend;


% % Plot normalized distance
% figure;
% plot((1:numSteps)*dt, dist, 'g', 'DisplayName', 'CV Low PN');
% title('Normalized Distance from Estimated Position to True Position');
% xlabel('Time (s)');
% ylabel('Normalized Distance');
% legend;
% 
% % Plot normalized distance for other filters as well
% hold on;
% plot((1:numSteps)*dt, dist, 'c', 'DisplayName', 'CV High PN');
% title('Normalized Distance from Estimated Position to True Position');
% xlabel('Time (s)');
% ylabel('Normalized Distance');
% legend;
% 
% hold on;
% plot((1:numSteps)*dt, dist, 'm', 'DisplayName', 'IMM');
% title('Normalized Distance from Estimated Position to True Position');
% xlabel('Time (s)');
% ylabel('Normalized Distance');
% legend;
% 
% % Plot model probabilities
% figure;
% plot((1:numSteps)*dt, modelProbs);
% title('Model Probabilities vs. Time');
% xlabel('Time (s)');
% ylabel('Model Probabilities');
% legend('IMM-CV', 'IMM-CA', 'IMM-CT');
