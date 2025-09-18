%% --- Plot ADC Log ---
% Load the CSV file
data = readmatrix('ADC_log.csv');

% Create a time vector based on sampling interval
samplePeriod = 0.1;        % seconds (same as used in logging)
t = (0:length(data)-1)' * samplePeriod;  

% Plot
figure;
plot(t, data, '-b', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('ADC Value');
title('Logged ADC Data from ESP32 S3');
grid on;
