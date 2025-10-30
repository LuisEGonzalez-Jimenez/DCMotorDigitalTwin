%% ===============================================================
%  CDMotor_SS_Control_Improved.m
%  Runs 5 automatic PWM step tests via ESP32-S3
%  Each run saved as CD_Motor_#.csv
%  Includes 2 s delay between tests for motor safety
%  ===============================================================

clear; clc;

%% === 1. Get user parameters ===
Ts_ms       = input('Enter sample period Ts (ms): ');
step_time_s = input('Enter step test duration (s): ');
fprintf('\nEnter 5 PWM step values (e.g., [10 30 50 70 90]):\n');
pwm_list    = input('PWM steps = ');

if numel(pwm_list) ~= 5
    error('Please enter exactly 5 PWM values.');
end

fprintf('\nTest configuration:\n');
fprintf('Ts = %g ms | Duration = %g s | PWM = [%s]\n', Ts_ms, step_time_s, num2str(pwm_list));

%% === 2. Connect to ESP32 ===
port = "COM13";   % adjust to your COM port
baud = 115200;
esp = serialport(port, baud);
configureTerminator(esp, "LF");
flush(esp);
fprintf('\nWaiting for ESP32 READY...\n');

%% Wait for READY
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

%% === 3. Run 5 tests ===
for k = 1:5
    pwm = pwm_list(k);
    logName = sprintf('CD_Motor_%d.csv', k);

    % delete previous version
    if isfile(logName)
        delete(logName);
    end

    fprintf('\n=== Running test %d/5: PWM = %d%% ===\n', k, pwm);

    % Send command to ESP32
    cmd = sprintf("%d,%d,%d\n", Ts_ms, step_time_s, pwm);
    writeline(esp, cmd);

    fid = fopen(logName, 'w');
    fprintf(fid, 't_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM\n');

    % Read until "Test complete"
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
    fprintf('Saved to %s\n', logName);

    % === New: wait 2 seconds between tests ===
    fprintf('Cooling... waiting 2 seconds before next test.\n');
    pause(2.0);

    % Wait for next READY signal
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
end

clear esp;
fprintf('\nAll 5 tests completed.\n');

%% === 4. Optionally run builder ===
reply = input('Run System Identification build now? (y/n): ', 's');
if strcmpi(reply, 'y')
    CDMotor_SS_build_Improved;
end
