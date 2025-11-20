%% CDMotor_SS_Build.m
% Build MIMO state-space model from filtered data
% Rodrigo Ramos — 2025
% -------------------------------------------------------------
% Pipeline version:
%   - Expects Mimo_SS_input, Mimo_SS_output, and Ts in workspace
%   - Builds iddata object and runs ssest (continuous-time)
%   - Saves model and report
% -------------------------------------------------------------

clc; close all;

fprintf("=== CDMotor_SS_Build ===\n");
fprintf("This script expects the following variables in workspace:\n");
fprintf("    Mimo_SS_input   -> filtered input signal (voltage)\n");
fprintf("    Mimo_SS_output  -> filtered output signals [I_filt, w_filt]\n");
fprintf("    Ts              -> sampling time (seconds)\n\n");


%% === 1. Validate required variables ===
if ~exist('Mimo_SS_input', 'var')
    error("Missing variable: Mimo_SS_input");
end
if ~exist('Mimo_SS_output', 'var')
    error("Missing variable: Mimo_SS_output");
end
if ~exist('Ts', 'var')
    error("Missing variable: Ts");
end

fprintf("Variables validated successfully.\n\n");


%% === 2. Build identification dataset ===
fprintf("Creating iddata object...\n");

u = Mimo_SS_input(:);     % column vector
y = Mimo_SS_output;       % Nx2 matrix: [I_filt, w_filt]

data = iddata(y, u, Ts);  % discrete dataset with correct Ts

fprintf("  Samples: %d\n", length(u));
fprintf("  Inputs : 1 (Voltage)\n");
fprintf("  Outputs: 2 (Current, Omega)\n");
fprintf("  Ts     : %.6f s\n\n", Ts);


%% === 3. Estimate state-space model ===
fprintf("Estimating continuous-time state-space model...\n");

% Using 2 states: matches DC motor (current + speed dynamics)
model_MIMO = ssest(data, 2, 'Ts', 0);   % 0 → continuous-time model

%% === 4. Extract matrices ===
[A, B, C, D] = ssdata(model_MIMO);

fprintf("\n=== Identified State-Space Model ===\n");
disp(A);
disp(B);
disp(C);
disp(D);


%% === 5. Fit quality ===
disp(' ');
disp("=== Fit Percentages ===");
disp(model_MIMO.Report.Fit.FitPercent);
fprintf("FPE: %.6g\n", model_MIMO.Report.Fit.FPE);


%% === 6. Save model ===
fprintf("Saving model to CDMotor_SS_Model.mat...\n");
save('CDMotor_SS_Model.mat', 'model_MIMO', 'A', 'B', 'C', 'D', 'Ts');

%% === 7. Export human-readable log ===
fid = fopen('SS_log.txt', 'w');
fprintf(fid, "=== CDMotor_SS_Build Pipeline Log ===\n");
fprintf(fid, "Date: %s\n\n", datestr(now));
fprintf(fid, "Ts (s): %.6f\n\n", Ts);

fprintf(fid, "A = \n"); fprintf(fid, "%g ", A); fprintf(fid, "\n\n");
fprintf(fid, "B = \n"); fprintf(fid, "%g ", B); fprintf(fid, "\n\n");
fprintf(fid, "C = \n"); fprintf(fid, "%g ", C); fprintf(fid, "\n\n");
fprintf(fid, "D = \n"); fprintf(fid, "%g ", D); fprintf(fid, "\n\n");

fprintf(fid, "Fit Percentages:\n");
disp_vals = model_MIMO.Report.Fit.FitPercent;
fprintf(fid, "%s\n\n", mat2str(disp_vals));

fprintf(fid, "FPE: %.6g\n", model_MIMO.Report.Fit.FPE);
fclose(fid);
fprintf("Summary saved to SS_log.txt\n");

%% === 8. Optional validation ===
figure;
compare(data, model_MIMO);
title('Model vs. Measured Signals (Filtered Current & Omega)');
