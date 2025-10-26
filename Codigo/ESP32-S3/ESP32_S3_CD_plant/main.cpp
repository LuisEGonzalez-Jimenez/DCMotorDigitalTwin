/******************************************************************
* Project
	Hardware in the Loop applied to a DC Motor
* File
	CD Motor Plant 
* Description
	Arduino Sketch for the ESP32-S3 that simulates a DC motor
    as "Plant" Controlled by a Matlab / Octave PID 
* Author:
	Ramos Romero Rodrigo
* Date:
	26/10/2025
*TODO:
	
******************************************************************/

#include <Arduino.h>

/** Parameters for the DC Motor **/
constexpr float R = 10.0f;
constexpr float L = 10e-3f;
constexpr float Kt = 0.2f;
constexpr float Kb = 0.2f;
constexpr float Jm = 0.01f;
constexpr float Bm = 0.1f;
constexpr float Ts = 0.001f;

/** Initial states **/
float i = 0.0f;
float w = 0.0f;

/** Initial voltage input**/
float u = 0.0f;

unsigned long prevMicros = 0; //used to return the number of microseconds since boot
const unsigned long Ts_us = 1000; //Sampling period in us - Must match Matlab / Octave
uint8_t syncByte = 0xAA; //Syncrhonization byte, Ensures we start reading at the beggining of a serial frame

//setting up serial connection
void setup() {
  Serial.begin(230400); //baudrate
  while (!Serial) delay(10); //waits for serial connection to become active (matlab / octave)
  //pinMode(LED_BUILTIN, OUTPUT);
  prevMicros = micros(); //sets the starting reference for the 1 kHz timing loop.
}

void loop() {
  unsigned long now = micros();
  if (now - prevMicros >= Ts_us) {
    prevMicros += Ts_us; 

    // 1. Wait for a sync byte then read control input
    if (Serial.available() >= 5) {
      uint8_t hdr = Serial.read();
      if (hdr == 0xAA) {  // valid frame start
        uint8_t buf[4];
        Serial.readBytes(buf, 4);
        memcpy(&u, buf, sizeof(float));
        //digitalWrite(LED_BUILTIN, HIGH); // indicates active link
      }
    } // Receives one packet = [0xAA][float u] → 5 bytes total from Matlab

    // 2. Integrate motor model - SImulation of the DC Motor
    float di = ((-R * i) - (Kb * w) + u) / L;
    float dw = ((Kt * i) - (Bm * w)) / Jm;
    i += Ts * di;
    w += Ts * dw;

    // 3. Send sync byte then data (ω, i) - Sends data frames to Matlab [0xAA][ω float (4 bytes)][i float (4 bytes)]
    Serial.write(syncByte); //aligns matlab to the start of the frame using 0xAA
    Serial.write((uint8_t *)&w, sizeof(float)); 
    Serial.write((uint8_t *)&i, sizeof(float));
  } 
}
