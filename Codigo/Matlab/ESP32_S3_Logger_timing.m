%% --- ESP32 S3 Logger (ESP provides timing) //ESP32_S3_Logger_timing
clear; clc;

% --- User settings ---
port = "COM13";        % change if needed
baudRate = 115200;     
logDuration = 5;       % seconds
flushLines = 20;       % discard startup junk
filename = 'ADC_log.csv';

% --- Connect to ESP32 ---
disp('Connecting to ESP32...');
esp = serialport(port, baudRate);
configureTerminator(esp,"LF");

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
data = [];

t0 = tic;
try
    while toc(t0) < logDuration
        if esp.NumBytesAvailable > 0
            line = readline(esp);
            parts = split(strtrim(line), ",");
            if numel(parts) == 2
                tVal = str2double(parts{1});
                adcVal = str2double(parts{2});
                if ~isnan(tVal) && ~isnan(adcVal)
                    data(end+1,:) = [tVal, adcVal]; %#ok<SAGROW>
                    fprintf("t=%.3fs, value=%d\n", tVal, adcVal);
                end
            end
        end
    end
catch ME
    disp('Logging stopped due to error.');
    clear esp
    rethrow(ME)
end

disp('Logging finished.');

% --- Save ---
if ~isempty(data)
    writematrix(data, filename);
    disp(['Data saved to ' filename ' (time,value)']);
else
    warning('No numeric data was recorded.');
end

clear esp;
