%% HIL PID Current Controller (MATLAB side)
% MATLAB controls armature current (i_ref)
% ESP32-S3 emulates DC motor plant (binary protocol)

function HIL_PID_CurrentControl_to_ESP32S3()
    % === Serial setup ===
    port = "COM13";             % <-- adjust to your ESP32-S3 port
    baud = 230400;
    T = 0.001;                  % 1 ms sample
    duration = 5;               % seconds
    N = duration / T;

    if exist('esp32','var'), clear esp32; end
    esp32 = serialport(port, baud);
    flush(esp32);
    pause(0.3);

    % === PID gains (for current loop, usually higher bandwidth) ===
    Kp = 10.0;
    Ki = 0.0;
    Kd = 0.0;

    % === Reference current [A] ===
    i_ref = 1.0;   % step reference

    % === Buffers ===
    t = (0:N-1)' * T;
    w = zeros(N,1);
    i = zeros(N,1);
    u = zeros(N,1);
    e = zeros(N,1);
    int_e = 0;
    prev_e = 0;

    syncByte = uint8(170); % 0xAA

    fprintf("Starting Current Control HIL test...\n");

    tic;
    for k = 1:N
        % --- PID current control ---
        e(k) = i_ref - i(max(k-1,1));
        int_e = int_e + e(k) * T;
        der_e = (e(k) - prev_e) / T;
        prev_e = e(k);
        u(k) = Kp * e(k) + Ki * int_e + Kd * der_e;

        % --- Send control voltage u ---
        write(esp32, syncByte, "uint8");
        write(esp32, single(u(k)), "single");

        % --- Read plant feedback ---
        t0 = tic;
        while esp32.NumBytesAvailable < 9
            if toc(t0) > 0.02, break; end
        end
        if esp32.NumBytesAvailable >= 9
            sync = read(esp32, 1, "uint8");
            if sync == 170
                data = read(esp32, 2, "single");
                w(k) = data(1);
                i(k) = data(2);
            end
        elseif k > 1
            w(k) = w(k-1);
            i(k) = i(k-1);
        end

        while toc < k*T, end
        if k <= 5
            fprintf("k=%d | u=%.3f | i=%.4f | w=%.4f\n", k, u(k), i(k), w(k));
        end
    end
    elapsed = toc;
    fprintf("Simulation done in %.2f s\n", elapsed);
    clear esp32;

    % === Plot results ===
    figure('Name','HIL DC Motor - Current Control');
    subplot(3,1,1);
    plot(t, i, 'm', 'LineWidth', 1.3); hold on;
    yline(i_ref, '--r', 'i_{ref}');
    ylabel('Current [A]');
    title('HIL DC Motor: MATLAB Current PID → ESP32-S3 Plant');
    grid on;

    subplot(3,1,2);
    plot(t, u, 'k', 'LineWidth', 1.3);
    ylabel('Control u [V]');
    grid on;

    subplot(3,1,3);
    plot(t, w, 'b', 'LineWidth', 1.3);
    ylabel('\omega [rad/s]');
    xlabel('Time [s]');
    grid on;
end
