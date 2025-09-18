#include <Arduino.h>
#include <Adafruit_NeoPixel.h>

#define LED_PIN 48       // On-board RGB LED (WS2812, GPIO48)
#define ADC_PIN 4        // Safe ADC1 pin on ESP32-S3
#define NUM_LEDS 1       // Only 1 built-in RGB

Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Task handles
TaskHandle_t taskUARTHandle;
TaskHandle_t taskSensorHandle;

// ---------------- Helper Functions ----------------
void setRGB(uint8_t r, uint8_t g, uint8_t b) {
  strip.setPixelColor(0, strip.Color(r, g, b));
  strip.show();
}

// ---------------- UART Task ----------------
void taskUART(void *pvParameters) {
  (void) pvParameters;

  for (;;) {
    if (Serial.available() > 0) {
      String cmd = Serial.readStringUntil('\n');
      cmd.trim();

      if (cmd == "LED_ON") {
        setRGB(0, 0, 255);   // Blue ON
        Serial.println("LED turned ON (Blue)");
      } 
      else if (cmd == "LED_OFF") {
        setRGB(0, 0, 0);     // OFF
        Serial.println("LED turned OFF");
      }
    }
    vTaskDelay(pdMS_TO_TICKS(50));  // check every 50ms
  }
}

// ---------------- Sensor Task ----------------
void taskSensor(void *pvParameters) {
  (void) pvParameters;

  // Configure ADC
  analogReadResolution(12);       // 12-bit (0-4095)
  analogSetAttenuation(ADC_11db); // input up to ~3.3V

  for (;;) {
    int sensorValue = analogRead(ADC_PIN);
    Serial.println(sensorValue);   // **only numeric output for MATLAB**
    vTaskDelay(pdMS_TO_TICKS(1000));  // every 1s
  }
}

// ---------------- Setup ----------------
void setup() {
  Serial.begin(115200);

  // Init RGB
  strip.begin();
  strip.show();  // start with LED off

  // Create tasks
  xTaskCreatePinnedToCore(taskUART, "UART Task", 4096, NULL, 1, &taskUARTHandle, 1);
  xTaskCreatePinnedToCore(taskSensor, "Sensor Task", 4096, NULL, 1, &taskSensorHandle, 1);
}

void loop() {
  // Empty: FreeRTOS handles everything
}
