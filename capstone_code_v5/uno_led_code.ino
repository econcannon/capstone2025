#include <FastLED.h>

#define LED_PIN 6         // Data pin for LED strip
#define NUMPIXELS 180      // Number of LEDs

CRGB leds[NUMPIXELS];



void setup() {
  Serial.begin(9600);  // Start serial communication with Giga
  FastLED.addLeds<WS2812B, LED_PIN, GRB>(leds, NUMPIXELS);
  FastLED.clear();  // Ensure LEDs are off initially
  FastLED.show();
  leds[5] = CRGB(255, 0, 0);
  FastLED.show();

  delay(1000);
  FastLED.clear();
  FastLED.show();
}

typedef struct {
    char letter;
    int value;
} ColumnMapping;

// ColumnMapping columns[] = {
//     {'A', 7}, {'B', 6}, {'C', 5}, {'D', 4},
//     {'E', 3}, {'F', 2}, {'G', 1}, {'H', 0}
// };
ColumnMapping columns[] = {
  {'a', 0}, {'b', 1}, {'c', 2}, {'d', 3},
  {'e', 4}, {'f', 5}, {'g', 6}, {'h', 7}
};

int get_column_value(char letter) {
  for (int i = 0; i < 8; i++) {
    if (columns[i].letter == letter) {
      return columns[i].value;
    }
  }
  return -1;
}

int calculate_board_led(char col, int row) {
  int col_val = get_column_value(col);
  if (col_val == -1) return -1;  // Invalid input

  int row_idx = row - 1;  // Convert to 0-based index
  int led_num;

  if (row % 2 == 1) {
    // Odd rows: left to right
    led_num = (row_idx * 8 + col_val) * 2;
  } else {
    // Even rows: right to left
    led_num = (row_idx * 8 + (7 - col_val)) * 2;
  }

  Serial.print("LED number: ");
  Serial.println(led_num);
  return led_num;
}


void loop() {
  if (Serial.available()) {
    String command = Serial.readStringUntil('\n');  // Read incoming command
    Serial.println("Received: " + command); 

    if (command.startsWith("SET_LED")) {
      // String led = "";
      // // int led = -1,
      // int r = -1, g = -1, b = -1;
      // int parsed = sscanf(command.c_str(), "SET_LED %d %d %d %d", &led, &r, &g, &b);
      char led_col;
      int led_row, r, g, b;
      int parsed = sscanf(command.c_str(), "SET_LED %c%d %d %d %d", &led_col, &led_row, &r, &g, &b);

      // Debugging the sscanf result
      // Serial.print("Parsed values: ");
      // Serial.print("LED = "); Serial.print(led);

      // led = calculate_board_led(led);

      // Serial.print(", R = "); Serial.print(r);
      // Serial.print(", G = "); Serial.print(g);
      // Serial.print(", B = "); Serial.println(b);
      // Serial.print("Parsing Success: "); Serial.println(parsed);
     
      Serial.print("Parsed: ");
      Serial.print("col = "); Serial.print(led_col);
      Serial.print(", row = "); Serial.print(led_row);
      Serial.print(", R = "); Serial.print(r);
      Serial.print(", G = "); Serial.print(g);
      Serial.print(", B = "); Serial.println(b);
      Serial.print("Parsing Success: "); Serial.println(parsed);

      if (parsed == 5) {
        int led = calculate_board_led(led_col, led_row);
        Serial.println("led number: " + led); 
        if (led < NUMPIXELS) { //led >= 0 &&
          leds[led] = CRGB(r, g, b);
          leds[led + 1] = CRGB(r, g, b);
          FastLED.show();
          Serial.println("LED lit");
        }
      }
        } else if (command.startsWith("CLEAR")) {
          FastLED.clear();
          FastLED.show();
      }





    //   if (parsed == 4 && led >= 0 && led < NUMPIXELS) {
    //     leds[led] = CRGB::White;
    //     // leds[led+1] = CRGB(r, g, b);
    //     FastLED.show();
    //     Serial.print("lit");
    //   }
    // } else if (command.startsWith("CLEAR")) {
    //   FastLED.clear();
    //   FastLED.show();
    // }
  }
}





