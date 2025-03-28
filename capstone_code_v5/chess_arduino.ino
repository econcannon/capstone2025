#include <WiFi.h>
#include <Arduino.h>
#include <ArduinoHttpClient.h>
#include <Arduino_JSON.h>
#include <ArduinoBLE.h>
#include <LiquidCrystal.h>
#include <tuple>
#include <utility>

const int buttonUpPin    = 29;
const int buttonDownPin  = 30;
const int buttonLeftPin  = 31;
const int buttonRightPin = 32;

// Flags for each button
volatile bool upPressed = false;
volatile bool downPressed = false;
volatile bool leftPressed = false;
volatile bool rightPressed = false;

// Debounce timers for each button
unsigned long lastDebounceUp = 0;
unsigned long lastDebounceDown = 0;
unsigned long lastDebounceLeft = 0;
unsigned long lastDebounceRight = 0;
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
volatile bool inMenu = false; // For the purpose of interrupts, determining current state
volatile bool inGetMove = false;
volatile bool sendButtonPressed = false;

// Interrupt handlers
void handleUp() {
  unsigned long now = millis();
  if (now - lastDebounceUp > debounceDelay) {
    upPressed = true;
    lastDebounceUp = now;
  }
}

void handleDown() {
  unsigned long now = millis();
  if (now - lastDebounceDown > debounceDelay) {
    downPressed = true;
    lastDebounceDown = now;
  }
}

void handleLeft() {
  unsigned long now = millis();
  if (now - lastDebounceLeft > debounceDelay) {
    leftPressed = true;
    lastDebounceLeft = now;
  }
}

void handleRight() {
  unsigned long now = millis();
  if (now - lastDebounceRight > debounceDelay) {
    rightPressed = true;
    lastDebounceRight = now;
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

void setup()
{
    Serial.begin(115200);
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

    // Set all button pins as inputs with pull-up resistors
    pinMode(buttonUpPin, INPUT_PULLUP);
    pinMode(buttonDownPin, INPUT_PULLUP);
    pinMode(buttonLeftPin, INPUT_PULLUP);
    pinMode(buttonRightPin, INPUT_PULLUP);

    attachInterrupt(digitalPinToInterrupt(buttonUpPin), handleUp, RISING);
    attachInterrupt(digitalPinToInterrupt(buttonDownPin), handleDown, RISING);
    attachInterrupt(digitalPinToInterrupt(buttonLeftPin), handleLeft, RISING);
    attachInterrupt(digitalPinToInterrupt(buttonRightPin), handleRight, RISING);


    // Initialize global vars
    clear_characteristics();
    reset = 0;
}

void loop()
{
    
    wait_for_bluetooth_credentials(); // Only need ble until game start
    if (String(useType) == "play") {
        play_game(); // Starts the game with proper connection
    }
    else if (String(useType) == "replay") {
        replay_game(); // ReVIsualize history of a completed game
    }       
    delay(1000);
    reset = 0;           // Setting here so that checking characteristics can propagate through all functions
}

void replay_game() {}

void check_connections()
{
    connect_to_bluetooth();
    connect_to_wifi();
}

void check_characteristics()
{
    read_ble_characteristics();
    if (reset)
    {
        clear_characteristics();
    }
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

void read_ble_characteristics()
{
    if (ssidCharacteristic.written())
    {
        String s = ssidCharacteristic.value();
        s.trim();
        s.toCharArray(ssid, sizeof(ssid));
        Serial.print("SSID: ");
        Serial.println(ssid);
    }
    if (passwordCharacteristic.written())
    {
        String p = passwordCharacteristic.value();
        p.trim();
        p.toCharArray(password, sizeof(password));
        Serial.print("Password: ");
        Serial.println(password);
    }
    if (gameIDCharacteristic.written())
    {
        String g = gameIDCharacteristic.value();
        g.trim();
        g.toCharArray(gameID, sizeof(gameID));
        Serial.print("Game ID: ");
        Serial.println(gameID);
    }
    if (playerIDCharacteristic.written())
    {
        String u = playerIDCharacteristic.value();
        u.trim();
        u.toCharArray(playerID, sizeof(playerID));
        Serial.print("User ID: ");
        Serial.println(playerID);
    }
    if (useTypeCharacteristic.written())
    {
        String use = useTypeCharacteristic.value();
        use.trim();
        use.toCharArray(useType, sizeof(useType));
        Serial.print("Use Type: ");
        Serial.println(useType);
    }
    if (resetCharacteristic.written())
    {
        int resetVal = resetCharacteristic.value();
        if (resetVal == 48) {reset = 0;}
        else {reset = 1;}
        Serial.print("Reset: ");
        Serial.println(reset);
    }
}

void connect_to_wifi()
{
    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);

    while (WiFi.status() != WL_CONNECTED)
    {
        WiFi.begin(ssid, password);
        delay(1000);
        Serial.print(".");
    }
    Serial.println("\nConnected to WiFi");
}


// BLE - Wait for WiFi Credentials & GameID via Bluetooth
void wait_for_bluetooth_credentials() {
    Serial.println("Waiting for WiFi credentials via Bluetooth...");
    
    BLEDevice central = BLE.central();
    while (!central.connected()) {
      central = BLE.central();
      if (central) {
        Serial.print("Connected to central: ");
        Serial.println(central.address());
  
        while (central.connected()) {
          read_ble_characteristics();
        //   if (strlen(ssid) > 0 && strlen(password) > 0 && strlen(gameID) > 0 && strlen(playerID) > 0) {
          if (strlen(ssid) > 0 && strlen(password) > 0 && strlen(gameID) > 0 && strlen(playerID) > 0 && strlen(useType) > 0) {
              Serial.println("All credentials received.");
              return;
          }
        }
      }
      central = BLE.central();
    }

    while (central.connected()) {
      read_ble_characteristics();
      //   if (strlen(ssid) > 0 && strlen(password) > 0 && strlen(gameID) > 0 && strlen(playerID) > 0) {
      if (strlen(ssid) > 0 && strlen(password) > 0 && strlen(useType) > 0) {
        Serial.println("All credentials received.");
        return;
      }
    }
}



void connect_to_bluetooth()
{
    if (BLE.connected())
    {
        Serial.println("Bluetooth already connected");
        return;
    }

    BLE.advertise();
    Serial.println("Waiting for Bluetooth connection...");
    while (!BLE.connected())
    {
        delay(100);
    }
    Serial.println("Bluetooth connected");
}



// SCAN BOARD AND DETECT PIECE CHANGES 
std::pair<String, String> get_move() {
    inGetMove = true;
    while (!fromSquare && !toSquare && !sendButtonPressed) {
    scan_grid_detect_pieces();
    track_changes();
    update_lcd("Detected move: from " + fromSquare + " to " + toSquare);
    }
    inGetMove = false;
    return {fromSquare, toSquare};
}

// std::pair<String, String> get_move() {
//   Serial.print("Enter move from (e.g., e2): ");
//   while (Serial.available() == 0) {}
//   String fromSquare = Serial.readStringUntil('\n');
//   fromSquare.trim();

//   // Get the "to" square
//   Serial.print("Enter move to (e.g., e4): ");
//   while (Serial.available() == 0) {}
//   String toSquare = Serial.readStringUntil('\n');
//   toSquare.trim();
//   return {fromSquare, toSquare};
// }


void play_game()
{
    join_game(); // Connects to game server, gets current turn and game state

    while (!gameOver)
    {
        check_websocket();
        check_characteristics();
        get_messages(); // Takes in any incoming message and handles accordingly Updates gameOver if relevant
        if (!gameOver)
        {
            if (myTurn)
            {
                std::pair<String, String> move = get_move();
                send_move(move.first, move.second); // Confirmations will be handled by get_messages
            }
            else if (opponentsTurn)
            {
              Serial.println("Entered opponents turn");
              delay(1000);
            }
        }
    }
}

void handle_game_over(String player, String winner)
{
    // Display something on the LCD and on LEDs
    if (player == winner)
    {
        update_lcd("You Win!");
    }
    else if (player == "")
    {
        update_lcd("It's a Draw!");
    }
    else
    {
        update_lcd("Game Over!");
    }
    // IMPLEMENT LOGIC TO RESET THE GAME HERE
}

void join_game()
{
    if (WiFi.status() != WL_CONNECTED)
        connect_to_wifi();
    Serial.print(gameID);
    Serial.print(" IN BETWEEN PRINTS ");
    Serial.println(playerID);

    char wsURL[100];
    snprintf(wsURL, sizeof(wsURL), "/connect?gameID=%s&playerID=%s", gameID, playerID);
    Serial.println("wsURL: ");
    Serial.print(wsURL);
    wsClient.begin(wsURL);
    int timeout = 5000;
    long startAttempt = millis();
    while (!wsClient.connected() && millis() - startAttempt < timeout)
    {
        Serial.println("Attempting WebSocket connection...");
        delay(1000);
    }

    if (wsClient.connected())
    {
        Serial.println("WebSocket connected.");
    }
    else
    {
        Serial.println("WebSocket connection failed.");
    }
}

void check_websocket()
{
    if (!wsClient.connected()) {
        join_game();
    }
}

String other_color(String color)
{
    if (color == "white")
        return "black";
    else
        return "white";
}


void get_messages()
{
    int messageSize = wsClient.parseMessage();
    if (messageSize > 0)
    {
        String response = wsClient.readString();
        Serial.print("Received: ");
        Serial.println(response);

        JSONVar parsedResponse = JSON.parse(response);
        handle_message(parsedResponse);
    }
}


void handle_message(JSONVar parsedResponse) {
  String messageType = parsedResponse["message_type"];

  // Opponents move
  if (messageType == "move")
  {
      String opponentFromSquare = (const char *)parsedResponse["move"]["from"];
      String opponentToSquare = (const char *)parsedResponse["move"]["to"];
      Serial.print("Opponent moved from ");
      Serial.print(opponentFromSquare);
      Serial.print(" to ");
      Serial.println(opponentToSquare);
      myTurn = true;
      opponentsTurn = false;
      gameOver = parsedResponse["game_over"];
      bool checkmate = parsedResponse["checkmate"];
      String color = (const char *)parsedResponse["color"];
      if (gameOver & checkmate)
          handle_game_over(color, other_color(color));
      if (gameOver & !checkmate)
          handle_game_over("", "");
      fen_to_expected_board((const char *)parsedResponse["fen"]);
      validate_opponent_move();
  }
  // This section is happening in sendMove now
  // // Confirms my move
  // else if (messageType == "confirmation")
  // {
  //     myTurn = false;
  //     opponentsTurn = true;
  //     gameOver = parsedResponse["game_over"];
  //     checkmate = parsedResponse["checkmate"];
  //     if (gameOver & checkmate)
  //         handle_game_over((const char *)parsedResponse["color"]);
  //     if (gameOver & !checkmate)
  //         handle_game_over("");
  //     Serial.println("Move confirmed!");
  //     fen_to_expected_board((const char *)parsedResponse["fen"]);
  // }
  // Game over
  else if (messageType == "game-state")
  {
      myColor = (const char *)parsedResponse["color"];
      String turn = (const char *)parsedResponse["turn"];
      if (myColor[0] == turn[0]) {
        myTurn = true;
        opponentsTurn = false;
      }
      fen_to_expected_board((const char *)parsedResponse["fen"]);
      last_move = (const char *)parsedResponse["lastMove"];
      if (last_move != nullptr) update_lcd("Last move was: " + last_move);
  }

  else if (messageType == "error")
  {
      String error = (const char *)parsedResponse["error"];
      Serial.println("Invalid move. Try again. Error message: " + error);
  }
  else
  {
      Serial.println("Unknown message type: " + messageType);
  }
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
        delay(200);
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
                // Serial.print("Black piece detected at: (");
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
                // Serial.print("White piece detected at: (");
                //  return piece informatio
                current_board_state[i - 1][j - 1] = -1;
                // string lcdString = "White piece @ ()" + i  ", " + j + ") " + sensorValue;
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


void send_move(String fromSquare, String toSquare)
{

    // send local move coordinates to server

    bool moveConfirmed = false;

    while (!moveConfirmed)
    {
        check_websocket();
        // Construct move payload
        char movePayload[200];
        snprintf(movePayload, sizeof(movePayload),
                 "{\"message_type\":\"move\",\"playerID\":\"%s\",\"move\":{\"from\":\"%s\",\"to\":\"%s\"}}",
                 playerID, fromSquare.c_str(), toSquare.c_str());

        // Send move over WebSocket
        wsClient.beginMessage(TYPE_TEXT);
        wsClient.print(movePayload);
        wsClient.endMessage();

        Serial.print("Move sent: ");
        Serial.print(fromSquare);
        Serial.print(" to ");
        Serial.println(toSquare);
        String lcdString = "Move from " + fromSquare + " to " + toSquare + " sent!";
        update_lcd(lcdString);

        // Wait for confirmation
        long startTime = millis();
        while (millis() - startTime < 10000)
        { // Wait for up to 5 seconds
            int messageSize = wsClient.parseMessage();
            if (messageSize > 0)
            {
                String response = wsClient.readString();
                Serial.print("Received: ");
                Serial.println(response);

                // Parse the response
                JSONVar parsedResponse = JSON.parse(response);

                String messageType = (const char *)parsedResponse["message_type"];

                if (messageType == "confirmation")
                {
                    moveConfirmed = true;
                    Serial.println("Move confirmed!");

                    myTurn = false;
                    opponentsTurn = true;
                    gameOver = parsedResponse["game_over"];
                    bool checkmate = parsedResponse["checkmate"];
                    String color = (const char *)parsedResponse["color"];
                    if (gameOver & checkmate)
                        handle_game_over(color, color);
                    if (gameOver & !checkmate)
                        handle_game_over("", "");
                    fen_to_expected_board((const char *)parsedResponse["fen"]);
                    update_last_board_state();

                    // Reset move coordinates
                    fromSquare = "";
                    toSquare = "";
                    break;
                }
                else if (messageType == "error") // this format of sending and receiving could cause duplicate send attempts
                {
                    String error = (const char *)parsedResponse["error"];
                    Serial.println("Invalid move. Try again. Error message: " + error);
                    break;
                }
                else
                {
                    handle_message(parsedResponse);
                    break;
                }
            }
            
        }
    }
}

// update lcd / display string - Move sent, Opponents turn, your turn, game over You win
void update_lcd(String message)
{
    lcd.clear();
    lcd.println(message);

    int messageLength = message.length();

    if (messageLength <= 16)
    {
        lcd.setCursor(0, 0);
        lcd.print(message);
    }
    else if (messageLength <= 32)
    {
        lcd.setCursor(0, 0);
        lcd.print(message.substring(0, 16));
        lcd.setCursor(0, 1);
        lcd.print(message.substring(16));
    }
    else
    {
        for (int i = 0; i < messageLength - 15; i++)
        {
            lcd.setCursor(0, 0);
            lcd.print(message.substring(i, i + 16));
            delay(300);
        }
    }
}

void validate_opponent_move()
{

    // check with HALL EFFECT SENSORS moved to correct point
    // While current state != expected state:
    // Display opponent move LCD and LED
    // Scan board
    // if detect move:
    // compare board states
    // When current state matches expected state:
    // move on

    update_lcd("Board doesn't match expected state , last move was from " + fromSquare + " to " + toSquare);
    while (!compare_board_states())
        {
            // Display LCD logic
            scan_grid_detect_pieces();
            delay(100);
        }
}

// String to send update to LED, determined by messageType
// messageType 1 = opponent move
// messageType 2 = emoji
void update_LEDS(String s, int messageType)
{
}

// Board state comparison helper
bool compare_board_states()
{
    for (int i = 0; i < 8; i++)
    {
        for (int j = 0; j < 8; j++)
        {
            if (current_board_state[i][j] != expected_board_state[i][j])
            {
                return false;
            }
        }
    }
    return true;
}

void wait_for_opponent_move()
{
    Serial.println("Waiting for opponent to move...");
    // Wait till coordinates received
    while (true)
    {
        int messageSize = wsClient.parseMessage();
        if (messageSize > 0)
        {
            String response = wsClient.readString();
            Serial.print("Received: ");
            Serial.println(response);

            JSONVar parsedResponse = JSON.parse(response);

            String messageType = parsedResponse["message_type"];

            if (messageType == "move")
            {
                String fromSquare = parsedResponse["move"]["from"];
                String toSquare = parsedResponse["move"]["to"];
                Serial.print("Opponent moved from ");
                Serial.print(fromSquare);
                Serial.print(" to ");
                Serial.println(toSquare);

                update_lcd("Opponent moved from " + fromSquare + " to " + toSquare);

                compare_board_states();

                break;
            }
            else if (messageType == "error")
            {
                String error = parsedResponse["error"];
                Serial.println("Invalid move. Try again. Error message: " + error);
                break;
            }
            else
            {
                break;
            }
        }
    }
}

//  1 = Black piece
//-1 = White piece
//  0 = Empty space
void fen_to_expected_board(String fen)
{
    int row = 0;
    int col = 0;

    for (int i = 0; i < fen.length(); i++)
    {
        char c = fen.charAt(i);

        if (c == '/')
        {
            row = row + 1;
            col = 0;
        }
        else if (c >= '1' && c <= '8')
        {
            int emptySquares = c - '0';
            for (int j = 0; j < emptySquares; j++)
            {
                expected_board_state[row][col] = 0;
                col = col + 1;
            }
        }
        else
        {
            bool isUpper = (c >= 'A' && c <= 'Z');
            int pieceVal;

            if (isUpper)
            {
                pieceVal = -1;
            }
            else
            {
                pieceVal = 1;
            }

            expected_board_state[row][col] = pieceVal;
            col = col + 1;
        }

        if (row >= 8)
        {
            break;
        }
    }
}

// not sure how we want to do this, either wil LEDs on board or with LCD
void display_expected_board_state() {}


// Finds changes between two board states. Up to 4 to account for castling
std::tuple<std::pair<int, int>, std::pair<int, int>, std::pair<int, int>, std::pair<int, int>> findChanges(int a[8][8], int b[8][8]) {
    std::pair<int, int> changes[4];
    int count = 0;

    for (int i = 0; i < 8 && count < 4; ++i) {
        for (int j = 0; j < 8 && count < 4; ++j) {
            if (a[i][j] != b[i][j]) {
                changes[count++] = {i, j};
            }
        }
    }

    // Fill remaining with (-1, -1) if only 2 changes
    while (count < 4) {
        changes[count++] = {-1, -1};
    }

    return {changes[0], changes[1], changes[2], changes[3]};
}


void update_last_board_state() {
    for (int row = 0; row < 8; row++) {
        for (int col = 0; col < 8; col++) {
            last_board_state[row][col] = expected_board_state[row][col];
        }
    }
}


// Store up to 5 sets of difference data
const int NUM_DIFFS = 5;
int diffHistory[NUM_DIFFS][64][3]; // Up to 64 diffs to allow for extreme case of every position changing
int diffCounts[NUM_DIFFS];
int diffIndex = 0;


// Convert index to chess square notation (e.g., e2, e4)
String indexToSquare(int row, int col) {
  char file = 'a' + col;
  int rank = 8 - row;
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