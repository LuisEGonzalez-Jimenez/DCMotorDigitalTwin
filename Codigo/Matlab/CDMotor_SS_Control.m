%% ===============================================================
%  CDMotor_SS_Control.m
%  MATLAB-driven control of the ESP32-S3 DC motor step test
%  --------------------------------------------------------------
%  1) Asks user for Ts (ms), duration (s), and PWM step (%)
%  2) Sends parameters to ESP32-S3 via serial
%  3) Waits for test completion and closes connection
%  ===============================================================

clear; clc;

% Close any previously open serial ports or files
if ~isempty(instrfind)
    fclose(instrfind);
    delete(instrfind);
end
%% === User inputs ===
Ts_ms       = input('Enter sample period Ts (ms): ');
step_time_s = input('Enter step test duration (s): ');
pwm_step    = input('Enter PWM step %% (0–100): ');

fprintf('\nParameters entered:\n');
fprintf('Ts = %g ms | Duration = %g s | PWM = %g%%\n', Ts_ms, step_time_s, pwm_step);

%% === Configure serial connection ===
port = "COM13";      % Adjust to your ESP32-S3 port
baud = 115200;       % Must match PlatformIO sketch
esp = serialport(port, baud);

configureTerminator(esp, "LF");
flush(esp);  % clear buffers

fprintf('\nWaiting for ESP32 ready signal...\n');

%% === Wait until ESP32 prints the ready prompt ===
ready = false;
while ~ready
    if esp.NumBytesAvailable > 0
        line = readline(esp);
        disp(line);
        if contains(line, "READY")
            ready = true;
        end
    end
end

%% === Send test parameters ===
cmd = sprintf("%d,%d,%d\n", Ts_ms, step_time_s, pwm_step);
fprintf('Sending parameters: %s\n', cmd);
writeline(esp, cmd);

%% === Read ESP32 responses ===
%=== Prepare unified log file ===
logName = "CD_Motor_data.csv";

% If it exists, delete it first to start fresh
if isfile(logName)
    delete(logName);
    fprintf('Old log file "%s" deleted.\n', logName);
end

% Open a new clean file for writing
fid = fopen(logName, 'w');
fprintf('Logging to file: %s\n', logName);

while true
    if esp.NumBytesAvailable > 0
        line = readline(esp);
        disp(line);
        fprintf(fid, '%s\n', line);
        if contains(line, "Test complete")
            break;
        end
    end
end

fclose(fid);
fprintf('\nTest finished. Data saved as %s\n', logName);

clear esp; % release COM port

%% === Optional: automatically build model ===
reply = input('Run System Identification build? (y/n): ', 's');
if strcmpi(reply, 'y')
    CDMotor_SS_build;   % assumes the file is in the same MATLAB folder
end
