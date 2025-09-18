%% If you are not getting data, After running the file >>ESP32_S3_Logger.m press reset on the ESP to properly save values

%% --- ESP32 S3 Logger with CSV Output ---
clear; clc;

% --- User settings ---
port = "COM13";        % change to your ESP32 COM port
baudRate = 115200;     
logDuration = 5;      % seconds
%samplePeriod = 0.01;    % seconds between samples (10 ms)
samplePeriod = 0.001;  % 1 ms per sample
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
data = [];
t0 = tic;

try
    while toc(t0) < logDuration
        if esp.NumBytesAvailable > 0
            line = readline(esp);           
            value = str2double(line);       

            if isnan(value)
                fprintf('Ignored non-numeric line: %s\n', line);
            else
                data(end+1,1) = value;       %#ok<SAGROW>
                elapsed = toc(t0);
                fprintf('t=%.2fs, value=%d\n', elapsed, value);
            end
        end
        pause(samplePeriod);   % control sampling interval
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
    disp(['Data saved to ' filename]);
else
    warning('No numeric data was recorded.');
end

% --- Cleanup ---
clear esp;
