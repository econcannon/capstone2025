

#include <FastLED.h>

#define LED_PIN 6         // Data pin for LED strip
#define NUMPIXELS 180      // Number of LEDs

CRGB leds[NUMPIXELS];






void setup() {
  Serial.begin(9600);  // Start serial communication with Giga
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUMPIXELS);
  FastLED.clear();  // Ensure LEDs are off initially
  FastLED.show();
  delay(1000);
}

typedef struct {
    char letter;
    int value;
} ColumnMapping;

ColumnMapping columns[] = {
    {'A', 7}, {'B', 6}, {'C', 5}, {'D', 4},
    {'E', 3}, {'F', 2}, {'G', 1}, {'H', 0}
};

int calculate_board_led(led){
  char col;
  int row;
  int parsed = sscanf(command.c_str(led), "%c%d", &col, &row);
  // led_num = (8 * row - columns[col].value) * 2;
  if row % 2 == 1:  //# Odd rows (A1-H1, A3-H3, etc.) → Left to Right
      led_num = (8 * row - columns[col].value) * 2;
  else:  # Even rows //(A2-H2, A4-H4, etc.) → Right to Left. FLIP COLUMN MAPPING
      led_num = (8 * row - (7 - columns[col].value)) * 2;

  return led_num
}



void loop() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');  // Read incoming command
    Serial.println("Received: " + command); 

    if (command.startsWith("SET_LED")) {
      int led = -1, r = -1, g = -1, b = -1;
      int parsed = sscanf(command.c_str(), "SET_LED %d %d %d %d", &led, &r, &g, &b);

      // Debugging the sscanf result
      Serial.print("Parsed values: ");
      Serial.print("LED = "); Serial.print(led);

      led = calculate_board_led(led);

      Serial.print(", R = "); Serial.print(r);
      Serial.print(", G = "); Serial.print(g);
      Serial.print(", B = "); Serial.println(b);
      Serial.print("Parsing Success: "); Serial.println(parsed);

      if (parsed == 4 && led >= 0 && led < NUMPIXELS) {
        leds[led] = CRGB::White;
        // leds[led+1] = CRGB(r, g, b);
        FastLED.show();
        Serial.print("lit");
      }
    } else if (command.startsWith("CLEAR")) {
      FastLED.clear();
      FastLED.show();
    }
  }
}

