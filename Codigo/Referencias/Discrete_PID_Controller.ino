// Discrete PID Controller for an Octave Dynamical Model
double y, u, uP, uI, uD, e, ekm1, uIkm1, r, Kp, Ki, Kd, T;
String y_s;

void setup() {
  Serial.begin(115200);
  Kp = 0;  Ki = 0;  Kd = 0;
  r = 5;   ekm1 = 0; uIkm1 = 0;  T = 0.001;
}

void loop() {
  // Check if Octave Sent Current Output
  if (Serial.available()) {
    // Reading Current Output
    y_s = Serial.readStringUntil('\n');
    y = y_s.toDouble();
    // Computing Control Input
    e = r - y;
    uP = Kp*e;
    uI = Ki*T*ekm1 + uIkm1;
    uD = Kd*(e - ekm1)/T;
    u = uP + uI + uD;
    Serial.println(u);
    // Defining Recursive Terms
    ekm1 = e;
    uIkm1 = uI;
    delay(1);
  }
}

