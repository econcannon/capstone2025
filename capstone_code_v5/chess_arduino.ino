#include <WiFi.h>
#include <Arduino.h>
#include <ArduinoHttpClient.h>
#include <Arduino_JSON.h>
#include <ArduinoBLE.h>
#include <LiquidCrystal.h>

//Hall sensor pin assignments and thresholds
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

//Board state 2D array
// 1 = Black piece
//-1 = White piece
// 0 = Empty space
int current_board_state[8][8];
int last_board_state[8][8];
int expected_board_state[8][8];

//LCD pin assignments
const int rs = 6, en = 9, d4 = 2, d5 = 3, d6 = 4, d7 = 5;

// WiFi credentials and server details
char ssid[50];
char password[50];
char playerID[50];
char gameID[65];
char useType[50];
int reset;

// Server details
const char *serverAddress = "chess-app-v5.concannon-e.workers.dev";
int port = 443;  // HTTPS WebSocket

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
BLEByteCharacteristic useTypeCharacteristic(USE_TYPE_CHAR_UUID, BLEWrite); 


void setup() {
    Serial.begin(115200);
    if (!Serial) delay(1000);   
    
    // BLE Setup
    if (!BLE.begin()) {
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
    
    //Hall sensor rows
    pinMode(rowEight, OUTPUT);
    pinMode(rowOne, OUTPUT);
    pinMode(rowTwo, OUTPUT);
    pinMode(rowThree, OUTPUT);
    pinMode(rowFour, OUTPUT);
    pinMode(rowFive, OUTPUT);
    pinMode(rowSix, OUTPUT);
    pinMode(rowSeven, OUTPUT);

    // Initialize global vars
    ssid = "";
    password = "";
    playerID = "";
    gameID = "";
    useType = "";
    reset = false;
}

void loop() {

    check_connections(); // Checks for proper connection to BLE and WiFi
    if (useType == "play")
        play_game(); // Starts the game with proper connection
    else if (useType == "replay")
        replay_game(); // ReVIsualize history of a completed game
    check_characteristics(); // game connection info (Reset, loss connection, etc)
    reset = false; // Setting here so that checking characteristics can propagate through all functions
}

void check_connections() {
    connect_to_wifi();
    connect_to_bluetooth();
}

void check_characteristics() {
    read_ble_credentials();
    if (reset) {
        clear_characteristics();
    }
}

void clear_characteristics() {
    ssidCharacteristic.setValue("");
    passwordCharacteristic.setValue("");
    gameIDCharacteristic.setValue("");
    playerIDCharacteristic.setValue("");
    resetCharacteristic.setValue(false);
    useTypeCharacteristic.setValue("");
}

void read_ble_credentials() {
  if (ssidCharacteristic.written()) {
    String s = ssidCharacteristic.value();
    s.trim();
    s.toCharArray(ssid, sizeof(ssid));
    Serial.print("SSID: ");
    Serial.println(ssid);
  }
  if (passwordCharacteristic.written()) {
    String p = passwordCharacteristic.value();
    p.trim();
    p.toCharArray(password, sizeof(password));
    Serial.print("Password: ");
    Serial.println(password);
  }
  if (gameIDCharacteristic.written()) {
    String g = gameIDCharacteristic.value();
    g.trim();
    g.toCharArray(gameID, sizeof(gameID));
    Serial.print("Game ID: ");
    Serial.println(gameID);
  }
  if (playerIDCharacteristic.written()) {
    String u = playerIDCharacteristic.value();
    u.trim();
    u.toCharArray(playerID, sizeof(playerID));
    Serial.print("User ID: ");
    Serial.println(playerID);
  }
  if (useTypeCharacteristic.written()) {
    String use = useTypeCharacteristic.value();
    use.trim();
    use.toCharArray(useType, sizeof(useType));
    Serial.print("Use Type: ");
    Serial.println(useType);
    }
    if (resetCharacteristic.written()) {
        reset = resetCharacteristic.value();
        Serial.print("Reset: ");
        Serial.println(reset);
    }
}

// Reconnect WiFi if needed
void connect_to_wifi() {
    Serial.print("Connecting to WiFi: ");
    Serial.println(ssid);

    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        WiFi.begin(ssid, password);
        delay(1000);
        Serial.print(".");
    }
    Serial.println("\nConnected to WiFi");
}

void connect_to_bluetooth() {
    if (BLE.connected()) {
        Serial.println("Bluetooth already connected");
        return;
    }

    BLE.advertise();
    Serial.println("Waiting for Bluetooth connection...");
    while (!BLE.connected()) {
        delay(100);
    }
    Serial.println("Bluetooth connected");
}


void play_game() {
    bool myTurn = false;
    bool opponentsTurn = false;
    bool gameOver = false;
    join_game(); // Connects to game server, gets current turn and game state
    
    while !(gameOver)
        check_websocket();
        check_characteristics();
        get_messages(); // Takes in any incoming message and handles accordingly
        if myTurn
            scan_grid_detect_pieces();
            send_move();
            update_LCD(); // 'Move sent' confirmation
            opponentsTurn = true;
            myTurn = false;
        else if opponentsTurn
            wait_for_opponentMove();
            validate_opponent_move(); // Make sure scanned grid matches expectations
            myTurn = true;
            opponentsTurn = false;
            //Wait and check if local player moves opponent's piece
            scan_grid_detect_pieces();  // Detects current board state
            //Confirm they moved the right one to the right spot
            update_LCD(); // 'Your turn' message
        else
            Serial.println("Error: Neither player's turn.");
        
    handle_game_over();
}


// NEEDS TO HAVE AUTHENTICATION TOKEN ADDED
void joinGame() {
    if(WiFi.status() != WL_CONNECTED) connectToWiFi();
  
    char wsURL[100];
    snprintf(wsURL, sizeof(wsURL), "/connect?gameID=%s&playerID=%s", gameID, playerID);
    Serial.println("wsURL: ");
    Serial.print(wsURL);
    wsClient.begin(wsURL);
    int timeout = 5000;
    long startAttempt = millis();
    while (!wsClient.connected() && millis() - startAttempt < timeout) {
      Serial.println("Attempting WebSocket connection...");
      delay(1000);
    }
  
    if (wsClient.connected()) {
      Serial.println("WebSocket connected.");
    } else {
      Serial.println("WebSocket connection failed.");
    }
  }

void check_websocket() {
    check_connections();
    if (!wsClient.connected()) {
        join_game();
    }
}

void get_messages() {
    

}

//HALL SENSOR FUNCTIONS
void set_hall_row_voltage(int value) {
    digitalWrite(rowOne, LOW);
    digitalWrite(rowTwo, LOW);
    digitalWrite(rowThree, LOW);
    digitalWrite(rowFour, LOW);
    digitalWrite(rowFive, LOW);
    digitalWrite(rowSix, LOW);
    digitalWrite(rowSeven, LOW);
    digitalWrite(rowEight, LOW);
    delay(50);
    //Serial.println("Set all voltages OFF");
    switch (value) {
        case 1: digitalWrite(rowOne, HIGH); break;
        case 2: digitalWrite(rowTwo, HIGH); break;
        case 3: digitalWrite(rowThree, HIGH); break;
        case 4: digitalWrite(rowFour, HIGH); break;
        case 5: digitalWrite(rowFive, HIGH); break;
        case 6: digitalWrite(rowSix, HIGH); break;
        case 7: digitalWrite(rowSeven, HIGH); break;
        case 8: digitalWrite(rowEight, HIGH); break;
    }
    delay(150);
}

//Assumes one row of sensors is ON, reads column index {value}
float read_hall_col(int value) {
    //Serial.println("Reading:");
    float val = -1;  // Default value in case of error
    delayMicroseconds(5);
    switch (value) {
        case 1: val = analogRead(colOne); break;
        case 2: val = analogRead(colTwo); break;
        case 3: val = analogRead(colThree); break;
        case 4: val = analogRead(colFour); break;
        case 5: val = analogRead(colFive); break;
        case 6: val = analogRead(colSix); break;
        case 7: val = analogRead(colSeven); break;
        case 8: val = analogRead(colEight); break;
    }
    delay(10);
    return val;
}

//Sequentially turns the 8 sensors in a row ON and reads the 8 columns for each row
//Compares sensor value to threshold, detects piece presence and polarity
//Updates global board state 2D array
void scan_grid_detect_pieces(){
    float sensorValue;
    //Serial.println("LOOP START");
    for (int i = 1; i < 9; i++) {
        set_hall_row_voltage(i);
        //Serial.print("Setting row: ");
        //Serial.println(i);
        delay(5);
        delay(200);
        for (int j = 1; j < 9; j++) {           
            //Serial.print("Reading with i ");
            //Serial.print(i);   
            //Serial.print(" j: ");
            //Serial.println(j);
            delay(5);
            sensorValue = read_hall_col(j);  // Read sensor
            //Serial.println(sensorValue);
           
            if (sensorValue > upperThresh) {
                //Serial.print("Black piece detected at: (");
                current_board_state[i-1, j-1] = 1;
                //string lcdString = "Black piece @ ()" + i  ", " + j + ") " + sensorValue;
                //update_lcd(message);
            }
            else if (sensorValue < lowerThresh & sensorValue >= 100) {
                //Serial.print("White piece detected at: (");
                // return piece informatio
                current_board_state[i-1, j-1] = -1;
                //string lcdString = "White piece @ ()" + i  ", " + j + ") " + sensorValue;
                //update_lcd(message);
            }
            else {
                current_board_state[i-1, j-1] = 0;
            }
            // Serial.println("step done");
        }
        // Serial.println("for loop done");
    }
    //delay(10);  // Small delay for stability
}


void send_move(String::fromSquare, String::toSquare){
    
    // send local move coordinates to server

    bool moveConfirmed = false;

    while (!moveConfirmed) {
        while (1) {
      if (!reconnectWebSocket()) {
        Serial.println("Failed to reconnect. Retrying move...");
      } else {
        break;
      }
    }

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

    // Wait for confirmation
    long startTime = millis();
    while (millis() - startTime < 10000) {  // Wait for up to 5 seconds
      int messageSize = wsClient.parseMessage();
      if (messageSize > 0) {
        String response = wsClient.readString();
        Serial.print("Received: ");
        Serial.println(response);

        // Parse the response
        JSONVar parsedResponse = JSON.parse(response);

        String messageType = parsedResponse["message_type"];

        if (messageType == "confirmation") {
          moveConfirmed = true;
          Serial.println("Move confirmed!");
          break;
        } else if (messageType == "error") {
          String error = parsedResponse["error"];
          Serial.println("Invalid move. Try again. Error message: " + error);
          break;
        } else {
          break;
        }
      }
      string lcdString = "Move from " + fromSquare + " to " + toSquare + " sent!";
      update_lcd(message);
    }
  }
}

// update lcd / display string - Move sent, Opponents turn, your turn, game over You win
void update_lcd(string message){
    lcd.clear();
    lcd.println(message)

    int messageLength = message.length();

    if (messageLength <= 16) {
        lcd.setCursor(0, 0);
        lcd.print(message);
    } else if (messageLength <= 32) {
        lcd.setCursor(0, 0);
        lcd.print(message.substring(0, 16));
        lcd.setCursor(0, 1);
        lcd.print(message.substring(16));
    } else {
    for (int i = 0; i < messageLength - 15; i++) {
      lcd.setCursor(0, 0);
      lcd.print(message.substring(i, i + 16));
      delay(300);
    }
  }
}


void validate_opponent_move(){

    // check with HALL EFFECT SENSORS moved to correct point
    // While current state != expected state:
        // Display opponent move LCD and LED
        // Scan board
            // if detect move:
                // compare board states
    // When current state matches expected state:
        // move on

    update_LCD("Board doesn't match expected state");
    while !(compare_board_states()) {
        //Display LCD logic        
        scan_grid_detect_pieces()
        delay(100);
    }
    
        
    
    
}

// String to be displayed on the LCD 
void update_LCD(String s) {
}

// String to send update to LED, determined by messageType
// messageType 1 = opponent move
// messageType 2 = emoji 
void update_LEDS(String s, int messageType) {
    
}

// Board state comparison helper
bool compare_board_states() {
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            if (current_board_state[i][j] != expected_board_state[i][j]) {
                return false
            }
        }
    }
    return true
}


void wait_for_opponent_move(){
    Serial.println("Waiting for opponent to move...");
    // Wait till coordinates received
    while (true) {
        int messageSize = wsClient.parseMessage();
        if (messageSize > 0) {
            String response = wsClient.readString();
            Serial.print("Received: ");
            Serial.println(response);

            JSONVar parsedResponse = JSON.parse(response);

            String messageType = parsedResponse["message_type"];

            if (messageType == "move") {
                String fromSquare = parsedResponse["move"]["from"];
                String toSquare = parsedResponse["move"]["to"];
                Serial.print("Opponent moved from ");
                Serial.print(fromSquare);
                Serial.print(" to ");
                Serial.println(toSquare);

                // update board state
                update_LCD("Opponent moved from " + fromSquare + " to " + toSquare);

                compare_board_states();


                break;
            } else if (messageType == "error") {
                String error = parsedResponse["error"];
                Serial.println("Invalid move. Try again. Error message: " + error);
                break;
            } else {
                break; 
            }
        }
    }
}







