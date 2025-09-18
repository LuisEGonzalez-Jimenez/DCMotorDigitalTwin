void setup() {
  // put your setup code here, to executed once:
  Serial.begin(9600);
  Serial.println("This is ESP32 setup code");
}

void loop() {
  // put your main code here, to run repeatedly:
  Serial.println("This is ESP32 loop code");
  delay(1000);
}
