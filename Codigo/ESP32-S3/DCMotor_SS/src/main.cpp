#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_INA219.h>

const int PIN_PWMA = 9;
const int PIN_AIN1 = 10;
const int PIN_AIN2 = 11;
const int PIN_STBY = 12;
const int PIN_SDA  = 6;
const int PIN_SCL  = 7;
const int ENC_A    = 4;
const int ENC_B    = 5;

Adafruit_INA219 ina219;
volatile long encoder_count = 0;
float rpm = 0.0;

int Ts_ms = 100;          // default sample period (ms)
float test_duration_s = 2.0;
int pwm_percent = 50;

void tb6612_forward() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, LOW); }
void tb6612_brake()   { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, HIGH); }
void tb6612_coast()   { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, LOW); }

void IRAM_ATTR encoderISR() {
  int B = digitalRead(ENC_B);
  if (B == HIGH) encoder_count++;
  else encoder_count--;
}

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("=== ESP32-S3 DCMotor_SS Ready ===");
  Serial.println("READY");  // MATLAB waits for this exact token

  Wire.begin(PIN_SDA, PIN_SCL);
  if (!ina219.begin()) {
    Serial.println("INA219 not found! Check wiring.");
    while (true) delay(10);
  }

  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  pinMode(PIN_STBY, OUTPUT);
  digitalWrite(PIN_STBY, HIGH);
  tb6612_coast();

  pinMode(ENC_A, INPUT_PULLUP);
  pinMode(ENC_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENC_A), encoderISR, RISING);

  // PWM setup
  ledcSetup(0, 20000, 10);
  ledcAttachPin(PIN_PWMA, 0);
  ledcWrite(0, 0);
}

void loop() {
  // Wait for command from MATLAB
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');
    input.trim();
    if (input.length() == 0) return;

    int firstComma = input.indexOf(',');
    int secondComma = input.indexOf(',', firstComma + 1);

    Ts_ms          = input.substring(0, firstComma).toInt();
    test_duration_s = input.substring(firstComma + 1, secondComma).toFloat();
    pwm_percent    = input.substring(secondComma + 1).toInt();

    // Determine sign and magnitude
    bool reverse = (pwm_percent < 0);
    int pwm_mag = abs(pwm_percent);
    if (pwm_mag > 100) pwm_mag = 100;
    int duty = map(pwm_mag, 0, 100, 0, 1023);

    Serial.printf("Starting test: Ts=%d ms, Duration=%.2f s, PWM=%d%% (duty=%d) [%s]\n",
                  Ts_ms, test_duration_s, pwm_percent, duty, reverse ? "REVERSE" : "FORWARD");
    Serial.println("t_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM");

    // Set direction
    if (reverse) {
      digitalWrite(PIN_AIN1, LOW);
      digitalWrite(PIN_AIN2, HIGH);
    } else {
      digitalWrite(PIN_AIN1, HIGH);
      digitalWrite(PIN_AIN2, LOW);
    }

    // Enable PWM output
    ledcWrite(0, duty);

    encoder_count = 0;

    unsigned long testStart = millis();
    unsigned long lastSample = testStart;
    const int PPR = 330;

    while (millis() - testStart < (unsigned long)(test_duration_s * 1000.0)) {
      unsigned long now = millis();
      if (now - lastSample >= Ts_ms) {
        noInterrupts();
        long counts = encoder_count;
        encoder_count = 0;
        interrupts();

        float revs = (float)counts / (float)PPR;
        float revs_per_sec = revs / (Ts_ms / 1000.0f);
        rpm = revs_per_sec * 60.0f;
        float omega = rpm * (2.0f * PI / 60.0f);

        float bus_V = ina219.getBusVoltage_V();
        float current_A = ina219.getCurrent_mA() / 1000.0f;
        float duty_frac = duty / 1023.0f;
        float u_eff = duty_frac * bus_V;
        float t_s = (now - testStart) / 1000.0f;

        Serial.printf("%.3f,%.1f,%.3f,%.3f,%.6f,%.4f,%.2f\n",
                      t_s, pwm_percent*1.0f, bus_V, u_eff, current_A, omega, rpm);

        lastSample = now;
      }
    }

    ledcWrite(0, 0);
    tb6612_brake();
    Serial.println("Test complete.");
    Serial.println("READY"); // signal MATLAB that it's ready for next run
  }
}
