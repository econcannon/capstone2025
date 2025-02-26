#include <WiFi.h>
#include <Arduino.h>
#include <ArduinoHttpClient.h>
#include <Arduino_JSON.h>
#include <ArduinoBLE.h>

// WiFi credentials and server details
char ssid[50];
char password[50];
char playerID[50];
char gameID[65];

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

// Create BLE Service and Characteristics
BLEService gameService(GAMESERVICE_CHAR_UUID);
BLEStringCharacteristic ssidCharacteristic(SSID_CHAR_UUID, BLERead | BLEWrite, 50);
BLEStringCharacteristic passwordCharacteristic(PASSWORD_CHAR_UUID, BLERead | BLEWrite, 50);
BLEStringCharacteristic gameIDCharacteristic(GAMEID_CHAR_UUID, BLERead | BLEWrite, 65);
BLEStringCharacteristic playerIDCharacteristic(PLAYERID_CHAR_UUID, BLERead | BLEWrite, 50);
BLEByteCharacteristic resetCharacteristic(RESET_CHAR_UUID, BLEWrite);  // Reset characteristic

String playerColor = "";
char turn = ' ';  // 'w' or 'b' indicating whose turn it is
bool bleConnected = false;

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

  BLE.addService(gameService);
  BLE.advertise();
  Serial.println("Bluetooth advertising started...");

  // Wait for BLE WiFi credentials and game ID
  waitForBluetoothCredentials();

  // Connect to WiFi after receiving credentials
  connectToWiFi();

  // Join the game using WebSocket
  joinGame();
}

void loop() {
  BLEDevice central = BLE.central();

  if (central) {
    if (!bleConnected) {
      Serial.print("Connected to central: ");
      Serial.println(central.address());
      bleConnected = true;
    }
  } else if (bleConnected) {
    Serial.println("Bluetooth disconnected, restarting advertising...");
    BLE.advertise();
    bleConnected = false;
  }

  // Check for reset signal
  if (resetCharacteristic.written() && resetCharacteristic.value() == 1) {
    Serial.println("Reset signal received via Bluetooth.");
    resetGame();
  }

  // WebSocket communication loop
  if (wsClient.connected()) {
    int messageSize = wsClient.parseMessage();
    if (messageSize > 0) {
      String response = wsClient.readString();
      Serial.print("Received: ");
      Serial.println(response);
      handleIncomingMessage(response);
    }
  } else {
    Serial.println("WebSocket disconnected, attempting reconnect...");
    joinGame();
    delay(5000);
  }

  BLE.poll();  // Handle BLE events while WebSocket is idle
}

// BLE - Wait for WiFi Credentials & GameID via Bluetooth
void waitForBluetoothCredentials() {
  Serial.println("Waiting for WiFi credentials and gameID via Bluetooth...");

  while (!bleConnected) {
    BLEDevice central = BLE.central();
    if (central) {
      Serial.print("Connected to central: ");
      Serial.println(central.address());

      while (central.connected()) {
        readBLECredentials();
        if (strlen(ssid) > 0 && strlen(password) > 0 && strlen(gameID) > 0 && strlen(playerID) > 0) {
          Serial.println("All credentials received.");
          return;
        }
      }
    }
  }
}

void readBLECredentials() {
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
}

// Join the WebSocket game
void joinGame() {

  if (WiFi.status() != WL_CONNECTED)
  {
    connectToWiFi();
  }
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


// Reconnect WiFi if needed
void connectToWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000); 
    Serial.print(".");
    WiFi.begin(ssid, password);
  }
  Serial.println("\nConnected to WiFi");
}


// Reset Game (triggered by BLE reset signal)
void resetGame() {
  memset(ssid, 0, sizeof(ssid));
  memset(password, 0, sizeof(password));
  memset(gameID, 0, sizeof(gameID));
  memset(playerID, 0, sizeof(playerID));
  waitForBluetoothCredentials();
  connectToWiFi();
  joinGame();
}


// Handle Incoming WebSocket Messages
void handleIncomingMessage(String message) {
  JSONVar parsedMessage = JSON.parse(message);
  String messageType = parsedMessage["message_type"];
  bool game_over = parsedMessage["game_over"];
  bool checkmate = parsedMessage["checkmate"];
  Serial.println("parsed message: ");
  Serial.print(parsedMessage);
  if (messageType == "game-state") {
    String fen = (const char *)parsedMessage["fen"];
    playerColor = (const char *)parsedMessage["color"];
    String turnString = (const char *)parsedMessage["turn"];
    turn = turnString.charAt(0);

    Serial.println("\nGame State Updated: " + fen);
    if ((playerColor == "white" && turn == 'w') || (playerColor == "black" && turn == 'b')) {
      sendMove();
    }
  } else if (messageType == "confirmation") {
    if (game_over) {
      if (checkmate == true) {
        Serial.println("You won!");
      } else {
        Serial.println("Draw");
      }
    }
  }
}

void getMove(String &fromSquare, String &toSquare) {
  // Get the "from" square
  Serial.print("Enter move from (e.g., e2): ");
  while (Serial.available() == 0) {}
  fromSquare = Serial.readStringUntil('\n');
  fromSquare.trim();

  // Get the "to" square
  Serial.print("Enter move to (e.g., e4): ");
  while (Serial.available() == 0) {}
  toSquare = Serial.readStringUntil('\n');
  toSquare.trim();
}

void sendMove() {
  String fromSquare, toSquare;
  bool moveConfirmed = false;

  while (!moveConfirmed) {
    // Get move by calling the new function
    getMove(fromSquare, toSquare);

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
    }
  }
}


bool reconnectWebSocket() {
  if (wsClient.connected()) {
    return true;  // Already connected
  }

  Serial.println("Attempting to reconnect WebSocket...");
  char wsURL[100];
  snprintf(wsURL, sizeof(wsURL), "/connect?gameID=%s&playerID=%s", gameID, playerID);
  wsClient.begin(wsURL);

  long startAttempt = millis();
  int timeout = 5000;  // 5 seconds timeout

  while (!wsClient.connected() && millis() - startAttempt < timeout) {
    Serial.print(".");
    delay(1000);
  }

  if (wsClient.connected()) {
    Serial.println("\nWebSocket reconnected successfully.");
    return true;
  } else {
    Serial.println("\nWebSocket reconnection failed.");
    return false;
  }
}
