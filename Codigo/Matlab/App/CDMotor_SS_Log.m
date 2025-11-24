function [Time, PWM_i, Omega_o, I_o, Ts, t_filtered] = CDMotor_SS_Log(Ts_ms, pwm_list, port, baud)
%% CDMotor_SS_Log.m (function version)
% ESP32-S3 DC Motor System-ID Log (3-step sequence)
% Rodrigo Ramos — 2025
% -------------------------------------------------------------
% Usage:
%   [Time, PWM_i, Omega_o, I_o, Ts, t_filtered] = ...
%       CDMotor_SS_Log(Ts_ms, pwm_list, port, baud);
%
%   Ts_ms    : sampling time in ms
%   pwm_list : vector with 3 PWM values (e.g., [30 50 80])
%   port     : serial port (string, e.g. "COM13")
%   baud     : baud rate (e.g., 921600)
% -------------------------------------------------------------

clc; fclose('all');

fprintf("=== CDMotor_SS_Log ===\n");
fprintf("This function uses:\n");
fprintf("    Ts_ms     = %g ms\n", Ts_ms);
fprintf("    pwm_list  = [%g %g %g] %%\n\n", pwm_list(1), pwm_list(2), pwm_list(3));

%% === Validate input arguments ===
if numel(pwm_list) ~= 3
    error('pwm_list must contain exactly 3 PWM values.');
end

if Ts_ms <= 0
    error('Ts_ms must be positive.');
end

%% === Clean old logs ===
if isfile("CD_Motor_Measurements.csv")
    delete("CD_Motor_Measurements.csv");
end
fprintf("Old CD_Motor_Measurements.csv removed (if it existed).\n");

%% === Open serial connection ===
fprintf("Opening serial %s @ %d baud...\n", port, baud);
s = serialport(port, baud, "Timeout", 20);
configureTerminator(s,"LF");

pause(1); flush(s);

fprintf("Waiting for ESP32-S3 READY...\n");
line = "";
while ~contains(line,"READY")
    if s.NumBytesAvailable > 0
        line = readline(s);
    end
end

fprintf("Connected. Board is READY.\n\n");

%% === Send command to ESP32 for 3-step test ===
fprintf("Starting 3-step test sequence...\n");

cmd = sprintf("SEQ,%d,%d,%d,%d\n", Ts_ms, pwm_list(1), pwm_list(2), pwm_list(3));
write(s, cmd, "string");

fprintf("Sent command: %s\n", cmd);

% Wait for acknowledgment
while true
    if s.NumBytesAvailable > 0
        line = readline(s);
        if contains(line, "Starting sequence")
            fprintf("%s\n", line);
            break;
        end
    end
end

%% === Create output CSV ===
fid = fopen("CD_Motor_Measurements.csv","w");
fprintf(fid,"t_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM\n");

%% === Read streamed data ===
fprintf("Logging data...\n");

while true
    if s.NumBytesAvailable > 0
        line = readline(s);

        if contains(line, "SEQ DONE")
            fprintf("Sequence complete.\n");
            break;
        elseif contains(line, "t_s,")
            continue; % ESP header lines
        else
            fprintf(fid, "%s\n", strtrim(line));
        end
    end
end

fclose(fid);
fprintf("Saved: CD_Motor_Measurements.csv\n");

clear s;

%% === Load CSV and extract signals ===
csvName = "CD_Motor_Measurements.csv";

fprintf("\nImporting log file: %s\n", csvName);

if ~isfile(csvName)
    error('File "%s" not found in folder: %s', csvName, pwd);
end

opts = detectImportOptions(csvName);
opts.SelectedVariableNames = {'t_s','duty_pct','omega_rad_s','current_A'};

data = readtable(csvName, opts);

% Extract signals
Time       = data.t_s;
PWM_i      = data.duty_pct;
Omega_o    = data.omega_rad_s;
I_o        = data.current_A;

fprintf("Loaded %d samples.\n", height(data));
fprintf("Time range: %.3f – %.3f s\n", min(Time), max(Time));
fprintf("PWM range: %.1f – %.1f %%\n", min(PWM_i), max(PWM_i));
fprintf("Omega range: %.3f – %.3f rad/s\n", min(Omega_o), max(Omega_o));
fprintf("Current range: %.3f – %.3f A\n\n", min(I_o), max(I_o));

% Sampling time setup
Ts = Ts_ms / 1000;
N = numel(I_o);
t_filtered = (0:N-1)' * Ts;

fprintf("Using Ts = %.6f s (%g ms)\n", Ts, Ts_ms);
fprintf("Generated filtered time vector (%d samples)\n\n", N);