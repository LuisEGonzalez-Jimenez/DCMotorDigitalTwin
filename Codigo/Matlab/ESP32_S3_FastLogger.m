%% --- ESP32 S3 Logger with CSV Output (Time + Value) --- // ESP32_S3_FastLogger
clear; clc;

% --- User settings ---
port = "COM13";        % change to your ESP32 COM port
baudRate = 115200;     
logDuration = 5;       % seconds
flushLines = 20;       % lines to flush at start
filename = 'ADC_log.csv';

% --- Connect to ESP32 ---
disp('Connecting to ESP32...');
esp = serialport(port, baudRate);
configureTerminator(esp,"LF"); % Make sure we read line-by-line

% --- Flush startup messages ---
disp('Flushing startup messages...');
for i = 1:flushLines
    if esp.NumBytesAvailable > 0
        readline(esp); 
        pause(0.05);
    end
end

% --- Logging ---
disp('Logging data from ESP32...');
data = [];   % will store [time, value]
t0 = tic;

% --- Logging ---
disp('Logging data from ESP32...');
data = [];
t0 = tic;

try
    while toc(t0) < logDuration
        if esp.NumBytesAvailable > 0
            line = readline(esp);
            value = str2double(line);

            if ~isnan(value)
                elapsed = toc(t0);
                data(end+1,:) = [elapsed, value]; %#ok<SAGROW>
                fprintf('t=%.3fs, value=%d\n', elapsed, value);
            end
        end
        % 🔴 REMOVE pause(samplePeriod); 
        % let the ESP pacing define sample rate
    end
catch ME
    disp('Logging stopped due to error.');
    clear esp
    rethrow(ME)
end


disp('Logging finished.');

% --- Save data ---
if ~isempty(data)
    writematrix(data, filename);
    disp(['Data saved to ' filename ' (time + value)']);
else
    warning('No numeric data was recorded.');
end

% --- Cleanup ---
clear esp;
