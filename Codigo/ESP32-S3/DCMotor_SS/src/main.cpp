/******************************************************************
* Project
	Hardware in the Loop applied to a DC Motor
* File
	CD Motor State Space Logger
* Description
	Logs values captured using the ESP32-S3, TB6612 motor bridge and 
	INA219 DC sensor for matlab processing using PWM input from
	0-100%. Pair with MATLAB DC_Motor_Logger.m 
  To save TS (real), Time, PWM input, Angular velocity, Armature
  current and RPM.
* Author:
	Ramos Romero Rodrigo
* Date:
	26/10/2025
*TODO:
	
******************************************************************/


#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_INA219.h>
#include <ESP32Encoder.h>

// ===================== PINOUT (your working wiring) =====================
static const int PIN_PWMA = 9;
static const int PIN_AIN1 = 10;
static const int PIN_AIN2 = 11;
static const int PIN_STBY = 12;

static const int PIN_SDA  = 6;   // INA219 I2C
static const int PIN_SCL  = 7;

static const int ENC_A    = 17;  // quadrature A
static const int ENC_B    = 18;  // quadrature B

// ===================== PWM CONFIG =====================
static const int  PWM_CH   = 0;
static const int  PWM_RES  = 10;        // 10-bit (0..1023)
static const int  PWM_FREQ = 20000;     // 20 kHz (quiet)

// ===================== ENCODER + MODEL CONSTANTS =====================
ESP32Encoder enc;
static const float TICKS_PER_REV = 1025.0f;  // <-- your calibrated value

// ===================== INA219 =====================
Adafruit_INA219 ina219;

// ===================== LOGGING BUFFER =====================
// CSV schema: t_s, duty_pct, Vbus_V, u_eff_V, current_A, omega_rad_s, RPM
struct Sample {
  float t_s;
  float duty_pct;
  float vbus_V;
  float u_eff_V;
  float current_A;
  float omega_rad_s;
  float rpm;
};

// Max buffer size (e.g., 2 ms over 10 s ~ 5000; we provision 8000)
static const size_t MAX_SAMPLES = 8000;
static Sample *logBuf = nullptr;

// ===================== HELPERS =====================
static inline void tb6612_forward() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, LOW); }
static inline void tb6612_reverse() { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, HIGH); }
static inline void tb6612_brake()   { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, HIGH); }
static inline void tb6612_coast()   { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, LOW); }

// ===================== SETUP =====================
void setup() {
  Serial.begin(921600);
  delay(500);

  // Power + driver pins
  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  pinMode(PIN_STBY, OUTPUT);
  digitalWrite(PIN_STBY, HIGH);
  tb6612_coast();

  // PWM
  ledcSetup(PWM_CH, PWM_FREQ, PWM_RES);
  ledcAttachPin(PIN_PWMA, PWM_CH);
  ledcWrite(PWM_CH, 0);

  // I2C fast
  Wire.begin(PIN_SDA, PIN_SCL);
  Wire.setClock(400000); // 400 kHz (safe, reliable)
  if (!ina219.begin()) {
    Serial.println("INA219 not found! Check wiring.");
    while (true) delay(10);
  }
  // (Adafruit INA219 doesn't expose per-sample ADC mode cleanly; 400kHz I2C + simpler calls keeps us fast.)

  // Encoder (hardware PCNT full-quad + filter)
  pinMode(ENC_A, INPUT_PULLUP);
  pinMode(ENC_B, INPUT_PULLUP);
  ESP32Encoder::useInternalWeakPullResistors = UP;
  enc.attachFullQuad(ENC_A, ENC_B);
  enc.setFilter(120); // adjust 80..200 if needed
  enc.setCount(0);

  // Log buffer
  logBuf = (Sample*)malloc(sizeof(Sample) * MAX_SAMPLES);

  Serial.println();
  Serial.println("=== TB6612 + INA219 + Encoder CSV Fast Logger ===");
  Serial.println("READY"); // MATLAB waits on this token
}

// ===================== MAIN =====================
void loop() {
  // Command format from MATLAB (or terminal): "Ts_ms,duration_s,pwm_percent\n"
  if (!Serial.available()) return;
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line.length() == 0) return;

  // Parse CSV
  int c1 = line.indexOf(',');
  int c2 = line.indexOf(',', c1 + 1);
  if (c1 < 0 || c2 < 0) return;

  int   Ts_ms    = line.substring(0, c1).toInt();
  float dur_s    = line.substring(c1 + 1, c2).toFloat();
  int   pwm_pct  = line.substring(c2 + 1).toInt();

  // Boundaries
  if (Ts_ms < 1) Ts_ms = 1;
  if (dur_s <= 0) dur_s = 2.0f;
  if (pwm_pct > 100) pwm_pct = 100;
  if (pwm_pct < -100) pwm_pct = -100;

  const bool reverse = (pwm_pct < 0);
  const int  mag     = abs(pwm_pct);
  const int  duty    = (int)round((mag / 100.0f) * ((1 << PWM_RES) - 1));

  // Compute max samples & clip to buffer
  const uint32_t dur_ms = (uint32_t)lroundf(dur_s * 1000.0f);
  const size_t   need   = (size_t)((dur_ms + Ts_ms - 1) / Ts_ms);
  const size_t   cap    = (need < MAX_SAMPLES) ? need : MAX_SAMPLES;

  // Start test
  Serial.printf("Starting test: Ts=%d ms, Dur=%.2f s, PWM=%d%% (duty=%d)\n",
                Ts_ms, dur_s, pwm_pct, duty);
  Serial.println("t_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM");

  // Prepare
  enc.setCount(0);
  long long prevTicks = 0;

  // Enable motor
  digitalWrite(PIN_STBY, HIGH);
  delay(5);
  if (reverse) tb6612_reverse(); else tb6612_forward();
  ledcWrite(PWM_CH, duty);

  // Timing loop (no Serial prints here)
  const uint32_t t0_ms = millis();
  const uint64_t t0_us = micros();
  uint64_t next_us = t0_us;
  size_t idx = 0;

  while ((millis() - t0_ms) < dur_ms && idx < cap) {
    // Wait until next sample time
    next_us += (uint64_t)Ts_ms * 1000ULL;
    while ((long)(micros() - next_us) < 0) {
      // busy-wait small time slice (short Ts); yields most accurate Ts
      // optional: delayMicroseconds(50);
    }

    // Snapshot time (actual)
    const float t_s = (float)(micros() - t0_us) * 1e-6f;

    // Read encoder (delta ticks)
    long long nowTicks = enc.getCount();
    long long dTicks   = nowTicks - prevTicks;
    prevTicks = nowTicks;

    // Compute speed
    const float revs   = (float)dTicks / TICKS_PER_REV;
    const float Ts_s   = (float)Ts_ms / 1000.0f; // nominal Ts (used for u_eff scaling), ω uses actual t_s via delta ticks
    const float revps  = revs / Ts_s;            // this uses nominal Ts for speed
    const float rpm    = revps * 60.0f;
    const float omega  = rpm * (2.0f * PI / 60.0f);

    // INA219 readings
    const float vbus   = ina219.getBusVoltage_V();
    const float current_A = ina219.getCurrent_mA() * 0.001f;

    // Effective drive estimate
    const float duty_frac = duty / (float)((1 << PWM_RES) - 1);
    const float u_eff = duty_frac * vbus;

    // Store in RAM buffer
    logBuf[idx++] = Sample{ t_s, (float)pwm_pct, vbus, u_eff, current_A, omega, rpm };
  }

  // Stop motor
  ledcWrite(PWM_CH, 0);
  tb6612_brake();
  delay(50);
  digitalWrite(PIN_STBY, LOW);

  // Dump CSV
  for (size_t i = 0; i < idx; ++i) {
    const Sample &s = logBuf[i];
    Serial.printf("%.6f,%.1f,%.3f,%.3f,%.6f,%.6f,%.3f\n",
                  s.t_s, s.duty_pct, s.vbus_V, s.u_eff_V, s.current_A, s.omega_rad_s, s.rpm);
  }

  Serial.println("Test complete.");
  Serial.println("READY"); // signal ready for next command
}
