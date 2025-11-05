%% DC_Motor_Logger.m
% Rodrigo Ramos — HIL DC Motor Project
% Pair with "DC_Motor_SS" PlatformIO project
% -------------------------------------
% - Deletes old logs
% - Runs 5 PWM step tests on ESP32-S3
% - Saves simplified logs (no voltage columns)
% - Creates averaged merged log (DC_motor_log_M.csv)
% - Plots ω and I across all runs

clear; clc; fclose('all');

%% === 1. Delete old logs ===
oldLogs = dir('DC_motor_log_*.csv');
for k = 1:length(oldLogs)
    delete(fullfile(oldLogs(k).folder, oldLogs(k).name));
end
fprintf("Old DC_motor_log_*.csv files deleted.\n");

fprintf("=== DC_Motor_Logger ===\n");

%% === 2. Ask user for test parameters ===
Ts_ms    = input('Enter sampling time Ts [ms] (e.g., 2): ');
dur_s    = input('Enter test duration [s] (e.g., 5): ');
pwm_list = input('Enter 5 PWM step values (e.g., [10 30 50 70 90]): ');

if numel(pwm_list) ~= 5
    error('Please provide exactly 5 PWM values.');
end

%% === 3. Open serial connection ===
port = "COM13";    % adjust as needed
baud = 921600;     % must match ESP32 firmware
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

%% === 4. Run 5 tests sequentially ===
for k = 1:5
    pwm = pwm_list(k);
    fname = sprintf("DC_motor_log_%d.csv", k);

    if isfile(fname)
        delete(fname);
    end

    fprintf("\n---- Test %d of 5 | PWM = %d%% ----\n", k, pwm);
    cmd = sprintf("%d,%.3f,%d\n", Ts_ms, dur_s, pwm);
    write(s, cmd, "string");

    % Wait for test start
    while true
        if s.NumBytesAvailable > 0
            line = readline(s);
            if contains(line, "Starting test")
                fprintf("%s\n", line);
                break;
            end
        end
    end

    % Open file for writing simplified data
    fid = fopen(fname, 'w');
    fprintf(fid, "Ts_real_s,time_s,PWM_input,omega_rad_s,current_A,RPM\n");

    % Read CSV data until READY token
    t_prev = NaN;
    while true
        if s.NumBytesAvailable > 0
            line = strtrim(readline(s));

            if contains(line, "READY")
                break;
            elseif isempty(line) || contains(line, "t_s,") || contains(line, "Test complete")
                continue;
            end

            % Parse CSV from ESP32: t_s,duty_pct,Vbus,u_eff,current,omega,RPM
            vals = str2double(split(line, ','));
            if numel(vals) ~= 7
                continue;
            end
            t_s       = vals(1);
            pwm_input = vals(2);
            current_A = vals(5);
            omega_rad = vals(6);
            rpm       = vals(7);

            % Compute real Ts
            if isnan(t_prev)
                Ts_real = 0;
            else
                Ts_real = t_s - t_prev;
            end
            t_prev = t_s;

            fprintf(fid, "%.6f,%.6f,%.2f,%.6f,%.6f,%.3f\n", ...
                Ts_real, t_s, pwm_input, omega_rad, current_A, rpm);
        end
    end

    fclose(fid);
    fprintf("→ Saved %s\n", fname);
    pause(2.0); % 2-second pause between tests
end

clear s;
fprintf("\nAll 5 tests finished successfully.\n");

%% === 5. Merge and average logs ===
fprintf("Building averaged log (DC_motor_log_M.csv)...\n");

dataAll = [];
for k = 1:5
    fname = sprintf("DC_motor_log_%d.csv", k);
    tbl = readtable(fname);
    dataAll = [dataAll; tbl]; %#ok<AGROW>
end

% Determine unique time stamps (interpolate if needed)
t_unique = unique(dataAll.time_s);
omega_interp = zeros(size(t_unique));
curr_interp  = zeros(size(t_unique));
rpm_interp   = zeros(size(t_unique));

for k = 1:5
    fname = sprintf("DC_motor_log_%d.csv", k);
    tbl = readtable(fname);
    omega_interp = omega_interp + interp1(tbl.time_s, tbl.omega_rad_s, t_unique, 'linear', 'extrap');
    curr_interp  = curr_interp  + interp1(tbl.time_s, tbl.current_A,  t_unique, 'linear', 'extrap');
    rpm_interp   = rpm_interp   + interp1(tbl.time_s, tbl.RPM,        t_unique, 'linear', 'extrap');
end

omega_mean = omega_interp / 5;
curr_mean  = curr_interp  / 5;
rpm_mean   = rpm_interp   / 5;
Ts_mean    = mean(diff(t_unique));

T_M = table(...
    repmat(Ts_mean, numel(t_unique), 1), ...
    t_unique, ...
    mean(pwm_list)*ones(numel(t_unique),1), ...
    omega_mean, ...
    curr_mean, ...
    rpm_mean, ...
    'VariableNames', {'Ts_real_s','time_s','PWM_input','omega_rad_s','current_A','RPM'});

writetable(T_M, 'DC_motor_log_M.csv');
fprintf("→ Saved DC_motor_log_M.csv (averaged from all 5 tests)\n");

%% === 6. Plot results ===
fprintf("\nPlotting results...\n");

figure('Name','DC Motor Test Logs','NumberTitle','off','Position',[100 100 1000 600]);

% --- ω plot ---
subplot(2,1,1); hold on; grid on; box on;
for k = 1:5
    tbl = readtable(sprintf("DC_motor_log_%d.csv", k));
    plot(tbl.time_s, tbl.omega_rad_s, 'DisplayName', sprintf('Run %d (%d%% PWM)', k, pwm_list(k)));
end
plot(T_M.time_s, T_M.omega_rad_s, 'k', 'LineWidth', 2, 'DisplayName', 'Average');
title('Angular Velocity (rad/s)');
xlabel('Time [s]'); ylabel('\omega [rad/s]');
legend('show', 'Location', 'best');

% --- Current plot ---
subplot(2,1,2); hold on; grid on; box on;
for k = 1:5
    tbl = readtable(sprintf("DC_motor_log_%d.csv", k));
    plot(tbl.time_s, tbl.current_A, 'DisplayName', sprintf('Run %d (%d%% PWM)', k, pwm_list(k)));
end
plot(T_M.time_s, T_M.current_A, 'k', 'LineWidth', 2, 'DisplayName', 'Average');
title('Armature Current (A)');
xlabel('Time [s]'); ylabel('I_a [A]');
legend('show', 'Location', 'best');

fprintf("=== Logging and plotting complete ===\n");
