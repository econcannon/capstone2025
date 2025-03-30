#include <WiFi.h>
#include <Arduino.h>
#include <ArduinoHttpClient.h>
#include <Arduino_JSON.h>
#include <ArduinoBLE.h>
#include <LiquidCrystal.h>
#include <tuple>
#include <utility>

// const int buttonUpPin    = 2;
// const int buttonDownPin  = 3;
// const int buttonLeftPin  = 4;
const int buttonRightPin = 2;

// // Flags for each button
// volatile bool upPressed = false;
// volatile bool downPressed = false;
// volatile bool leftPressed = false;
volatile bool rightPressed = false;
volatile unsigned long rightButtonPressedTime = 0;


// // Debounce timers for each button
// volatile unsigned long lastDebounceUp = 0;
// volatile unsigned long lastDebounceDown = 0;
// volatile unsigned long lastDebounceLeft = 0;
volatile unsigned long lastDebounceRight = 0;
const unsigned long debounceDelay = 50;  // milliseconds

// Global variables for ease of use between functions
bool gameOver = false;
String winner = "";
bool myTurn = false;
bool opponentsTurn = false;
String myColor = "";
String fromSquare = "";
String toSquare = "";
String last_move = "";
// volatile bool inMenu = false; // For the purpose of interrupts, determining current state
volatile bool inGetMove = false;
volatile bool sendButtonPressed = false;

// // Interrupt handlers
// void handleUp() {
//   unsigned long now = millis();
//   if (now - lastDebounceUp > debounceDelay) {
//     upPressed = true;
//     lastDebounceUp = now;
//   }
// }

// void handleDown() {
//   unsigned long now = millis();
//   if (now - lastDebounceDown > debounceDelay) {
//     downPressed = true;
//     lastDebounceDown = now;
//   }
// }

// void handleLeft() {
//   unsigned long now = millis();
//   if (now - lastDebounceLeft > debounceDelay) {
//     leftPressed = true;
//     lastDebounceLeft = now;
//   }
// }

void handleRight() {
  unsigned long now = millis();
  if (now - lastDebounceRight > debounceDelay) {
    rightPressed = true;
    lastDebounceRight = now;
    buttonPressedTime = now;
    if (inGetMove) {sendButtonPressed = true;}
  }
}

// Hall sensor pin assignments and thresholds
const int rowOne = 22;
const int rowTwo = 24;
const int rowThree = 26;
const int rowFour = 28;
const int rowFive = 30;
const int rowSix = 32;
const int rowSeven = 34;
const int rowEight = 36;

#define colEight A11
#define colSeven A10
#define colSix A9
#define colFive A8
#define colFour A7
#define colThree A6
#define colTwo A5
#define colOne A4

const int lowerThresh = 600;
const int upperThresh = 900;

// Board state 2D array
//  1 = Black piece
//-1 = White piece
//  0 = Empty space
int current_board_state[8][8];
int last_board_state[8][8];
int expected_board_state[8][8];

// LCD pin assignments
const int rs = 6, en = 9, d4 = 2, d5 = 3, d6 = 4, d7 = 5;

LiquidCrystal lcd(rs, en, d4, d5, d6, d7);


// WiFi credentials and server details
char ssid[50];
char password[50];
char playerID[50];
char gameID[65];
char useType[50];
int reset;

// Server details
const char *serverAddress = "chess-app-v5.concannon-e.workers.dev";
int port = 443; // HTTPS WebSocket

WiFiSSLClient wifiClient;
WebSocketClient wsClient(wifiClient, serverAddress, port);

// BLE Service and Characteristics (UUIDs)
#define GAMESERVICE_CHAR_UUID "5c8fbcee-e44a-440a-b9be-f09510b40411"
#define SSID_CHAR_UUID "8266532f-1fe1-4af9-97e1-3b7c04ef8201"
#define PASSWORD_CHAR_UUID "91abf729-1b45-4147-b8f7-b93620e8bce1"
#define GAMEID_CHAR_UUID "5f91bb09-093c-42d7-b615-a2b110369a2e"
#define PLAYERID_CHAR_UUID "bcf9cb8c-78f4-4b22-8f2c-ad5df34a34cd"
#define RESET_CHAR_UUID "cfb3a8c4-85c7-4e9f-9f0b-b1c6e22b15e2"
#define USE_TYPE_CHAR_UUID "cfb3a8c4-85c7-4e9f-9f0b-b1c6e22b15e3"

// Create BLE Service and Characteristics
BLEService gameService(GAMESERVICE_CHAR_UUID);
BLEStringCharacteristic ssidCharacteristic(SSID_CHAR_UUID, BLERead | BLEWrite, 50);
BLEStringCharacteristic passwordCharacteristic(PASSWORD_CHAR_UUID, BLERead | BLEWrite, 50);
BLEStringCharacteristic gameIDCharacteristic(GAMEID_CHAR_UUID, BLERead | BLEWrite, 65);
BLEStringCharacteristic playerIDCharacteristic(PLAYERID_CHAR_UUID, BLERead | BLEWrite, 50);
BLEByteCharacteristic resetCharacteristic(RESET_CHAR_UUID, BLEWrite);
BLEStringCharacteristic useTypeCharacteristic(USE_TYPE_CHAR_UUID, BLERead | BLEWrite, 50);

void do_nothing(){
  
}

void setup()
{
    Serial.begin(115200);
    Serial1.begin(9600);
    if (!Serial)
        delay(1000);

    // BLE Setup
    if (!BLE.begin())
    {
        Serial.println("BLE initialization failed!");
    }
    BLE.setLocalName("GIGA_R1_Bluetooth");
    BLE.setAdvertisedService(gameService);

    // Add BLE characteristics
    gameService.addCharacteristic(ssidCharacteristic);
    gameService.addCharacteristic(passwordCharacteristic);
    gameService.addCharacteristic(gameIDCharacteristic);
    gameService.addCharacteristic(playerIDCharacteristic);
    gameService.addCharacteristic(resetCharacteristic);
    gameService.addCharacteristic(useTypeCharacteristic);

    BLE.addService(gameService);
    BLE.advertise();
    Serial.println("Bluetooth advertising started...");

    // Hall sensor rows
    pinMode(rowEight, OUTPUT);
    pinMode(rowOne, OUTPUT);
    pinMode(rowTwo, OUTPUT);
    pinMode(rowThree, OUTPUT);
    pinMode(rowFour, OUTPUT);
    pinMode(rowFive, OUTPUT);
    pinMode(rowSix, OUTPUT);
    pinMode(rowSeven, OUTPUT);

    Serial.println("Here");

    // // Set all button pins as inputs with pull-up resistors
    // pinMode(buttonUpPin, INPUT_PULLUP);
    // pinMode(buttonDownPin, INPUT_PULLUP);
    // pinMode(buttonLeftPin, INPUT_PULLUP);
    pinMode(buttonRightPin, INPUT_PULLUP);

    Serial.println("There");

    // attachInterrupt(digitalPinToInterrupt(buttonUpPin), handleUp, FALLING);
    // attachInterrupt(digitalPinToInterrupt(buttonDownPin), handleDown, FALLING);
    // attachInterrupt(digitalPinToInterrupt(buttonLeftPin), handleLeft, FALLING);
    attachInterrupt(digitalPinToInterrupt(buttonRightPin), handleRight, FALLING);

    Serial.println("Done");

    // Initialize global vars
    clear_characteristics();
    reset = 0;

    initialize_expected_board();
    print_board();
}


// Resets all characteristic values and sets the global variables to 0 except for reset
void clear_characteristics()
{   
    memset(ssid, 0, sizeof(ssid));
    memset(password, 0, sizeof(password));
    memset(gameID, 0, sizeof(gameID));
    memset(playerID, 0, sizeof(playerID));
    memset(useType, 0, sizeof(useType));
    ssidCharacteristic.setValue("");
    passwordCharacteristic.setValue("");
    gameIDCharacteristic.setValue("");
    playerIDCharacteristic.setValue("");
    resetCharacteristic.setValue(0);
    useTypeCharacteristic.setValue("");
}

// SCAN BOARD AND DETECT PIECE CHANGES 
std::pair<String, String> get_move() {
    inGetMove = true;
    Serial.println("In get move");
    while ((fromSquare == "") || (toSquare == "") || !sendButtonPressed) {
      if (sendButtonPressed && millis() - buttonPressedTime > 500) {
        sendButtonPressed = false;
        Serial.println("Button press expired, waiting for new press...");
      }
      Serial.println("sendButtonPressed: ");
      Serial.print(sendButtonPressed);
      Serial.println("From Square: ");
      Serial.print(fromSquare);
      Serial.println("To Square: ");
      Serial.print(toSquare);

      scan_grid_detect_pieces();
      track_changes();
      // update_lcd("Detected move: from " + fromSquare + " to " + toSquare);
    }
    sendButtonPressed = false;
    inGetMove = false;
    return {fromSquare, toSquare};
}

void loop() {
  // put your main code here, to run repeatedly:
  Serial.println("Starting loop");
  std::pair<String, String> move = get_move();
  Serial.println("Detected Moves");
  Serial.println(move.first);
  Serial.println(move.second);
  fromSquare = "";
  toSquare = "";
  initialize_expected_board();
  print_board();
}



// Store up to 5 sets of difference data
const int NUM_DIFFS = 5;
int diffHistory[NUM_DIFFS][64][3]; // Up to 64 diffs to allow for extreme case of every position changing
int diffCounts[NUM_DIFFS];
int diffIndex = 0;


// Convert index to chess square notation (e.g., e2, e4)
String indexToSquare(int row, int col) {
  char file = 'a' + col;
  int rank = row+1;
  return String(file) + String(rank);
}

// Compare current board with expected board and record differences
int getDifferences(int diffs[][3]) {
  int count = 0;
  for (int row = 0; row < 8; row++) {
    for (int col = 0; col < 8; col++) {
      if (expected_board_state[row][col] != current_board_state[row][col]) {
        diffs[count][0] = row;
        diffs[count][1] = col;
        diffs[count][2] = current_board_state[row][col];
        count++;
      }
    }
  }
  return count;
}

// Save current difference data
void recordDiffHistory(int diffs[][3], int count) {
  for (int i = 0; i < count; i++) {
    diffHistory[diffIndex][i][0] = diffs[i][0];
    diffHistory[diffIndex][i][1] = diffs[i][1];
    diffHistory[diffIndex][i][2] = diffs[i][2];
  }
  diffCounts[diffIndex] = count;
  diffIndex = (diffIndex + 1) % NUM_DIFFS;
}

// Check if last NUM_DIFFS differences have been the same
bool isStableChange() {
  for (int i = 1; i < NUM_DIFFS; i++) {
    if (diffCounts[i] != diffCounts[0]) return false;
    for (int j = 0; j < diffCounts[0]; j++) {
      for (int k = 0; k < 3; k++) {
        if (diffHistory[i][j][k] != diffHistory[0][j][k]) return false;
      }
    }
  }
  return true;
}

void track_changes() {
  int diffs[64][3];
  int count = getDifferences(diffs);
  recordDiffHistory(diffs, count);

  if (count > 0 && isStableChange()) {
    if (count == 2) {
      for (int i = 0; i < count; i++) {
        int row = diffs[i][0];
        int col = diffs[i][1];
        int newVal = diffs[i][2];
        int oldVal = expected_board_state[row][col];

        Serial.print("row: ");
        Serial.print(row);
        Serial.print(", col: ");
        Serial.print(col);
        Serial.print(", oldVal: ");
        Serial.print(oldVal);
        Serial.print(", newVal: ");
        Serial.println(newVal);

        if (newVal == 0 && (oldVal == 1 || oldVal == -1)) {
          fromSquare = indexToSquare(row, col);
        } else if (oldVal == 0 && (newVal == 1 || newVal == -1)) {
          toSquare = indexToSquare(row, col);
        }
      }
      if (fromSquare != "" && toSquare != "") {
        Serial.print("Move detected: fromSquare = ");
        Serial.print(fromSquare);
        Serial.print(", toSquare = ");
        Serial.println(toSquare);
        Serial.println("sendButtonPressed: ");
        Serial.print(sendButtonPressed);
      }
    } else if (count == 4) {
      Serial.println("Castling or promotion detected. Placeholder for further implementation.");
    }

    // Update expected board to match current board
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        expected_board_state[row][col] = current_board_state[row][col];
      }
    }
  }
}

// Sequentially turns the 8 sensors in a row ON and reads the 8 columns for each row
// Compares sensor value to threshold, detects piece presence and polarity
// Updates global board state 2D array
void scan_grid_detect_pieces()
{
    float sensorValue;
    // Serial.println("LOOP START");
    for (int i = 1; i < 9; i++)
    {
        set_hall_row_voltage(i);
        // Serial.print("Setting row: ");
        // Serial.println(i);
        delay(5);
        delay(10);
        for (int j = 1; j < 9; j++)
        {
            // Serial.print("Reading with i ");
            // Serial.print(i);
            // Serial.print(" j: ");
            // Serial.println(j);
            delay(5);
            sensorValue = read_hall_col(j); // Read sensor
            // Serial.println(sensorValue);

            if (sensorValue > upperThresh)
            {
                Serial.println("Black piece detected at: (" + String(i) + String(j));
                current_board_state[i - 1][j - 1] = 1;
                // string lcdString = "Black piece @ ()" + i  ", " + j + ") " + sensorValue;
                // update_lcd(message);
                lcd.clear();
                lcd.setCursor(0, 0);
                lcd.print("Black @ ");
                lcd.setCursor(5, 1);
                lcd.print(i);
                lcd.setCursor(6, 1);
                lcd.print(",");
                lcd.setCursor(7, 1);
                lcd.print(j);
            }
            else if (sensorValue < lowerThresh & sensorValue >= 100)
            {
                Serial.println("White piece detected at: (" + String(i) + String(j));
                //  return piece informatio
                current_board_state[i - 1][j - 1] = -1;
                // String lcdString = "White piece @ ()" + i  ", " + j + ") " + sensorValue;
                // update_lcd(message);
                lcd.clear();
                lcd.setCursor(0, 0);
                lcd.print("White @ ");
                lcd.setCursor(5, 1);
                lcd.print(i);
                lcd.setCursor(6, 1);
                lcd.print(",");
                lcd.setCursor(7, 1);
                lcd.print(j);
            }
            else
            {
                current_board_state[i - 1][j - 1] = 0;
            }
            // Serial.println("step done");
        }
        // Serial.println("for loop done");
    }
    // delay(10);  // Small delay for stability
}

// HALL SENSOR FUNCTIONS
void set_hall_row_voltage(int value)
{
    digitalWrite(rowOne, LOW);
    digitalWrite(rowTwo, LOW);
    digitalWrite(rowThree, LOW);
    digitalWrite(rowFour, LOW);
    digitalWrite(rowFive, LOW);
    digitalWrite(rowSix, LOW);
    digitalWrite(rowSeven, LOW);
    digitalWrite(rowEight, LOW);
    delay(50);
    // Serial.println("Set all voltages OFF");
    switch (value)
    {
    case 1:
        digitalWrite(rowOne, HIGH);
        break;
    case 2:
        digitalWrite(rowTwo, HIGH);
        break;
    case 3:
        digitalWrite(rowThree, HIGH);
        break;
    case 4:
        digitalWrite(rowFour, HIGH);
        break;
    case 5:
        digitalWrite(rowFive, HIGH);
        break;
    case 6:
        digitalWrite(rowSix, HIGH);
        break;
    case 7:
        digitalWrite(rowSeven, HIGH);
        break;
    case 8:
        digitalWrite(rowEight, HIGH);
        break;
    }
    delay(150);
}

// Assumes one row of sensors is ON, reads column index {value}
float read_hall_col(int value)
{
    // Serial.println("Reading:");
    float val = -1; // Default value in case of error
    delayMicroseconds(5);
    switch (value)
    {
    case 1:
        val = analogRead(colOne);
        break;
    case 2:
        val = analogRead(colTwo);
        break;
    case 3:
        val = analogRead(colThree);
        break;
    case 4:
        val = analogRead(colFour);
        break;
    case 5:
        val = analogRead(colFive);
        break;
    case 6:
        val = analogRead(colSix);
        break;
    case 7:
        val = analogRead(colSeven);
        break;
    case 8:
        val = analogRead(colEight);
        break;
    }
    delay(10);
    return val;
}

void initialize_expected_board()
{
    float sensorValue;
    // Serial.println("LOOP START");
    for (int i = 1; i < 9; i++)
    {
        set_hall_row_voltage(i);
        // Serial.print("Setting row: ");
        // Serial.println(i);
        delay(5);
        delay(10);
        for (int j = 1; j < 9; j++)
        {
            // Serial.print("Reading with i ");
            // Serial.print(i);
            // Serial.print(" j: ");
            // Serial.println(j);
            delay(5);
            sensorValue = read_hall_col(j); // Read sensor
            // Serial.println(sensorValue);

            if (sensorValue > upperThresh)
            {
                Serial.println("Black piece detected at: (" + String(i) + String(j));
                expected_board_state[i - 1][j - 1] = 1;
                // string lcdString = "Black piece @ ()" + i  ", " + j + ") " + sensorValue;
                // update_lcd(message);
                lcd.clear();
                lcd.setCursor(0, 0);
                lcd.print("Black @ ");
                lcd.setCursor(5, 1);
                lcd.print(i);
                lcd.setCursor(6, 1);
                lcd.print(",");
                lcd.setCursor(7, 1);
                lcd.print(j);
            }
            else if (sensorValue < lowerThresh & sensorValue >= 100)
            {
                Serial.println("White piece detected at: (" + String(i) + String(j));
                //  return piece informatio
                expected_board_state[i - 1][j - 1] = -1;
                // String lcdString = "White piece @ ()" + i  ", " + j + ") " + sensorValue;
                // update_lcd(message);
                lcd.clear();
                lcd.setCursor(0, 0);
                lcd.print("White @ ");
                lcd.setCursor(5, 1);
                lcd.print(i);
                lcd.setCursor(6, 1);
                lcd.print(",");
                lcd.setCursor(7, 1);
                lcd.print(j);
            }
            else
            {
                expected_board_state[i - 1][j - 1] = 0;
            }
            // Serial.println("step done");
        }
        // Serial.println("for loop done");
    }
    // delay(10);  // Small delay for stability
}



void print_board() {
  Serial.println("");
  for (int row = 7; row > -1; row--) {
    for (int col = 0; col < 8; col++) {
      Serial.print(expected_board_state[row][col]);
      Serial.print("\t");  // Tab for spacing
    }
    Serial.println();  // New line after each row
  }
}
