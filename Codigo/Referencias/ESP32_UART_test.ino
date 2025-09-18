#define LED_PIN 2   // GPIO2 (built-in LED on many ESP32 boards)

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW); // start OFF
}

void loop() {
  // If something comes from MATLAB
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');  // read until newline

    cmd.trim(); // remove spaces/newlines

    if (cmd == "LED_ON") {
      digitalWrite(LED_PIN, HIGH);
      Serial.println("LED turned ON");
    } 
    else if (cmd == "LED_OFF") {
      digitalWrite(LED_PIN, LOW);
      Serial.println("LED turned OFF");
    }
  }

  // For testing, ESP keeps sending dummy sensor values
  int sensorValue = analogRead(34);  // or replace with your own source
  Serial.println(sensorValue);
  delay(1000);
}
