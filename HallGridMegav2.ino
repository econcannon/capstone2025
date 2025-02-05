//2/5/25 Fuentes group 3 Jeremy Gagnon

const int rowZero = 38;
const int rowOne = 40;
const int rowTwo = 42;
const int rowThree = 44;
const int rowFour = 46;
const int rowFive = 48;
const int rowSix = 50;
const int rowSeven = 52;

const int colZero = A0;
const int colOne = A1;
const int colTwo = A2;
const int colThree = A3;
const int colFour = A4;
const int colFive = A5;
const int colSix = A6;
const int colSeven = A7;

const int lowerThresh = 450;
const int upperThresh = 550; 

void setup() {

    pinMode(rowZero, OUTPUT);
    pinMode(rowOne, OUTPUT);
    pinMode(rowTwo, OUTPUT);
    pinMode(rowThree, OUTPUT);
    pinMode(rowFour, OUTPUT);
    pinMode(rowFive, OUTPUT);
    pinMode(rowSix, OUTPUT);
    pinMode(rowSeven, OUTPUT);

    pinMode(colZero, INPUT);
    pinMode(colOne, INPUT);
    pinMode(colTwo, INPUT);
    pinMode(colThree, INPUT);
    pinMode(colFour, INPUT);
    pinMode(colFive, INPUT);
    pinMode(colSix, INPUT);
    pinMode(colSeven, INPUT);
    
    Serial.begin(9600);  // Start serial communication for debugging
    Serial.println("Initialized");
}

void setVoltage(int value) {
    digitalWrite(rowZero, LOW);
    digitalWrite(rowOne, LOW);
    digitalWrite(rowTwo, LOW);
    digitalWrite(rowThree, LOW);
    digitalWrite(rowFour, LOW);
    digitalWrite(rowFive, LOW);
    digitalWrite(rowSix, LOW);
    digitalWrite(rowSeven, LOW);
    delay(10);
    //Serial.println("Set all voltages OFF");

    switch (value) {
        case 0: digitalWrite(rowZero, HIGH); break;
        case 1: digitalWrite(rowOne, HIGH); break;
        case 2: digitalWrite(rowTwo, HIGH); break;
        case 3: digitalWrite(rowThree, HIGH); break;
        case 4: digitalWrite(rowFour, HIGH); break;
        case 5: digitalWrite(rowFive, HIGH); break;
        case 6: digitalWrite(rowSix, HIGH); break;
        case 7: digitalWrite(rowSeven, HIGH); break;
    }
    delay(10);
}

float readCol(int value) {
    //Serial.println("Reading:");
    float val = -1;  // Default value in case of error
    analogRead(A8);
    delayMicroseconds(50);
    switch (value) {
        case 0: val = analogRead(colZero); break;
        case 1: val = analogRead(colOne); break;
        case 2: val = analogRead(colTwo); break;
        case 3: val = analogRead(colThree); break;
        case 4: val = analogRead(colFour); break;
        case 5: val = analogRead(colFive); break;
        case 6: val = analogRead(colSix); break;
        case 7: val = analogRead(colSeven); break;
    }
    return val;
}


void loop() {
    float sensorValue;
    //Serial.println("LOOP START");

    for (int i = 0; i < 8; i++) {
        
        setVoltage(i);
        //Serial.print("Setting row: ");
        //Serial.println(i);
        delay(5);
        
        for (int j = 0; j < 8; j++) {           
            //Serial.print("Reading with i ");
            //Serial.print(i);   
            //Serial.print(" j: ");
            //Serial.println(j);
            delay(50);
            sensorValue = readCol(j);  // Read sensor
            //Serial.println(sensorValue);
           
            if (sensorValue > upperThresh) {
                Serial.print("Black piece detected at: (");
                Serial.print(i);
                Serial.print(", ");
                Serial.print(j);
                Serial.print(")");
                Serial.print(" Val: ");
                Serial.println(sensorValue);
            }
            
            else {
                //Serial.println("Nothing");

                //Serial.print("Nothing at (");
                //Serial.print(i);
                //Serial.print(", ");
                //Serial.print(j);
                //Serial.println(")");
            }
            
            
            //Serial.println("step done");
        }
        //Serial.println("for loop done");
    }

    delay(10);  // Small delay for stability
}
