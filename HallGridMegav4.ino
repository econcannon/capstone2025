f//2/5/25 Fuentes group 3 Jeremy Gagnon

#include <LiquidCrystal.h>

const int rowOne = 22;
const int rowTwo = 24;
const int rowThree = 26;
const int rowFour = 28;
const int rowFive = 30;
const int rowSix = 32;
const int rowSeven = 34;
const int rowEight = 36;

const int rs = 6, en = 9, d4 = 2, d5 = 3, d6 = 4, d7 = 5;


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

LiquidCrystal lcd(rs, en, d4, d5, d6, d7);


void setup() {
    pinMode(rowEight, OUTPUT);
    pinMode(rowOne, OUTPUT);
    pinMode(rowTwo, OUTPUT);
    pinMode(rowThree, OUTPUT);
    pinMode(rowFour, OUTPUT);
    pinMode(rowFive, OUTPUT);
    pinMode(rowSix, OUTPUT);
    pinMode(rowSeven, OUTPUT);
    
    Serial.begin(9600);  // Start serial communication for debugging
    lcd.begin(16, 2);
    lcd.print("Initialized");
    Serial.println("Initialized");
}

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

float read_hall_col(int value) {
    //Serial.println("Reading:");
    float val = -1;  // Default value in case of error
    analogRead(A8);
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

void scan_sensor_vals() {
    float sensorValue;
    for (int i = 8; i > 0; i--) {  // Start from row 7 down to 0
        setVoltage(i);
        delay(5);  // Allow time for stabilization
        
        for (int j = 1; j < 9; j++) {
            sensorValue = readCol(j) / 100;  // Read sensor value
            Serial.print(sensorValue);
            Serial.print("\t");  // Use tab spacing for readability
        }
        Serial.println();  // New line after each row
    }
    Serial.println("----------------------");  // Separate scans visually
}

void scan_grid_detect_pieces() {
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
                Serial.print("Black piece detected at: (");
                // return piece information here
                Serial.print(i);
                Serial.print(", ");
                Serial.print(j);
                Serial.print(")");
                Serial.print(" Val: ");
                Serial.println(sensorValue);

                lcd.print("Black @ (");
                lcd.print(i);
                lcd.print(", ");
                lcd.print(j);
                lcd.print(")");
                lcd.print(" Val: ");
                lcd.println(sensorValue);
            }
            else if (sensorValue < lowerThresh & sensorValue >= 100) {
                Serial.print("White piece detected at: (");
                // return piece information here
                Serial.print(i);
                Serial.print(", ");
                Serial.print(j);
                Serial.print(")");
                Serial.print(" Val: ");
                Serial.println(sensorValue);

                lcd.print("White @ (");
                lcd.print(i);
                lcd.print(", ");
                lcd.print(j);
                lcd.print(")");
                lcd.print(" Val: ");
                lcd.println(sensorValue);
            }

            else {
                //Serial.print("Nothing - ");

                //Serial.print("Nothing at (");
                //Serial.print(i);
                //Serial.print(", ");
                //Serial.print(j);
                //Serial.println(")");
                //Serial.print(" Val: ");
                //Serial.println(sensorValue);
            }
            
            
            //Serial.println("step done");
        }
        //Serial.println("for loop done");
    }

    //delay(10);  // Small delay for stability
}

void loop(){
  scan_sensor_vals();
  scan_grid_detect_pieces();
}