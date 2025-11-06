%% DC_Motor_Log.m
% Rodrigo Ramos — HIL DC Motor Project (Transient Logger)
% Pair with "DC_Motor_SS" PlatformIO project
% ---------------------------------------------------------
% Logs one continuous 7-second experiment:
%  1 s idle  → 1 s step1 → 1 s idle → 1 s step2 → 1 s idle → 1 s step3 → 1 s idle
%
% Inputs: Ts_ms and 3 PWM step values
% Output: DC_motor_log.csv  (single continuous log)
% Columns: Ts_real_s,time_s,PWM_input,omega_rad_s,current_A,RPM
% ---------------------------------------------------------

clear; clc; fclose('all');

%% === 1. Delete old log ===
if isfile('DC_motor_log.csv')
    delete('DC_motor_log.csv');
end
fprintf("Old DC_motor_log.csv deleted.\n");

fprintf("=== DC_Motor_Log (Transient Test) ===\n");

%% === 2. Ask user for parameters ===
Ts_ms    = input('Enter sampling time Ts [ms] (e.g., 2): ');
pwm_list = input('Enter 3 PWM step values (e.g., [20 50 80]): ');

if numel(pwm_list) ~= 3
    error('Please provide exactly 3 PWM values.');
end

dur_s = 1.0;     % duration of each active PWM
pause_s = 1.0;   % standby time between each step
fprintf("Total test duration ≈ %.1f s\n", 7.0);

%% === 3. Open serial connection ===
port = "COM13";   % adjust if needed
baud = 921600;    % must match ESP32 firmware
s = serialport(port, baud, "Timeout", 20);
configureTerminator(s, "LF");

fprintf("Waiting for ESP32-S3...\n");
flush(s); pause(2);

% Wait for READY handshake
while s.NumBytesAvailable == 0
    pause(0.1);
end
line = readline(s);
while ~contains(line, "READY")
    line = readline(s);
end
fprintf("Connected. Board is READY.\n\n");

%% === 4. Prepare log ===
fid = fopen('DC_motor_log.csv', 'w');
fprintf(fid, "Ts_real_s,time_s,PWM_input,omega_rad_s,current_A,RPM\n");

t_prev = NaN;
t_offset = 0.0;

%% === 5. Define test sequence ===
% Sequence: [Idle] Step1 [Idle] Step2 [Idle] Step3 [Idle]
seq_pwms = [0, pwm_list(1), 0, pwm_list(2), 0, pwm_list(3), 0];
seq_names = ["Idle1","Step1","Idle2","Step2","Idle3","Step3","Idle4"];

%% === 6. Run sequence ===
for i = 1:length(seq_pwms)
    pwm = seq_pwms(i);
    fprintf("Running segment %d/%d: %s (%d%% PWM)\n", i, length(seq_pwms), seq_names(i), pwm);

    % Send command to ESP32
    cmd = sprintf("%d,%.3f,%d\n", Ts_ms, dur_s, pwm);
    write(s, cmd, "string");

    % Wait for test start
    while true
        if s.NumBytesAvailable > 0
            line = readline(s);
            if contains(line, "Starting test")
                break;
            end
        end
    end

    % Read until READY and log
    while true
        if s.NumBytesAvailable > 0
            line = strtrim(readline(s));

            if contains(line, "READY")
                break;
            elseif isempty(line) || contains(line, "t_s,") || contains(line, "Test complete")
                continue;
            end

            % Parse: t_s,duty_pct,Vbus,u_eff,current,omega,RPM
            vals = str2double(split(line, ','));
            if numel(vals) ~= 7
                continue;
            end
            t_s       = vals(1);
            pwm_input = vals(2);
            current_A = vals(5);
            omega_rad = vals(6);
            rpm       = vals(7);

            % Compute actual Ts
            if isnan(t_prev)
                Ts_real = 0;
            else
                Ts_real = t_s - t_prev;
            end
            t_prev = t_s;

            % Apply offset for continuous time axis
            time_global = t_s + t_offset;

            fprintf(fid, "%.6f,%.6f,%.2f,%.6f,%.6f,%.3f\n", ...
                Ts_real, time_global, pwm_input, omega_rad, current_A, rpm);
        end
    end

    % Update time offset
    t_offset = t_offset + dur_s;

    % Wait the 1-second standby before next PWM
    if i < length(seq_pwms)
        pause(pause_s);
    end
end

fclose(fid);
clear s;
fprintf("\n→ Saved DC_motor_log.csv (complete 7-second transient)\n");

%% === 7. Plot results ===
fprintf("Plotting results...\n");
tbl = readtable('DC_motor_log.csv');

figure('Name','DC Motor Transient Log','NumberTitle','off','Position',[100 100 1000 600]);

subplot(3,1,1); hold on; grid on; box on;
plot(tbl.time_s, tbl.PWM_input, 'k', 'LineWidth', 1.5);
title('PWM Input (%)');
ylabel('PWM [%]');
xlim([0 max(tbl.time_s)]);

subplot(3,1,2); hold on; grid on; box on;
plot(tbl.time_s, tbl.omega_rad_s, 'b');
title('Angular Velocity \omega(t)');
ylabel('\omega [rad/s]');
xlim([0 max(tbl.time_s)]);

subplot(3,1,3); hold on; grid on; box on;
plot(tbl.time_s, tbl.current_A, 'r');
title('Armature Current i_a(t)');
xlabel('Time [s]');
ylabel('I_A [A]');
xlim([0 max(tbl.time_s)]);

sgtitle('DC Motor Transient Test — 3 Step Sequence');

fprintf("=== Logging and plotting complete ===\n");
