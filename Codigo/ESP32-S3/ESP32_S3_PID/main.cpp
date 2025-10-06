#include <Arduino.h>
#include <math.h>  // isnan, isinf, isfinite

// --- Tunable gains
static float Kp = 13.0f;
static float Ki = 0.0f;
static float Kd = 0.0f;

// --- Loop settings
static const float T   = 0.001f;    // 1 ms
static const float r   = 5.0f;      // reference (rad/s)
static const float UMAX = 12.0f;    // voltage saturation +12 V
static const float UMIN = -12.0f;   // voltage saturation -12 V

// --- State
static float y = 0, e = 0, u = 0;
static float uP = 0, uI = 0, uD = 0;
static float ekm1 = 0, uIkm1 = 0;
static unsigned long lastTick = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) { ; }        // wait for USB CDC on S3
  Serial.setTimeout(5);        // short read timeout to avoid long blocking
}

void loop() {
  // run controller at 1 kHz
  if (micros() - lastTick < 1000) return;
  lastTick = micros();

  // Expect one line with y each tick. If not available, still reply with last u.
  if (Serial.available()) {
    String line = Serial.readStringUntil('\n');
    line.trim();                    // remove \r, spaces
    if (line.length() == 0) {
      // empty line: keep last y (or set to 0)
      // y = y; // no change
    } else {
      float y_in = line.toFloat();  // returns 0 if not numeric
      if (isfinite(y_in)) {
        y = y_in;
      } else {
        // bad input: keep previous y and don’t update integrator this round
      }
    }
  }

  // PID compute (saturation & anti-windup currently DISABLED for tuning)
  e  = r - y;
  uP = Kp * e;
  uD = Kd * (e - ekm1) / T;

  // Tentative integral update (use current error for integration)
  float uI_candidate = uIkm1 + Ki * T * e;

  // Unsaturated sum with candidate integral
  float u_unsat = uP + uD + uI_candidate;

  // --- SATURATION (DISABLED) ---
  // float u_sat = u_unsat;
  // if (u_sat > UMAX) u_sat = UMAX;    // <-- uncomment to re-enable cap
  // if (u_sat < UMIN) u_sat = UMIN;    // <-- uncomment to re-enable cap

  // --- ANTI-WINDUP (DISABLED) ---
  // bool sat_hi = (u_unsat > UMAX);
  // bool sat_lo = (u_unsat < UMIN);
  // bool drives_deeper = (sat_hi && e > 0) || (sat_lo && e < 0);
  // if (drives_deeper) {
  //   uI = uIkm1;               // reject integral growth this tick
  // } else {
  //   uI = uI_candidate;        // accept integral update
  // }
  // With anti-windup disabled, always accept integral update:
  uI = uI_candidate;

  // Final control (NO saturation here while tuning)
  u = uP + uD + uI;
  // if (u > UMAX) u = UMAX;          // <-- uncomment to re-enable cap
  // if (u < UMIN) u = UMIN;          // <-- uncomment to re-enable cap

  // NaN/Inf guard (keep this!)
  if (!isfinite(u)) {
    u = 0.0f;     // safe fallback
    uI = 0.0f;    // reset integrator to recover
  }

  // Return control to MATLAB
  Serial.println(u, 6);

  // Update memory
  ekm1  = e;
  uIkm1 = uI;
}
