const int numDecoders = 4;
const int numSensors = 1;

// Pins for the 4-to-16 Decoder Select Lines (Shared Across All Decoders)
const int s0 = 22;
const int s1 = 26;
const int s2 = 30;
const int s3 = 34;

// Enable Pins for Each Decoder
const int enableDecoder1 = 38;
const int enableDecoder2 = 42;
const int enableDecoder3 = 46;
const int enableDecoder4 = 50;

// Analog Pin to Read from the Active Decoder Output
#define hallSensorPin A11

// Thresholds for Magnetic Field Detection (Adjust as Needed)
const float highThreshold = 3.3;  // Example: 4V
const float lowThreshold = 2.0;   // Example: 1V

// 2D Array to Store Sensor States [4 Decoders][16 Channels Each]
int sensorState[numDecoders][numSensors] = {0};

// Setup: Initialize Pins
void setup() {
  Serial.begin(9600);  // Initialize Serial Monitor

  // Set Select Pins as Outputs
  pinMode(s0, OUTPUT);
  pinMode(s1, OUTPUT);
  pinMode(s2, OUTPUT);
  pinMode(s3, OUTPUT);

  // Set Enable Pins as Outputs
  pinMode(enableDecoder1, OUTPUT);
  pinMode(enableDecoder2, OUTPUT);
  pinMode(enableDecoder3, OUTPUT);
  pinMode(enableDecoder4, OUTPUT);

  // Disable All Decoders Initially
  disableDecoders();
}

// Main Loop: Continuously Read Sensors
void loop() {
  readSensors();
  printSensorState();
  delay(1000);  // Wait 1 second between readings
}

// Function to Read Sensors from All Decoders
void readSensors() {
  // Loop Through Each Decoder (4 Total)
  for (int decoder = 0; decoder < numDecoders; decoder++) {
    enableDecoder(decoder);  // Enable Current Decoder

    // Loop Through All 16 Channels (0 to 15)
    for (int channel = 0; channel < numSensors; channel++) {
      selectChannel(channel);  // Select Channel on the Active Decoder
    
      // Read Analog Value from Hall Sensor
      int sensorValue = analogRead(hallSensorPin);
      float voltage = sensorValue * (5.0 / 1023.0);  // Convert to Voltage
      Serial.print(voltage);
      Serial.print(" ");
      // Store Sensor State (1 if Beyond Threshold, 0 Otherwise)
      if (voltage > highThreshold) {
        sensorState[decoder][channel] = 1;
      } else if (voltage < lowThreshold) {
        sensorState[decoder][channel] = -1;
      } else {
        sensorState[decoder][channel] = 0;
      }
    }
  }
  disableDecoders();  // Disable All Decoders After Reading
}

// Enable One Decoder Based on Index (0 to 3)
void enableDecoder(int decoder) {
  // Disable All Decoders First
  disableDecoders();
  
  switch (decoder) {
    case 0: digitalWrite(enableDecoder1, LOW); break;
    case 1: digitalWrite(enableDecoder2, LOW); break;
    case 2: digitalWrite(enableDecoder3, LOW); break;
    case 3: digitalWrite(enableDecoder4, LOW); break;
  }
  delay(10);
}

// Disable All Decoders
void disableDecoders() {
  digitalWrite(enableDecoder1, HIGH);
  digitalWrite(enableDecoder2, HIGH);
  digitalWrite(enableDecoder3, HIGH);
  digitalWrite(enableDecoder4, HIGH);
}

// Select a Channel on the Active Decoder (0 to 15)
void selectChannel(int channel) {
  digitalWrite(s0, bitRead(channel, 0));  // LSB
  digitalWrite(s1, bitRead(channel, 1));
  digitalWrite(s2, bitRead(channel, 2));
  digitalWrite(s3, bitRead(channel, 3));  // MSB
}

// Print the Current State of All Sensors
void printSensorState() {
  Serial.println("Sensor States (1 = Active, 0 = Inactive):");
  for (int i = 0; i < numDecoders; i++) {
    Serial.print("Decoder ");
    Serial.print(i + 1);
    Serial.print(": ");
    for (int j = 0; j < numSensors; j++) {
      Serial.print(sensorState[i][j]);
      Serial.print(" ");
    }
    Serial.println();
  }
  Serial.println("-------------------------");
}
