%% Log_filtering.m
% Rodrigo Ramos - HIL DC Motor Project
% Pair with "DC_Motor_SS" PlatformIO project
% --------------------------------------------------------------
% This script imports specific signals from a CSV log file:
%   Columns in file: [Ts_real_s, time_s, PWM_input, omega_rad_s, current_A, RPM]
%   Imported variables: 
%       Time   -> time_s
%       PWM_i  -> PWM_input
%       Omega_o -> omega_rad_s
%       I_o    -> current_A
% --------------------------------------------------------------

clc; clear; close all;

%% Ask user for filename
disp('Please input the name of the .csv file to import from (without extension):');
fileName = input('File name: ', 's');
fullName = strcat(fileName, '.csv');

% Check if file exists
if ~isfile(fullName)
    error('File "%s" not found in current directory: %s', fullName, pwd);
end

%% Read CSV file
opts = detectImportOptions(fullName);

% Ensure we only read the necessary columns
opts.SelectedVariableNames = {'time_s', 'PWM_input', 'omega_rad_s', 'current_A'};

data = readtable(fullName, opts);

%% Extract variables into workspace
Time    = data.time_s;
PWM_i   = data.PWM_input;
Omega_o = data.omega_rad_s;
I_o     = data.current_A;

%% Summary
fprintf('\n=== Log Import Summary ===\n');
fprintf('File: %s\n', fullName);
fprintf('Samples loaded: %d\n', height(data));
fprintf('Time range: %.3f s – %.3f s\n', min(Time), max(Time));
fprintf('PWM range: %.1f – %.1f\n', min(PWM_i), max(PWM_i));
fprintf('Omega range: %.3f – %.3f rad/s\n', min(Omega_o), max(Omega_o));
fprintf('Current range: %.3f – %.3f A\n', min(I_o), max(I_o));
fprintf('===========================\n\n');

%% Plot quick overview
figure('Name','Imported Motor Signals','NumberTitle','off');
subplot(3,1,1);
plot(Time, PWM_i, 'LineWidth', 1.2); grid on;
ylabel('PWM [%]'); title('PWM Input');

subplot(3,1,2);
plot(Time, Omega_o, 'LineWidth', 1.2); grid on;
ylabel('\omega [rad/s]'); title('Angular Velocity');

subplot(3,1,3);
plot(Time, I_o, 'LineWidth', 1.2); grid on;
ylabel('Current [A]'); xlabel('Time [s]');
title('Motor Current');

disp('Data successfully imported and plotted.');

%% Start filtering process

%% Sampling time input with safety check
Ts_ms = input('Please input the sampling time Ts (ms): ');
if Ts_ms < 0.05
    warning('Ts_ms = %.6f ms seems too small. Did you mean %.3f ms instead?', Ts_ms, Ts_ms*1000);
end
Ts = Ts_ms / 1000;   % convert to seconds

% Create a uniform time vector based on Ts and signal length
N = numel(I_o);          % or whichever signal you’ll filter
t_filtered = (0:N-1)' * Ts;  % column vector [0 Ts 2Ts ... (N-1)*Ts]

fprintf('Created time vector of size: [%d x %d]\n', size(t_filtered,1), size(t_filtered,2));

%% Interactive filtering for I_o (Current)
disp('=== Interactive Filtering: Current (I_o) ===');
disp('This filter uses: G(s) = a^2 / (s^2 + 2*a*s + a^2)');
disp('Type a new value for a to update the filter.');
disp("Press 'x' to finish.");

signal = I_o;   % Current signal

figure('Name','Interactive Filtering - Current','NumberTitle','off');
hold on; grid on;
plot(t_filtered, signal, 'Color',[0.6 0.6 0.6], 'DisplayName','Original');
xlabel('Time [s]'); ylabel('Current [A]');
title('Interactive Filtering - I_o');
legend show;

while true
    userInput = input('Enter new a value for I_o (or x to stop): ', 's');
    if strcmpi(userInput, 'x')
        disp('Finished filtering I_o.');
        break;
    end
    a = str2double(userInput);
    if isnan(a) || a <= 0
        disp('Invalid input. Enter a positive number or x to stop.');
        continue;
    end
    
    filtro = tf([a^2], [1, 2*a, a^2]);
    I_filt = lsim(filtro, signal, t_filtered);

    
    plot(t_filtered, I_filt, 'DisplayName', sprintf('a=%.0f', a));
    legend show;
    
    assignin('base','I_filt',I_filt);
end


%% Interactive filtering for Omega_o (Angular Speed)
disp('=== Interactive Filtering: Angular Speed (Omega_o) ===');
disp('Type a new value for a to update the filter.');
disp("Press 'x' to finish.");

signal = Omega_o;  % Angular velocity signal

figure('Name','Interactive Filtering - Omega','NumberTitle','off');
hold on; grid on;
plot(t_filtered, signal, 'Color',[0.6 0.6 0.6], 'DisplayName','Original');
xlabel('Time [s]'); ylabel('\omega [rad/s]');
title('Interactive Filtering - Omega_o');
legend show;

while true
    userInput = input('Enter new a value for Omega_o (or x to stop): ', 's');
    if strcmpi(userInput, 'x')
        disp('Finished filtering Omega_o.');
        break;
    end
    a = str2double(userInput);
    if isnan(a) || a <= 0
        disp('Invalid input. Enter a positive number or x to stop.');
        continue;
    end
    
    filtro = tf([a^2], [1, 2*a, a^2]);
    w_filt = lsim(filtro, signal, t_filtered);
    
    plot(t_filtered, w_filt, 'DisplayName', sprintf('a=%.0f', a));
    legend show;
    
    assignin('base','w_filt',w_filt);
end


%% Setting up variables for System Identification Toolbox
disp('=== Preparing variables for System Identification Toolbox ===');

ss_Toolbox_i = 12 * PWM_i / 100;   % Convert PWM [%] to Volts (0–12 V range)
ss_Toolbox_o = [I_filt, w_filt];            % Columns: [Current, Omega]

assignin('base','ss_Toolbox_i',ss_Toolbox_i);
assignin('base','ss_Toolbox_o',ss_Toolbox_o);

disp('Variables ready: ss_Toolbox_i and ss_Toolbox_o now in workspace.');
