/* I2C resetter */

#include <Wire.h>

#define MY_I2C_ADDRESS 0x0f
#define PIN_RESET 1
#define PIN_BUTTON_1 4
#define PIN_BUTTON_2 3

volatile byte flag_position;
volatile byte flags[] = {0, 0, 0};
const uint8_t flags_size = sizeof(flags) / sizeof(byte);

void _blinking() {
  for (int i = 0; i < 3; i++) {
    digitalWrite(PIN_RESET, LOW);
    delay(10);
    digitalWrite(PIN_RESET, HIGH);
    delay(10);
  }
}

void do_reset() {
  digitalWrite(PIN_RESET, LOW);
  delay(1);
  digitalWrite(PIN_RESET, HIGH);
}

void receiveEvent(int nbytes) {
  flag_position = Wire.read();
  nbytes--;
  if (nbytes == 1 && flag_position == 0x00)
    do_reset();
  while (nbytes--) {
    flag_position %= flags_size;
    flags[flag_position] = Wire.read();
    flag_position++;
  }
}

void requestEvent() {
  flag_position %= flags_size;
  Wire.write(flags[flag_position]);
  flag_position++;
}

void setup() {
  Wire.begin(MY_I2C_ADDRESS);
  Wire.onReceive(receiveEvent);
  Wire.onRequest(requestEvent);
  pinMode(PIN_RESET, OUTPUT);
  digitalWrite(PIN_RESET, HIGH);
  pinMode(PIN_BUTTON_1, INPUT_PULLUP);
  pinMode(PIN_BUTTON_2, INPUT_PULLUP);
}

void wait_button_off(int pin) {
  while (1) {
    delay(10);
    if (digitalRead(pin) == HIGH)
      return;
  }
}

void loop() {
  if (digitalRead(PIN_BUTTON_1) == LOW) {
    wait_button_off(PIN_BUTTON_1);
    flags[1] = 1;
  } else if (digitalRead(PIN_BUTTON_2) == LOW) {
    wait_button_off(PIN_BUTTON_2);
    flags[2] = 1;
  }
  delay(50);
}
