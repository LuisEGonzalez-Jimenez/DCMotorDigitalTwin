/******************************************************************
* Project
	Hardware in the Loop applied to a DC Motor
* File
	CD Motor Current sensing
* Description
	Using the ESP32-S3, TB6612 motor bridge and INA219 DC current
	sensor, print the armature current on the motor while running
	a PWM step test
* Author:
	Ramos Romero Rodrigo
* Date:
	26/10/2025
*TODO:
	
******************************************************************/



#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_INA219.h>

Adafruit_INA219 ina219;  // default I2C address 0x40

// === Pin mapping (your wiring) ===
const int PIN_PWMA = 9;    // TB6612 PWMA (LEDC-capable)
const int PIN_AIN1 = 10;   // TB6612 AIN1
const int PIN_AIN2 = 11;   // TB6612 AIN2
const int PIN_STBY = 12;   // TB6612 STBY

// I2C pins (your actual wiring)
const int PIN_SDA = 6;
const int PIN_SCL = 7;

// LEDC PWM setup
const int LEDC_CH   = 0;
const int LEDC_FREQ = 20000; // 20 kHz
const int LEDC_RES  = 10;    // 10-bit resolution (0–1023)

void tb6612_coast() { digitalWrite(PIN_AIN1, LOW); digitalWrite(PIN_AIN2, LOW); }
void tb6612_forward() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, LOW); }
void tb6612_reverse() { digitalWrite(PIN_AIN1, LOW); digitalWrite(PIN_AIN2, HIGH); }
void tb6612_brake() { digitalWrite(PIN_AIN1, HIGH); digitalWrite(PIN_AIN2, HIGH); }

//Prints only the current values and updates, no way to check those before
void logElectrical(int duty) {
  float bus_V = ina219.getBusVoltage_V();
  float current_mA = ina219.getCurrent_mA();
  float power_mW = ina219.getPower_mW();

  Serial.printf("Duty=%4d | Vbus=%.3fV | I=%.2fmA | P=%.1fmW\r", 
                duty, bus_V, current_mA, power_mW);
  Serial.flush(); // ensure the line updates in monitor
}

/* Keeps printing so we can compare values
void logElectrical(int duty) {
  float bus_V = ina219.getBusVoltage_V();
  float shunt_mV = ina219.getShuntVoltage_mV();
  float current_mA = ina219.getCurrent_mA();
  float power_mW = ina219.getPower_mW();

  Serial.print("Duty=");
  Serial.print(duty);
  Serial.print(" | I=");
  Serial.print(current_mA);
  Serial.print("mA\n");

} */

void setup() {
  //pinMode(LED_BUILTIN, OUTPUT);
  //digitalWrite(LED_BUILTIN, HIGH);  // turn on LED immediately
  Serial.println("\n\n=== TB6612 + INA219 bring-up ===");
  Serial.begin(115200);
  delay(50);

  // I2C initialization
  Wire.begin(PIN_SDA, PIN_SCL);
  if (!ina219.begin()) {
    Serial.println("INA219 not found! Check wiring/address.");
    while (true) delay(10);
  }

  // TB6612 control pins
  pinMode(PIN_AIN1, OUTPUT);
  pinMode(PIN_AIN2, OUTPUT);
  pinMode(PIN_STBY, OUTPUT);
  digitalWrite(PIN_STBY, HIGH);  // Enable bridge

  // PWM setup
  ledcSetup(LEDC_CH, LEDC_FREQ, LEDC_RES);
  ledcAttachPin(PIN_PWMA, LEDC_CH);
  ledcWrite(LEDC_CH, 0);

  tb6612_coast();
  delay(200);

  Serial.println("=== TB6612 + INA219 bring-up ===");

  // Soft-start forward
  tb6612_forward();
  for (int d = 0; d <= 700; d += 20) {
    ledcWrite(LEDC_CH, d);
    logElectrical(d);
    delay(50);
  }

  tb6612_brake();
  ledcWrite(LEDC_CH, 0);
  delay(300);

  // Reverse
  tb6612_reverse();
  for (int d = 0; d <= 600; d += 20) {
    ledcWrite(LEDC_CH, d);
    logElectrical(d);
    delay(50);
  }

  // Hold at steady reverse 50%
  ledcWrite(LEDC_CH, 512);
  tb6612_reverse();
}

void loop() {
  // Log current/power continuously
  logElectrical(512);
  delay(200);
}
