#include <Arduino.h>

#define LED_PIN 2   // GPIO2 (built-in LED)

// Task handles
TaskHandle_t taskUARTHandle;
TaskHandle_t taskSensorHandle;

// ---------------- UART Task ----------------
void taskUART(void *pvParameters) {
  (void) pvParameters;

  for (;;) {
    if (Serial.available() > 0) {
      String cmd = Serial.readStringUntil('\n');
      cmd.trim();

      if (cmd == "LED_ON") {
        digitalWrite(LED_PIN, HIGH);
        Serial.println("LED turned ON");
      } 
      else if (cmd == "LED_OFF") {
        digitalWrite(LED_PIN, LOW);
        Serial.println("LED turned OFF");
      }
    }
    vTaskDelay(50 / portTICK_PERIOD_MS);  // check every 50ms
  }
}

// ---------------- Sensor Task ----------------
void taskSensor(void *pvParameters) {
  (void) pvParameters;

  for (;;) {
    int sensorValue = analogRead(34);  // dummy sensor
    Serial.println(sensorValue);
    vTaskDelay(1000 / portTICK_PERIOD_MS);  // every 1s
  }
}

// ---------------- Setup ----------------
void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Create tasks
  xTaskCreatePinnedToCore(
    taskUART,           // Task function
    "UART Task",        // Task name
    4096,               // Stack size
    NULL,               // Parameters
    1,                  // Priority (higher = more urgent)
    &taskUARTHandle,    // Task handle
    1                   // Run on core 1
  );

  xTaskCreatePinnedToCore(
    taskSensor,         // Task function
    "Sensor Task",      // Task name
    4096,               
    NULL,               
    1,                  
    &taskSensorHandle,  
    1                   // Also on core 1 (you can change to 0 if you want to split)
  );
}

void loop() {
  // Empty: we’re using FreeRTOS tasks instead
}
