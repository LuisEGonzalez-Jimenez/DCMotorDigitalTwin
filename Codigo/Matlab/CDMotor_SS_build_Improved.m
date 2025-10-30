%% ===============================================================
%  CDMotor_SS_build_Improved.m
%  Merge 5 ESP32 tests and identify robust MIMO state-space model
%  ===============================================================

clear; clc; close all;

numFiles = 5;
dataCells = cell(1, numFiles);
Ts_values = zeros(1, numFiles);

fprintf('Loading 5 datasets:\n');
for k = 1:numFiles
    fname = sprintf('CD_Motor_%d.csv', k);
    if ~isfile(fname)
        error('Missing file: %s', fname);
    end
    fprintf('  %s\n', fname);
    T = readtable(fname);
    T = standardizeMissing(T, ["", "NaN"]);
    T = rmmissing(T);

    t = str2double(string(T.t_s));
    u = str2double(string(T.u_eff_V));
    omega = str2double(string(T.omega_rad_s));
    i = str2double(string(T.current_A));

    valid = all(~isnan([t u omega i]), 2);
    t = t(valid); u = u(valid); omega = omega(valid); i = i(valid);

    Ts = mean(diff(t(~isnan(t))));
    Ts_values(k) = Ts;

    dataCells{k} = iddata([omega i], u, Ts, ...
        'InputName', {'u_eff_V'}, ...
        'OutputName', {'omega_rad_s','current_A'}, ...
        'TimeUnit', 's');
end

fprintf('\nAverage detected Ts across datasets = %.5f s\n', mean(Ts_values));

%% === 2. Merge all datasets ===
data_all = dataCells{1};
for k = 2:numFiles
    data_all = merge(data_all, dataCells{k});
end

%% === 3. Estimate model ===
fprintf('\nEstimating robust continuous-time 2-state model...\n');
model_MIMO = ssest(data_all, 2, 'Ts', 0, ...
    'Feedthrough', false, 'DisturbanceModel', 'none', 'Focus', 'simulation');

%% === 4. Display and save ===
present(model_MIMO);
A = model_MIMO.A; B = model_MIMO.B; C = model_MIMO.C; D = model_MIMO.D;
Ts = mean(Ts_values);

save('CDMotor_SS_Model_Robust.mat', 'model_MIMO', 'A', 'B', 'C', 'D', 'Ts');
fprintf('\nModel saved to CDMotor_SS_Model_Robust.mat\n');

%% === 5. Log results to text ===
fid = fopen('SS_log_Improved.txt', 'w');
fprintf(fid, '=== CDMotor Robust SS Identification Log ===\n');
fprintf(fid, 'Generated on: %s\n\n', datestr(now));
fprintf(fid, 'Average Ts: %.6f s\n\n', Ts);

fprintf(fid, '--- A Matrix ---\n'); fprintf(fid, '%12.6f %12.6f\n', A');
fprintf(fid, '\n--- B Matrix ---\n'); fprintf(fid, '%12.6f\n', B);
fprintf(fid, '\n--- C Matrix ---\n'); fprintf(fid, '%12.6f %12.6f\n', C');
fprintf(fid, '\n--- D Matrix ---\n'); fprintf(fid, '%12.6f\n', D);

try
    fprintf(fid, '\n%s\n', evalc('present(model_MIMO)'));
catch
    fprintf(fid, '(present() summary unavailable)\n');
end
fclose(fid);

fprintf('Summary log saved to SS_log_Improved.txt\n');

%% === 6. Validate visually ===
figure('Name','Model Validation (Merged Data)');
compare(data_all, model_MIMO);
