/******************************************************************
* Project:
    Hardware in the Loop applied to a DC Motor
* File:
    DCMotor_Matlab_log (Corrected 3-step sequence version)
* Description:
    Logs values using ESP32-S3, TB6612 driver, INA219 current sensor,
    and quadrature encoder. Designed for MATLAB pipeline:
        CDMotor_SS_Log.m → Log_filtering.m → CDMotor_SS_Build.m
* Author:
    Ramos Romero Rodrigo
* Updated:
    20/11/2025 for 3-step sequence with global timestamps
******************************************************************/

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_INA219.h>
#include <ESP32Encoder.h>

// ===================== PINOUT =====================
static const int PIN_PWMA = 9;
static const int PIN_AIN1 = 10;
static const int PIN_AIN2 = 11;
static const int PIN_STBY = 12;

static const int PIN_SDA  = 6;
static const int PIN_SCL  = 7;

static const int ENC_A    = 17;
static const int ENC_B    = 18;

// ===================== PWM CONFIG =====================
static const int PWM_CH   = 0;
static const int PWM_RES  = 10;        // 10-bit resolution
static const int PWM_FREQ = 20000;     // 20 kHz

// ===================== CONSTANTS =====================
ESP32Encoder enc;
static const float TICKS_PER_REV = 1025.0f;

// INA219
Adafruit_INA219 ina219;

// Global timestamp for ENTIRE sequence
static uint64_t sequenceStart_us = 0;


// ===================== DRIVER HELPERS =====================
static inline void tb6612_forward() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, LOW); }
static inline void tb6612_reverse() { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, HIGH); }
static inline void tb6612_brake()   { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, HIGH); }
static inline void tb6612_coast()   { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, LOW); }


// ===================== RUN ONE SEGMENT =====================
void runSegment(int Ts_ms, int duration_ms, int pwm_pct)
{
    bool reverse = (pwm_pct < 0);
    int mag      = abs(pwm_pct);
    int duty     = (int)round((mag / 100.0f) * ((1 << PWM_RES) - 1));

    enc.setCount(0);
    long long prevTicks = 0;

    // Start motor
    digitalWrite(PIN_STBY, HIGH);
    delay(5);

    if      (mag == 0)  tb6612_coast();
    else if (reverse)   tb6612_reverse();
    else                tb6612_forward();

    ledcWrite(PWM_CH, duty);

    // ==== FIX: local segment start time ====
    uint64_t segmentStart_us = micros();
    uint64_t next_us = segmentStart_us;

    while ((micros() - segmentStart_us) < (uint64_t)duration_ms * 1000ULL) {

        // accurate sampling
        next_us += (uint64_t)Ts_ms * 1000ULL;
        while ((long)(micros() - next_us) < 0) {}

        // ==== CORRECT GLOBAL TIMESTAMP for CSV ====
        float t_s = (float)(micros() - sequenceStart_us) * 1e-6f;

        // Read encoder
        long long nowTicks = enc.getCount();
        long long dTicks   = nowTicks - prevTicks;
        prevTicks          = nowTicks;

        float Ts_s = Ts_ms / 1000.0f;
        float revs = (float)dTicks / TICKS_PER_REV;
        float rpm  = (revs / Ts_s) * 60.0f;
        float omega = rpm * (2.0f * PI / 60.0f);

        float vbus      = ina219.getBusVoltage_V();
        float current_A = ina219.getCurrent_mA() * 0.001f;

        float duty_frac = duty / float((1 << PWM_RES) - 1);
        float u_eff = duty_frac * vbus;

        Serial.printf("%.6f,%.1f,%.3f,%.3f,%.6f,%.6f,%.3f\n",
                      t_s, (float)pwm_pct, vbus, u_eff, current_A, omega, rpm);
    }

    // Stop motor after segment
    ledcWrite(PWM_CH, 0);
    tb6612_brake();
    delay(20);
    digitalWrite(PIN_STBY, LOW);
}



// ===================== SETUP =====================
void setup()
{
    Serial.begin(921600);
    delay(500);

    // Motor pins
    pinMode(PIN_AIN1, OUTPUT);
    pinMode(PIN_AIN2, OUTPUT);
    pinMode(PIN_STBY, OUTPUT);
    digitalWrite(PIN_STBY, HIGH);
    tb6612_coast();

    // PWM
    ledcSetup(PWM_CH, PWM_FREQ, PWM_RES);
    ledcAttachPin(PIN_PWMA, PWM_CH);
    ledcWrite(PWM_CH, 0);

    // INA219
    Wire.begin(PIN_SDA, PIN_SCL);
    Wire.setClock(400000);
    if (!ina219.begin()) {
        Serial.println("INA219 not found!");
        while (1) delay(10);
    }

    // Encoder
    pinMode(ENC_A, INPUT_PULLUP);
    pinMode(ENC_B, INPUT_PULLUP);
    ESP32Encoder::useInternalWeakPullResistors = UP;
    enc.attachFullQuad(ENC_A, ENC_B);
    enc.setFilter(120);
    enc.setCount(0);

    Serial.println();
    Serial.println("=== TB6612 + INA219 + Encoder CSV Logger ===");
    Serial.println("READY");
}


// ===================== LOOP =====================
void loop()
{
    if (!Serial.available()) return;

    String line = Serial.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) return;

    // ================= SEQ COMMAND =================
    if (line.startsWith("SEQ"))
    {
        // Format:  SEQ,Ts_ms,pwm1,pwm2,pwm3
        int c1 = line.indexOf(',');
        int c2 = line.indexOf(',', c1+1);
        int c3 = line.indexOf(',', c2+1);
        int c4 = line.indexOf(',', c3+1);

        if (c1 < 0 || c2 < 0 || c3 < 0 || c4 < 0) {
            Serial.println("ERR: Invalid SEQ format");
            return;
        }

        int Ts_ms = line.substring(c1+1, c2).toInt();
        int pwm1  = line.substring(c2+1, c3).toInt();
        int pwm2  = line.substring(c3+1, c4).toInt();
        int pwm3  = line.substring(c4+1).toInt();

        if (Ts_ms < 1) Ts_ms = 1;

        Serial.println("Starting sequence");
        Serial.println("t_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM");

        // Start global timestamp
        sequenceStart_us = micros();

        // ===== Test Timeline =====
        runSegment(Ts_ms, 1000, 0);     // 1 sec rest
        runSegment(Ts_ms, 2000, pwm1);  // Step 1
        runSegment(Ts_ms, 1000, 0);
        runSegment(Ts_ms, 2000, pwm2);  // Step 2
        runSegment(Ts_ms, 1000, 0);
        runSegment(Ts_ms, 2000, pwm3);  // Step 3
        runSegment(Ts_ms, 1000, 0);     // Final rest

        Serial.println("SEQ DONE");
        Serial.println("READY");
        return;
    }

    // Ignore any other legacy commands
}
