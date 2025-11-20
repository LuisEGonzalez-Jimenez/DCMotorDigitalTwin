%% Log_filtering.m
% Rodrigo Ramos - HIL DC Motor Project
% Pipeline version for MATLAB App
% --------------------------------------------------------------
% This script:
%   - Loads CD_Motor_Measurements.csv automatically
%   - Uses Ts_ms and V_in from workspace
%   - Performs interactive filtering of current & omega
%   - Exports Mimo_SS_input and Mimo_SS_output to workspace
% --------------------------------------------------------------

clc; close all;

fprintf("=== Log_filtering.m ===\n");
fprintf("This script expects the following in workspace:\n");
fprintf("    CD_Motor_Measurements.csv in current folder\n");
fprintf("    Ts_ms  -> sampling time (ms)\n");
fprintf("    V_in   -> motor driver voltage (0–24 V)\n\n");


%% === 1. Check required workspace variables ===
if ~exist('Ts_ms', 'var')
    error('Missing variable Ts_ms in workspace.');
end

if ~exist('V_in', 'var')
    error('Missing variable V_in in workspace.');
end

if V_in < 0 || V_in > 24
    error('V_in must be between 0 and 24 V.');
end

%% === 2. Interactive filtering: Current (I_o) ===
disp('=== Interactive Filtering: Current (I_o) ===');
disp('Filter: G(s) = a^2 / (s^2 + 2*a*s + a^2)');
disp("Enter filter value to update, or 'x' to finish.");

signal = I_o;

figure('Name','Interactive Filtering - Current','NumberTitle','off');
hold on; grid on;
plot(t_filtered, signal, 'Color',[0.7 0.7 0.7], 'DisplayName','Original');
xlabel('Time [s]'); ylabel('Current [A]');
title('Interactive Filtering - I_o');
legend show;

I_filt = I_o; % default if user stops early

while true
    userInput = input('a for I_o filter (or x): ', 's');
    if strcmpi(userInput,'x')
        disp('Finished I_o filtering.');
        break;
    end

    a = str2double(userInput);
    if isnan(a) || a <= 0
        disp('Invalid a. Try again.');
        continue;
    end

    filtro = tf([a^2],[1 2*a a^2]);
    I_filt = lsim(filtro, signal, t_filtered);

    plot(t_filtered, I_filt, 'DisplayName', sprintf('a=%.0f', a));
    legend show;
end


%% === 3. Interactive filtering: Omega_o ===
disp('=== Interactive Filtering: Angular Speed (Omega_o) ===');
disp("Enter 'a' values to update, or 'x' to finish.");

signal = Omega_o;

figure('Name','Interactive Filtering - Omega','NumberTitle','off');
hold on; grid on;
plot(t_filtered, signal, 'Color',[0.7 0.7 0.7], 'DisplayName','Original');
xlabel('Time [s]'); ylabel('\omega [rad/s]');
title('Interactive Filtering - Omega_o');
legend show;

w_filt = Omega_o;

while true
    userInput = input('a for Omega_o filter (or x): ', 's');
    if strcmpi(userInput,'x')
        disp('Finished Omega_o filtering.');
        break;
    end

    a = str2double(userInput);
    if isnan(a) || a <= 0
        disp('Invalid a. Try again.');
        continue;
    end

    filtro = tf([a^2],[1 2*a a^2]);
    w_filt = lsim(filtro, signal, t_filtered);

    plot(t_filtered, w_filt, 'DisplayName', sprintf('a=%.0f', a));
    legend show;
end


%% === 4. Prepare variables for System Identification Toolbox ===
disp('=== Preparing MIMO SS variables ===');

% MIMO input = effective voltage
Mimo_SS_input = (V_in * PWM_i) / 100;

% MIMO output = [current_filtered, omega_filtered]
Mimo_SS_output = [I_filt, w_filt];

assignin('base','Mimo_SS_input',  Mimo_SS_input);
assignin('base','Mimo_SS_output', Mimo_SS_output);
assignin('base','Ts', Ts);

fprintf("Exported to workspace:\n");
fprintf("  Mimo_SS_input  (input voltage)\n");
fprintf("  Mimo_SS_output (filtered output signals)\n");
fprintf("  Ts             (sampling time)\n\n");

fprintf("=== Log_filtering.m completed ===\n");
