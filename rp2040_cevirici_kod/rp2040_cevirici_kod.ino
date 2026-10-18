/*
 * EVRENSEL SESLİ ÇEVİRİ ASİSTANI - RP2040 / Raspberry Pi Pico HID Klavye Kodu
 *
 * Pin Bağlantıları (INPUT_PULLUP - Butonların diğer ucu GND'ye bağlanır):
 * - GP1: 1. Kişi Başla (KEY_F13)
 * - GP2: 2. Kişi Başla (KEY_F14)
 * - GP3: Durdur / Sıfırla (KEY_F15)
 */

#include <Keyboard.h>

const int PIN_KISI_1 = 1; // GP1
const int PIN_KISI_2 = 2; // GP2
const int PIN_DURDUR = 3; // GP3

void setup() {
  pinMode(PIN_KISI_1, INPUT_PULLUP);
  pinMode(PIN_KISI_2, INPUT_PULLUP);
  pinMode(PIN_DURDUR, INPUT_PULLUP);

  Keyboard.begin();
}

void loop() {
  // GP1 -> KEY_F13 (1. Kişi Başla)
  if (digitalRead(PIN_KISI_1) == LOW) {
    Keyboard.press(KEY_F13);
    delay(50);
    Keyboard.releaseAll();

    delay(150); // Debounce (Buton arklarını önleme)
    while (digitalRead(PIN_KISI_1) == LOW) {
      delay(10); // Parmak çekilene kadar bekle
    }
  }

  // GP2 -> KEY_F14 (2. Kişi Başla)
  if (digitalRead(PIN_KISI_2) == LOW) {
    Keyboard.press(KEY_F14);
    delay(50);
    Keyboard.releaseAll();

    delay(150); // Debounce (Buton arklarını önleme)
    while (digitalRead(PIN_KISI_2) == LOW) {
      delay(10); // Parmak çekilene kadar bekle
    }
  }

  // GP3 -> KEY_F15 (Durdur)
  if (digitalRead(PIN_DURDUR) == LOW) {
    Keyboard.press(KEY_F15);
    delay(50);
    Keyboard.releaseAll();

    delay(150); // Debounce (Buton arklarını önleme)
    while (digitalRead(PIN_DURDUR) == LOW) {
      delay(10); // Parmak çekilene kadar bekle
    }
  }
}
