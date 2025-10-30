%% ===============================================================
%  CDMotor_SS_build.m
%  Build MIMO State-Space model of a DC motor from logged data
%  --------------------------------------------------------------
%  Project : Hardware in the Loop Applied to a DC Motor
%  Author  : Rodrigo Ramos Romero 
%  Date    : 26/10/2025
%  --------------------------------------------------------------
%  Inputs  : u_eff_V (applied motor voltage)
%  Outputs : omega_rad_s (angular velocity, rad/s)
%             current_A   (armature current, A)
%  File    : run_50pct.csv  (or any CSV from the ESP32_S3 SS Build)
%  ===============================================================


clear; clc; close all;

%% === 1. Load CSV file ===
%  Adjust filename as needed (e.g., run_30pct.csv, run_70pct.csv)
fname = 'CD_Motor_data.csv';
fprintf('Loading data from %s ...\n', fname);
T = readtable(fname);

% Verify contents
disp('First few rows of the dataset:');
disp(head(T));

%% === 2. Extract signals ===
% Clean up: ensure all columns are numeric
T = standardizeMissing(T, ["", "NaN"]);
T = rmmissing(T);

t = str2double(string(T.t_s));            % force numeric
u = str2double(string(T.u_eff_V));
omega = str2double(string(T.omega_rad_s));
i = str2double(string(T.current_A));

% Remove any NaN rows
valid = all(~isnan([t u omega i]),2);
t = t(valid); u = u(valid); omega = omega(valid); i = i(valid);

% Compute sample time safely
if numel(t) > 1
    Ts = mean(diff(t(~isnan(t))));
else
    Ts = [];
end

fprintf('Detected sample time Ts = %.4f s\n', Ts);

%% === 3. Create MIMO iddata object ===
% Inputs: 1 (voltage)
% Outputs: 2 (omega, i)
y = [omega i];
data = iddata(y, u, Ts, ...
    'InputName', {'u_eff_V'}, ...
    'OutputName', {'omega_rad_s', 'current_A'}, ...
    'TimeUnit', 's');

%% === 4. Plot raw signals ===
figure('Name','Measured Signals');
subplot(3,1,1);
plot(t, u, 'LineWidth',1.2); grid on;
ylabel('Voltage (V)');
title('Input: Effective Motor Voltage');

subplot(3,1,2);
plot(t, omega, 'LineWidth',1.2); grid on;
ylabel('\omega (rad/s)');
title('Output 1: Angular Velocity');

subplot(3,1,3);
plot(t, i, 'LineWidth',1.2); grid on;
ylabel('Current (A)');
xlabel('Time (s)');
title('Output 2: Armature Current');

%% === 5. Estimate 2-state continuous-time model ===
% Order 2 → expected states [i; ω]
fprintf('\nEstimating continuous-time MIMO state-space model...\n');
model_MIMO = ssest(data, 2, 'Ts', 0);  % Ts=0 → continuous time

%% === 6. Display identified matrices ===
disp('=== Identified Continuous-Time Model ===');
present(model_MIMO);

A = model_MIMO.A;
B = model_MIMO.B;
C = model_MIMO.C;
D = model_MIMO.D;

fprintf('\nA = \n'); disp(A);
fprintf('B = \n'); disp(B);
fprintf('C = \n'); disp(C);
fprintf('D = \n'); disp(D);

%% === 7. Compare simulated vs measured outputs ===
figure('Name','Model Validation');
compare(data, model_MIMO);

%% === 8. Optional: Export model for reuse ===
save('CDMotor_SS_Model.mat', 'model_MIMO', 'A', 'B', 'C', 'D', 'Ts');
fprintf('\nModel saved to CDMotor_SS_Model.mat\n');

%% === 9. Write summary log to text file ===
logFile = 'SS_log.txt';
fid = fopen(logFile, 'w');

fprintf(fid, '=== CDMotor State-Space Identification Log ===\n');
fprintf(fid, 'Generated on: %s\n\n', datestr(now));

fprintf(fid, 'Sample time (Ts): %.6f s\n\n', Ts);

fprintf(fid, '--- A Matrix ---\n');
fprintf(fid, '%12.6f %12.6f\n', A');
fprintf(fid, '\n--- B Matrix ---\n');
fprintf(fid, '%12.6f\n', B);
fprintf(fid, '\n--- C Matrix ---\n');
fprintf(fid, '%12.6f %12.6f\n', C');
fprintf(fid, '\n--- D Matrix ---\n');
fprintf(fid, '%12.6f\n', D);

fprintf(fid, '\nModel summary:\n');
try
    fprintf(fid, '%s\n', evalc('present(model_MIMO)'));
catch
    fprintf(fid, '(present() summary unavailable)\n');
end

fclose(fid);
fprintf('Text log saved to %s\n', logFile);

