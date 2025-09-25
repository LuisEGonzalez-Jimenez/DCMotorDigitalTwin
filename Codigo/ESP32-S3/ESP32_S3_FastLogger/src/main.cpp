/*Fast Logger version, removed all unnecessary LED code and now only requires
Syncing the Baudrate with matlab, instead of Baud + Sampling freq*/

#include <Arduino.h>

#define ADC_PIN 4        // Safe ADC1 pin on ESP32-S3

// Task handles
TaskHandle_t taskSensorHandle;

// ---------------- Sensor Task ----------------
void taskSensor(void *pvParameters) {
  (void) pvParameters;

  // Configure ADC
  analogReadResolution(12);       // 12-bit (0-4095)
  analogSetAttenuation(ADC_11db); // input up to ~3.3V

  for (;;) {
    int sensorValue = analogRead(ADC_PIN);
    Serial.println(sensorValue);   // numeric only for MATLAB
    vTaskDelay(pdMS_TO_TICKS(1));  // ~1 ms per sample (1 kHz)
  }
}

// ---------------- Setup ----------------
void setup() {
  Serial.begin(115200);
  // Create task pinned to core 1
  xTaskCreatePinnedToCore(taskSensor, "Sensor Task", 4096, NULL, 1, &taskSensorHandle, 1);
}

void loop() {
  // Empty: FreeRTOS task handles everything
}
