/* Author: Willi Müller License: Do what you want with it, just please mention my
name and notify me

####--------Deutsch----------#### Dies ist der Code für eine Aquarium-Station auf
Basis eines Arduino. Sie misst die Temperatur im Aquarium und schaltet über eine
Funksteckdose z.B. die Heizung. Außerdem gehört auch noch eine automatische
Fütterungs-Anlage (Schrittmotor) und ein Display zur Station.

 Eine Anleitung zum Nachbauen bzw. eine Dokumentation der Hardware ist im Wiki
(http://wiki.github.com/jups23/Aquarium_Station/) zu finden. Hinweis: Elektrischer
Strom kann gefährlich sein! Ich kann nicht garantieren, dass Code und Schaltungen
einwandfrei funktionieren – es ist mein erstes Projekt ;-)

####--------English----------#### This is the code for an Arduino controlling one
wireless power supply via a hijacked remote. In addition it measures the
temperature, controls a stepper motor and a 2x20 LCD display. It is used to
control a fish tank. The temperature sensor is used to, well, measure the
temperature, the heating is attached to the wireless power supply so the Arduino
can turn it on and off. The steppert motor adds automatic feeding to this little
station.

Since I use it in German, every string which is printed on the LCD is in German.
The English translation could be found in the given comments. A clear assembly
tutorial in English is in the works. The schematic and a German tutorial could be
found in the wiki of this project
(http://wiki.github.com/jups23/Aquarium_Station/)

I can guarantee for nothing - this is my first Hardware project ;-) */

#include <ShiftLCD.h>
/*Thanks to Chris Parish for this Library available at http://cjparish.blogspot.com/2010/01/controlling-lcd-display-with-shift.html*/
//#include <LiquidCrystal.h>	//in case of no shift register/wenn ohne Schieberegister 

int sensorInputPin = 0;
int offPin =  12;  //triggers the remote to turn the power plug off 
int onPin = 13;	//triggers the remote to turn the power plug on
ShiftLCD lcd(6,3,5);	//with shift register/mit Schieberegister
//LiquidCrystal lcd(7,11,10,5,4,3,2);	//in case of no shift register/wenn ohne Schieberegister 
int motorEnable = 2;
int motorPin1 = 9;
int motorPin2 = 8;
int motorDelay = 50;
int sensorValue = 0;
int end=50; //number of measured temperature values
int hoursStart = 19, minutesStart = 50;//insert current time
unsigned long timeStart = 0, time = 0;
int hours = 0, minutes = 0, seconds = 0, milliseconds = 0;
int hoursFeed=19, minutesFeed=55;	//insert feeding time
float temp=0;    //current temperature
float span=1;    //span between tempMin und tempMax
float tempOpt=28, tempDay=28, tempNight=28;	
float tempMax, tempMin;
int requests=0;
int mode=0; //0=>'day', 1=>'night'
  int state = 0; //0=>'Heating on', 1=>'Heating off'


void setup() {
  pinMode(onPin, OUTPUT);  
  pinMode(offPin, OUTPUT); 
  pinMode(motorEnable, OUTPUT);
  pinMode(motorPin1, OUTPUT);
  pinMode(motorPin2, OUTPUT);
  analogReference (INTERNAL);
  lcd.begin(2,20);              // rows, columns.  use 2,16 for a 2x16 LCD, etc.
  lcd.clear();                  // start with a blank screen
}

void turn_on () {
  digitalWrite(onPin, HIGH);   
  delay(500);                  
  digitalWrite(onPin, LOW); 
  lcd.setCursor(0,0);
  lcd.print("Heizung ein"); //En: Heating on
}

void turn_off() {
  digitalWrite(offPin, HIGH);
  delay(500);
  digitalWrite(offPin, LOW);
  lcd.setCursor(0,0);
  lcd.print("Heizung aus"); //En: Heating off
}

void time_calc () {
  time = millis()+timeStart;
  hours = (time / 3600000) % 24;
  if ((hours>=0) && (hours<=7)) { mode=0;} 
  else mode=1;
  minutes = (time % 3600000)/60000;
  seconds = ((time % 3600000) % 60000) / 1000;
  milliseconds = time % 1000;
	lcd.setCursor(0,0); 
  if (state==1) {lcd.print("Heizung ein    ");}
	if (state==0) {lcd.print("Heizung aus    ");}
  lcd.print(hours); 
  lcd.print(":"); 
  lcd.print(minutes);
}

int measure () {
  for (int i=0; i<end; i++) {sensorValue += analogRead(sensorInputPin);}
  sensorValue/=end;
} 

float temp_calc (){
  float tempPrev=0;    //previous temperature
  temp = (100*1.1*sensorValue)/1024;
  if (temp != tempPrev) {
    time_calc();
    Serial.print(sensorValue); 
    Serial.print (" = "); 
    Serial.print(temp); 
    Serial.println("C");
    lcd.setCursor(0,1); 
    lcd.print("T:"); 
    lcd.print(temp);
    lcd.print(" Futter "); //En: Feeding
    lcd.print(hoursFeed); 
    lcd.print(":"); 
    lcd.print(minutesFeed);	
  }
  tempPrev=temp;
}

void four_steps_backwards(){
  digitalWrite(motorPin1, HIGH); 
  digitalWrite(motorPin2, HIGH); 
  delay(motorDelay);
  digitalWrite(motorPin1, LOW);  
  digitalWrite(motorPin2, HIGH); 
  delay(motorDelay);
  digitalWrite(motorPin1, LOW);  
  digitalWrite(motorPin2, LOW); 	
  delay(motorDelay);
  digitalWrite(motorPin1, HIGH); 
  digitalWrite(motorPin2, LOW); 	
  delay(motorDelay);
}

void four_steps_forwards(){
  digitalWrite(motorPin1, LOW);  
  digitalWrite(motorPin2, HIGH); 
  delay(motorDelay);
  digitalWrite(motorPin1, HIGH); 
  digitalWrite(motorPin2, HIGH); 
  delay(motorDelay);
  digitalWrite(motorPin1, HIGH); 
  digitalWrite(motorPin2, LOW); 	
  delay(motorDelay);
  digitalWrite(motorPin1, LOW);  
  digitalWrite(motorPin2, LOW); 	
  delay(motorDelay);
}

void feed_check() {
  requests++;	//prevent more than one feeding per minute
  if ((requests > 65) && (minutes == minutesFeed) && (hours==hoursFeed))  {
    lcd.setCursor(0,1); 
    lcd.print("     Fuetterung!    ");	//En: Currently feeding
    digitalWrite(motorEnable, HIGH);
		for (int i=0; i<5;i++) {four_steps_backwards();} 
    delay(3000);
    for (int i=0; i<5; i++) {four_steps_forwards();}
    digitalWrite(motorEnable, LOW);
    requests=0;		
    minutesFeed+=5;	//this provides a feeding every 5 minutes; please edit
    if (minutesFeed == 60){
      minutesFeed=0;
      hoursFeed+=1;
    }
  }
}

void day_night() {
  if (mode==0) {
    tempOpt=tempDay; 
  }
  if (mode==1) {
    tempOpt=tempNight;
  }
  tempMax=tempOpt + span/2;
  tempMin=tempOpt - span/2;
}

void startup() {
  digitalWrite(motorEnable, LOW);  
  lcd.setCursor(0,0); 
  lcd.print("O HAI, I CAN HAZ LCD");
  day_night();
  lcd.setCursor(0,1); 
  lcd.print("T_o:"); 
  lcd.print(tempOpt);
  lcd.print(" Spanne:"); //en: Span:
  lcd.print(span); 
  delay(3000);
  lcd.clear();
  turn_on();
	timeStart = hoursStart*3600000 + minutesStart*60000;
  delay(2000); // to protect remote and receiver
}

void loop () {
  startup();
  while (1<2) {
    delay(1000);
    measure();
    temp_calc();
    feed_check();
    day_night();
    if (temp > tempMax && state == 0) {
      turn_off();
      state=1;
    }
    else if (temp < tempMin && state == 1) {
      turn_on(); 
      state=0;
    }
  }
}

