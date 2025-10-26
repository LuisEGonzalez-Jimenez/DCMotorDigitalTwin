%% ===============================================================
%  Embedded_Discrete_Control_DC_Motor.m
%  HIL SIMULATION WITH DISCRETE CONTROLLER IN ESP32-S3 
%  Embedded_Discrete_Control_DC_Motor
%  --------------------------------------------------------------
%  Project : Hardware in the Loop Applied to a DC Motor
%  Author  : Rodrigo Ramos Romero 
%  Date    : 26/10/2025
%  ===============================================================

function Embedded_Discrete_Control_DC_Motor(tspan, x0)

  % --- Serial: clear any existing esp32 object (correct var name)
  if exist('esp32','var')
    clear esp32
  end

  % --- Connect to ESP32-S3 (adjust COM port if needed)
  esp32 = serialport("COM13", 115200);
  configureTerminator(esp32,"LF");
  flush(esp32);  % clear buffers

  % --- Clearing residual serial lines (warm-up)
  for i = 1:10
    try
      readline(esp32);
    catch
      % ignore if nothing to read
    end
    pause(0.01);
  end

  % --- Plant Definition (DC motor electrical + mechanical)
  R = 10;          % [Ohm]
  L = 10e-3;       % [H]
  Kb = 0.2;        % [V/(rad/s)]
  Kt = 0.2;        % [N*m/A]
  Jm = 1e-2;       % [kg*m^2]
  Bm = 0.1;        % [N*m*s/rad]

  A  = [-R/L,   -Kb/L;
         Kt/Jm, -Bm/Jm];
  B  = [1/L; 0];
  C  = eye(2);

  % --- Discretization (Forward Euler)
  T  = 0.001;                 % 1 kHz step (must match ESP loop)
  Ad = eye(2) + A*T;
  Bd = B*T;
  Cd = C; %#ok<NASGU>

  % --- Time & Initialization
  t   = tspan(1):T:tspan(2);
  num = length(t);
  x   = zeros(2, num);
  u   = zeros(1, num);
  x(:,1) = x0;

  % Reference shown on plot (match controller's r = 5.0 on ESP)
  r = 5*ones(1, num);

  % --- Output limits (match ESP — used only if you re-enable saturation)
  UMAX = 12;  UMIN = -12;

  disp("Starting simulation...");

  for k = 1:num-1
    % === Send current output (angular velocity) to ESP
    y = C(2,:)*x(:,k);  % x2 = angular speed [rad/s]
    writeline(esp32, sprintf('%.6f', y));

    % === Read control input from ESP
    u_str = readline(esp32);
    u_raw = str2double(u_str);
    if ~isfinite(u_raw)
      % fallback to last valid value if parse failed
      if k > 1
        u_raw = u(k-1);
      else
        u_raw = 0;
      end
    end

    % === Saturation (DISABLED FOR TUNING)
    % u(k) = max(min(u_raw, UMAX), UMIN);   % <-- uncomment to enforce ±12 V
    u(k) = u_raw;                            % no cap while tuning

    % === State update
    x(:,k+1) = Ad*x(:,k) + Bd*u(k);

    % (Optional debug)
    % if ~isfinite(u(k)), warning('u not finite at k=%d (raw="%s")', k, u_str); end
  end

  % --- Close serial port
  clear esp32

  % --- PLOTTING (blue lines)
  figure;
  subplot(2,1,1);
  stairs(t, x(1,:), "b");                 % current i(t)
  xlabel('Time [s]'); ylabel('x1 [A]'); grid on;

  subplot(2,1,2); hold on;
  stairs(t, x(2,:), "b");                 % angular velocity ω(t)
  stairs(t, r, "k--");                    % reference
  hold off;
  xlabel('Time [s]'); ylabel('x2 [rad/s]'); grid on;

  figure;
  stairs(t, u, "b");                      % input voltage u(t)
  xlabel('Time [s]'); ylabel('u [V]'); grid on;

end
