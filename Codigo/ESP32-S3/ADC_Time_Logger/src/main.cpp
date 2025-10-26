/******************************************************************
* Project
	Hardware in the Loop applied to a DC Motor
* File
	ADC TIme Logger
* Description
	Read the ADC and log with time stamps
	Updated code so that we send to MATLAB both the time for each sample, and the sample value
* Author:
	Ramos Romero Rodrigo
* Date:
	26/10/2025
*TODO:
	
******************************************************************/

#include <Arduino.h>

#define ADC_PIN 4  // ADC1 safe pin on ESP32-S3

TaskHandle_t taskSensorHandle;

// ---------------- Sensor Task ----------------
void taskSensor(void *pvParameters) {
  (void) pvParameters;

  analogReadResolution(12);       // 12-bit (0–4095)
  analogSetAttenuation(ADC_11db); // up to ~3.3V

  unsigned long startMicros = micros();

  for (;;) {
    int sensorValue = analogRead(ADC_PIN);
    unsigned long elapsedMicros = micros() - startMicros;
    float elapsedSec = elapsedMicros / 1e6;

    Serial.print(elapsedSec, 6);  // time in seconds with 6 decimals
    Serial.print(",");
    Serial.println(sensorValue);

    vTaskDelay(pdMS_TO_TICKS(1)); // ~1 ms per sample
  }
}

// ---------------- Setup ----------------
void setup() {
  Serial.begin(115200);
  xTaskCreatePinnedToCore(taskSensor, "Sensor Task", 4096, NULL, 1, &taskSensorHandle, 1);
}

void loop() {
  // Empty — FreeRTOS task does the work
}
