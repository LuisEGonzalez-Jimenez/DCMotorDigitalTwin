% HIL SIMULATION WITH DISCRETE CONTROLLER IN ESP32 BOARD
function Embedded_Discrete_Control_DC_Motor(tspan,x0)
  % Clear serial objects if exist
  if exist('esp','var')
    clear esp
  end
  % Connect to ESP32
  pkg load instrument-control; esp32 = serialport("COM5", 115200);
  % Clearing Serial Buffer
  for i = 1:10
    readline(esp32);  pause(0.1);
  end
  % Plant Definition
  R = 10; L = 10e-3; Kb = 0.2 ;Jm = 1e-2; Bm = 0.1; Kt = 0.2;
  A = [-R/L, -Kb/L; Kt/Jm, -Bm/Jm]; B = [1/L;0];  C = eye(2);
  T = 0.001;  Ad = eye(2)+A*T;      Bd = B*T;     Cd = C;    %FW EULER DISC.
  t = tspan(1):T:tspan(2);  num = length(t);  x = zeros(2,num);
  u = zeros(1,num); r = 5+2*sin(t);  x(:,1) = x0; disp("Starting simulation...");
  for k = 1:num-1
    % Sending Current Output
      % FOR PID CONTROL
    y = C(2,:)*x(:,k);                    writeline(esp32, num2str(y));
      % FOR BLOCK CONTROL
%    writeline(esp32, num2str(x(1,k)));    writeline(esp32, num2str(x(2,k)));
    % Reading Control Input
    u_str = readline(esp32);              u(k) = str2double(u_str);
    % Computing next state
    x(:,k+1) = Ad*x(:,k) + Bd*u(k);
  end
  clear esp % Closing Serial Port
 % PLOTTING STATES AND INPUT
  figure; subplot(2,1,1); stairs(t,x(1,:),"r");
          xlabel('Time [s]');   ylabel('x1 [A]');       grid;
          subplot(2,1,2); hold on; stairs(t,x(2,:),"r"); stairs(t,r,"k--");
          hold off; xlabel('Time [s]');   ylabel('x1 [rad/s]');   grid;
  figure; stairs(t,u,"r"); xlabel('Time [s]');   ylabel('u [V]');  grid;
end

##  r = 5+2*sin(t);

