%% HIL PID Current Controller (MATLAB side)
% MATLAB controls armature current (w_ref)
% ESP32-S3 emulates DC motor plant (binary protocol)

function HIL_PID_Controller_to_ESP32S3()
    port = "COM13"; baud = 230400;
    T = 0.001; duration = 5; N = duration / T;

    if exist('esp32', 'var'), clear esp32; end
    esp32 = serialport(port, baud);
    flush(esp32);
    pause(0.3);

    % PID gains
    Kp = 10.0; 
    Ki = 0.0; 
    Kd = 0.00;
    w_ref = 5.0;

    t = (0:N-1)' * T; w = zeros(N,1); i = zeros(N,1);
    u = zeros(N,1); e = zeros(N,1); int_e = 0; prev_e = 0;

    syncByte = uint8(170); % 0xAA
    fprintf("Starting run...\n");

    tic;
    for k = 1:N
        % PID
        e(k) = w_ref - w(max(k-1,1));
        int_e = int_e + e(k)*T;
        der_e = (e(k) - prev_e)/T; prev_e = e(k);
        u(k) = Kp*e(k) + Ki*int_e + Kd*der_e;

        % SEND frame: [0xAA][float u]
        write(esp32, syncByte, "uint8");
        write(esp32, single(u(k)), "single");

        % READ frame: expect [0xAA][float w][float i]
        % Wait until at least 9 bytes available
        t0 = tic;
        while esp32.NumBytesAvailable < 9
            if toc(t0) > 0.02, break; end
        end

        if esp32.NumBytesAvailable >= 9
            % Look for sync 0xAA
            sync = read(esp32, 1, "uint8");
            if sync == 170
                data = read(esp32, 2, "single");
                w(k) = data(1);
                i(k) = data(2);
            end
        elseif k > 1
            w(k) = w(k-1); i(k) = i(k-1);
        end

        while toc < k*T, end
        if k <= 5
            fprintf("k=%d | u=%.3f | w=%.4f | i=%.4f\n", k,u(k),w(k),i(k));
        end
    end
    elapsed = toc; fprintf("Simulation done in %.2f s\n", elapsed);
    clear esp32;

    figure('Name','HIL DC Motor');
    subplot(3,1,1); plot(t,w,'b','LineWidth',1.3); hold on;
    yline(w_ref,'--r','Ref'); ylabel('\omega [rad/s]'); grid on;
    subplot(3,1,2); plot(t,i,'m','LineWidth',1.3); ylabel('Current [A]'); grid on;
    subplot(3,1,3); plot(t,u,'k','LineWidth',1.3); ylabel('u [V]'); xlabel('Time [s]'); grid on;
end
