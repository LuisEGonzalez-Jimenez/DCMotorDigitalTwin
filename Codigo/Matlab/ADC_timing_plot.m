%% --- Plot ADC Log (Time + Value) --- % ADC_timing_plot
data = readmatrix('ADC_log.csv');
t = data(:,1);
values = data(:,2);

% --- Limit to first 1 second ---
mask = t <= 1; 
t_plot = t(mask);
values_plot = values(mask);

% --- Plot ---
figure;
plot(t_plot, values_plot, '-b','LineWidth',1.2);
xlabel('Time (s)');
ylabel('ADC Value');
title('ADC Data (ESP32-S3 timing, first 1 second)');
grid on;
