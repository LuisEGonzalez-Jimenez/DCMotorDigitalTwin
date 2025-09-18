void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=== ESP32 Chip Information ===");
  Serial.printf("Chip model     : %s\n", ESP.getChipModel());
  Serial.printf("Chip revision  : %d\n", ESP.getChipRevision());
  Serial.printf("CPU cores      : %d\n", ESP.getChipCores());
  Serial.printf("Flash size     : %d MB\n", ESP.getFlashChipSize() / (1024 * 1024));
  Serial.printf("Flash speed    : %d Hz\n", ESP.getFlashChipSpeed());
  Serial.printf("SDK version    : %s\n", ESP.getSdkVersion());
  Serial.printf("Chip ID        : %08X\n", (uint32_t)ESP.getEfuseMac()); // lower 4 bytes
}

void loop() {
  // nothing
}
