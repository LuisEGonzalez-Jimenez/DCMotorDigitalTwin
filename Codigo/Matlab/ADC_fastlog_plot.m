%% --- Plot ADC Log (Time + Value) --- // ADC_fastlog_plot
data = readmatrix('ADC_log.csv');

time = data(:,1);
values = data(:,2);

% Clip to first second if desired
clipWindow = 1;  % seconds
mask = time <= clipWindow;

figure;
plot(time(mask), values(mask), '-b', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('ADC Value');
title(sprintf('ADC Data (First %.1f s)', clipWindow));
grid on;
