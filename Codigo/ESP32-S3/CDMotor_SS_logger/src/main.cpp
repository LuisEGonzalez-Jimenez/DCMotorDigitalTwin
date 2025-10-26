/******************************************************************
* Project
	Hardware in the Loop applied to a DC Motor
* File
	CD Motor State Space Logger
* Description
	Logs values captured using the ESP32-S3, TB6612 motor bridge and 
	INA219 DC sensor for matlab processing using PWM input from
	0-100%. Updated version from "full logger" that saves RPM,
	Current and Angular velocity
* Author:
	Ramos Romero Rodrigo
* Date:
	26/10/2025
*TODO:
	
******************************************************************/

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_INA219.h>

//
// === Hardware Pin Mapping ===
//
const int PIN_PWMA = 9;    // TB6612 PWM
const int PIN_AIN1 = 10;   // TB6612 AIN1
const int PIN_AIN2 = 11;   // TB6612 AIN2
const int PIN_STBY = 12;   // TB6612 STBY (HIGH = enable)

// I2C pins for INA219
const int PIN_SDA = 6;
const int PIN_SCL = 7;

// Encoder pins
const int ENC_A = 4;
const int ENC_B = 5;

// === Encoder characteristics ===
const int PPR = 330;                        // pulses per revolution
const unsigned long SAMPLE_PERIOD_MS = 100; // sample period
const unsigned long TEST_DURATION_MS = 2000; // run time = 2 s

// === Globals ===
volatile long encoder_count = 0;
float rpm = 0.0;


Adafruit_INA219 ina219;

// === TB6612 helpers ===
void tb6612_forward() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, LOW); }
void tb6612_brake()   { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, HIGH); }
void tb6612_coast()   { digitalWrite(PIN_AIN1, LOW);  digitalWrite(PIN_AIN2, LOW); }

//
// === Encoder ISR ===
//
void IRAM_ATTR encoderISR() {
  int B = digitalRead(ENC_B);
  if (B == HIGH)
    encoder_count++;
  else
    encoder_count--;
}

//
// === Setup ===
//
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=== TB6612 + INA219 + Encoder CSV Test ===");

  // I2C init
  Wire.begin(PIN_SDA, PIN_SCL);
  if (!ina219.begin()) {
    Serial.println("INA219 not found! Check wiring/address.");
    while (true) delay(10);
  }

  // TB6612 pins
  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  pinMode(PIN_STBY, OUTPUT);
  digitalWrite(PIN_STBY, HIGH);
  tb6612_coast();

  // Encoder pins
  pinMode(ENC_A, INPUT_PULLUP);
  pinMode(ENC_B, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(ENC_A), encoderISR, RISING);

  // PWM setup (LEDC)
  const int LEDC_CH = 0;
  const int LEDC_FREQ = 20000; // 20 kHz
  const int LEDC_RES  = 10;    // 10-bit
  ledcSetup(LEDC_CH, LEDC_FREQ, LEDC_RES);
  ledcAttachPin(PIN_PWMA, LEDC_CH);
  ledcWrite(LEDC_CH, 0);

  Serial.println("Please input PWM step % (0–100):");
}

//
// === Loop ===
//
void loop() {
  static bool testRunning = false;
  static unsigned long testStart = 0;
  static unsigned long lastSample = 0;
  static int duty = 0;
  const int LEDC_CH = 0;

  // --- Wait for user input ---
  if (!testRunning && Serial.available() > 0) {
    int pwm_percent = Serial.parseInt();
    if (pwm_percent >= 0 && pwm_percent <= 100) {
      while (Serial.available()) Serial.read(); // clear buffer

      duty = map(pwm_percent, 0, 100, 0, 1023);
      Serial.printf("Starting test with PWM = %d%% (duty=%d)\n", pwm_percent, duty);
      Serial.println("t_s,duty_pct,Vbus_V,u_eff_V,current_A,omega_rad_s,RPM"); // CSV header

      tb6612_forward();
      ledcWrite(LEDC_CH, duty);

      encoder_count = 0;
      testStart = millis();
      lastSample = testStart;
      testRunning = true;
    } else {
      Serial.println("Invalid input. Please enter 0–100.");
      while (Serial.available()) Serial.read();
    }
  }

  // --- Run test ---
  if (testRunning) {
    unsigned long now = millis();

    if (now - lastSample >= SAMPLE_PERIOD_MS) {
      noInterrupts();
      long counts = encoder_count;
      encoder_count = 0;
      interrupts();

      float revs = (float)counts / (float)PPR;
      float revs_per_sec = revs / (SAMPLE_PERIOD_MS / 1000.0f);
      rpm = revs_per_sec * 60.0f;
      float omega = rpm * (2.0f * PI / 60.0f);

      float bus_V = ina219.getBusVoltage_V();
      float current_A = ina219.getCurrent_mA() / 1000.0f;

      float duty_frac = duty / 1023.0f;
      float u_eff = duty_frac * bus_V;
      float t_s = (now - testStart) / 1000.0f;

      // === CSV print ===
      Serial.printf("%.3f,%.1f,%.3f,%.3f,%.6f,%.4f,%.2f\n",
                    t_s, duty_frac * 100.0f, bus_V, u_eff, current_A, omega, rpm);

      lastSample = now;
    }

    // Stop after 2 s
    if (millis() - testStart >= TEST_DURATION_MS) {
      ledcWrite(LEDC_CH, 0);
      tb6612_brake();
      testRunning = false;
      Serial.println("Test complete.\n");
      Serial.println("Please input PWM step % (0–100):");
    }
  }
}
