/*-------------------------
 To Dos
 -------------------------
 
 // Jonas
 Gesten an Processing schicken --> Punch als Test
 Processing soll Gesten erkennen, evtl. zusätzl. Library bzw. selbst gestalten
 siehe auskommentierte Fkt motionRecognized()
 
 Gesten starten und enden je nach Bewegung bzw. Stillstand der Hand/Finger
 
 (leap motion mit LED ring verheiraten)
 
 
 
 
 // Felix
 
 1) Grundlage: Arduino ansprechen - was kann er managen?
 Vor allem, was kriegt der Serielle Port pro Sekunde hin? (Binär-Zerlegung notwendig??!)
 
 Darauf basierend 2 Klassen schreiben:
 
 2a) Bildschirm-Simulation
 Gepimpte LED-Klasse, die Kommandos versteht ("Blinke 2 Sekunden!")
 
 2b) Arduino + Ring
 Gleiche Funktion wie 2A aber auf Arduino
 
 // Notizen 
 
 Timer wenn abgelaufen rückwärts zählen lassen, um User die ÜBerlaufzeit mitzuteilen.
 
 
 */

/*-------------------------
 VARS
 -------------------------*/

// SDKs + libraries
import de.voidplus.leapmotion.*;
import org.gicentre.utils.move.Ease;

/*---- status helpers ----- 
 
 int globalStatus
 // 0 = sleep
 // 1 = animate
 // 2 = listen
 // 3 = run
 // 4 = pause
 
 globalAnimation
 // int globalAnimationDuration = duration of animation sequence, in frames
 // int globalAnimationEndAction = action to trigger on end
 
 Auf Arduino SEite:
 // int globalAnimationType 
 // 0 = fade in + out
 // 1 = blink
 
 globalTimer
 globalTimerStatus 
 // 0 = paused
 // 1 = running
 
 ---------------------------*/

// input
LeapMotion leap;
int leapPunchDetectorDelay;
int leapPunchDelay;
float[] leapHandTracker;
float leapHandHeight;
float leapHandPinch;
float leapHandXPos;
float leapPinchXPosNull;
float leapHandZPos;
float leapPinchZPosNull;
boolean leapHandIsPinched;

// virtual ring setup
float lg_diam;
float lg_rad;
float lg_circ;
float sm_diam;

// leap helpers
int previousPosition = 0;
int currentPosition = 0;
int currentBrightness = 51;

// overall status of the app
int appStateMain = 0; 

// status of the timer
int timerMinutes = 0;
int timerSeconds = 0;
int timerCurrentFrame = 59;

// animation helpers
int animationCounter = 0;
int animationHelper = 0;
LED[] LEDs;


/*-------------------------
 SETUP
 -------------------------*/

void setup() {

  // set the stage
  size(600, 600);
  background(25);
  colorMode(HSB, 255);
  frameRate(60);
  smooth();

  // prepare 60 LEDs
  LEDs = new LED[60];

  // init leap
  leap = new LeapMotion(this).allowGestures();
  leapHandTracker = new float[5];
  leapPunchDelay = leapPunchDetectorDelay = millis();
  leapHandIsPinched = false;

  // create simulaton
  lg_diam =  550; // large circle's diameter
  lg_rad  = lg_diam/2; // large circle's radius
  lg_circ =  PI * lg_diam; // large circumference
  sm_diam = (lg_circ / LEDs.length); // small circle's diameter

  for (int i = 0; i < LEDs.length; ++i) {
    LEDs[i] = new LED(i);
  }

  // set app to "waiting"
  appStateMain = 1;
}

/*-------------------------
 keyboard / punch listener
 -------------------------*/

void keyPressed() {

  if (key == 'p') {
    inputActionHandler("punch");
  }

  if (key == 'o') {
    inputActionHandler("increase");
  }

  if (key == 'l') {
    inputActionHandler("decrease");
  }

  if (key == 'f') {
    inputActionHandler("flick");
  }
}

void setMinutes(int minutes) {
  if (minutes <= 0) {
    timerMinutes = 0;
  } else if (minutes >= 60){
    timerMinutes = 60;
  } else {
    timerMinutes = minutes;
  }
}

void setSeconds(int seconds) {
  if (seconds <= 0) {
    timerSeconds = 0;
  } else if (seconds >= 60){
    timerSeconds = 60;
  } else {
    timerSeconds = seconds;
  }
}

void inputActionHandler(String action) {

  if (action == "increase") {
    if (appStateMain == 3) {
      //increase minutes
      timerMinutes = (timerMinutes >= 60) ? 60 : timerMinutes +1;
    }
    if (appStateMain == 4) {
      //increase seconds
      timerSeconds = (timerSeconds >= 60) ? 60 : timerSeconds +1;
    }
  }

  if (action == "decrease") {
    if (appStateMain == 3) {
      //decrease minutes
      timerMinutes = (timerMinutes <= 0) ? 0 : timerMinutes -1;
    }
    if (appStateMain == 4) {
      //decrease seconds
      timerSeconds = (timerSeconds <= 0) ? 0 : timerSeconds -1;
    }
  }

  if (action == "punch") {

    // usually, punch goes to next higher status (appState Main +1).
    // EXCEPTIONS: 
    // 5 (paused) --> go back to 4 (running)
    // 6 (alarm) --> go back to 2 (startup animation)
    // NOTE:
    // 2 (animation) will end after 1 second and go to 3 (adjust) automatically
    // 4 (running) will end automatically and go to 6 (alam) when counter reaches zero.
    
    if (appStateMain == 5) {
      appStateMain = 4;
    } else if (appStateMain == 6) {
      appStateMain = 2;
    } else {
      appStateMain++;
    }
    }

    if (action == "flick") {

      if (appStateMain == 5 || appStateMain == 6) {
        appStateMain = 3;
      }
    }

    println(">> appStateMain = " + appStateMain);

}

/*-------------------------
 DRAW
 -------------------------*/

void draw() {

  //decide what currently needs to be done
  switch (appStateMain) {
  default:
    //waiting
    printStatus("waiting");
    break;

    // not initialized, do nothing
  case 0:
    printStatus("switched off");
    break;

    // app launched, still do nothing
  case 1:
    printStatus("standby");
    break;

    // device was activated, show startup animation
  case 2:
    printStatus("starting");
    stepStart();
    break;

    // device start completed, wait for time adjustment 
  case 3:
    printStatus("time?");
    stepAdjust();
    break;

    // timer is running (counting backwards)
  case 4:
    printStatus(((timerMinutes < 10) ? "0" : "") + timerMinutes + ":" + ((timerSeconds < 10) ? "0" : "") + timerSeconds);
    stepRun();
    break;

    // timer is paused (holding current time)
  case 5:
    printStatus(((timerMinutes < 10) ? "0" : "") + timerMinutes + ":" + ((timerSeconds < 10) ? "0" : "") + timerSeconds + " - paused");
    break;

    // timer reached 0 and plays alarm
  case 6:
    printStatus("Piep!");
    stepAlarm();
    break;
  }

  /*-------------------------
   INTERACTION
   -------------------------*/
   
   for (Hand hand : leap.getHands()) {
      
      leapHandHeight = hand.getPosition().y;
      leapHandXPos = hand.getPosition().x;
      leapHandZPos = hand.getPosition().z;
      leapHandPinch = hand.getPinchStrength();

   }
   
   
   punchDetector();
}

// permanently check leap motion input for punch gesture
// it saves the height of the stabilizedHand to an array
// in that array, the last 5 positions are kept
// if there is a difference in height >60, this is considered a punch gesture
boolean punchDetector(){
  
  // this should not be checked every frame
  // but only every 10 milliseconds
  
  
  //vorherige zeit < jetzige zeit minus hundert
  //ist die letzte ausführung 100 ms her? -> dann neu! 
  if(leapPunchDetectorDelay < millis() - 200){
    
    leapPunchDetectorDelay = millis();
    
    
      
      for(int i = 4; i >= 0; i--){
        if(i == 0){
          leapHandTracker[i] = leapHandHeight;
          //println(i + " " + leapHandHeight);
        }
        // on position 1-4, store positions of last 4 frames
        else{
          leapHandTracker[i] = leapHandTracker[i-1];
          //println(i + " " + leapHandTracker[i]);
        }
      }
    
    //compare values in the array
    //only if array is fully set
    if(leapHandTracker[4] !=0){
      for (int i=0; i<5; i++){ 
        //der jüngste muss kleiner sein als einer der vorherigen 4
        if(leapHandTracker[0] - 150 > leapHandTracker[i]){
          println("PUNCH!!!!Punch!!!!PUNCH!!!!");
          for (int j=0; j<5; j++){
            leapHandTracker[j] = 0f;
          }
          inputActionHandler("punch");
      }
        }
          
      }
  }
   /* 
    println(" ");
    println("- - - -");
    
    leapPunchDetectorDelay = millis();
    
    for (Hand hand : leap.getHands()) {
      
      PVector handStabilized = hand.getStabilizedPosition();
      
      for(int i = leapHandTracker.length-1; i >= 0; i--){
        // on position 0, store current position
        if(i == 0){
          leapHandTracker[i] = handStabilized.y;
          println(handStabilized.y);
        }
        // on position 1-4, store positions of last 4 frames
        else{
            leapHandTracker[i] = leapHandTracker[i-1];
            println(leapHandTracker[i-1]);
        }
        
        // now that we have the current + the last 4 states in the array
        // check if there is a difference > 60 between any of them
        if(leapHandTracker[i] > handStabilized.y + 60){
          if(leapPunchDelay < millis() - 100){
            println("detected but ignored due to delay.");
          }else{
            println(" ");
            println("!!!!!PUNCH!!!!! > " + leapHandTracker[i] + " <> " + handStabilized.y);
            println(" ");
            // avoid multiple triggering
            leapPunchDelay = millis();
          }
        }
      }
    }
    
    
    
    // remember highest position of hand
    if(leapHandTracker < hand.getStabilizedPosition().y){
      leapHandTracker = hand.getStabilizedPosition().y;
    }
    */
  
  return true;
}

void printStatus(String status) {
  noStroke();
  fill(255);
  rect(0, 0, 120, 20); 
  stroke(153);
  fill(100);
  text(status, 10, 10);
}

/*-------------------------
 FUNCTIONALITY
 -------------------------*/

// wake up animation
// this is called every frame as long as appStateMain == 2
void stepStart() {

  // animatonCounter is helper variable
  // if 0, animation was just started
  if (animationCounter == 0) {
    animationCounter = 1;
  }
  // if other then 0, calculate what to display
  else {
    // let this run for 1 second
    if (animationCounter <= 60) {
      animationCounter++;

      // animationHelper increases from 0 to 255 in 60 steps:
      animationHelper = int(lerp(0, 255, (float)animationCounter/60));

      for (int j = 0; j < 60; j++) {
        LEDs[j].setColor(animationHelper, 255, 255);
      }
    }
    // after 1 second, go to appStateMain 3 (adjusting minutes)
    else {
      println("reached end of startup animation");
      animationCounter = 0;
      appStateMain = 3;
    }
  }
}

// feedback for adjustment of minutes and seconds
// this is called every frame as long as appStateMain is 3 (minutes) or 4 (seconds)
void stepAdjust() {

  /*
  int currentColor = 0;
   int currentlyAdjusting = timerMinutes;
   
   // make this work for seconds and minutes
   if(appStateMain == 3){
   currentlyAdjusting = timerMinutes;
   currentColor = 255; //(red for minutes)
   }
   
   if(appStateMain == 4){
   currentlyAdjusting = timerSeconds;
   currentColor = 200; //(green for seconds)
   }
   
   // LEDs 0 to x draw colorful
   for (int i = 0; i < currentlyAdjusting; i++) {
   LEDs[i].setColor(currentColor, 255, 255);
   }
   
   // LEDs x to 60, draw white
   for (int j = currentlyAdjusting; j < 60; j++) {
   LEDs[j].setToWhite();
   }
   */
    
  // if hand is in pinched gesture
  if(leapHandPinch >= 0.9){
    
    // if reference coordinates were set already
    if(leapHandIsPinched) {
      
      int Ztemp = (int)(leapHandZPos - leapPinchZPosNull);
      int Xtemp = (int)(leapHandXPos - leapPinchXPosNull);
      
      println (Xtemp);
      
      setSeconds((int)(Ztemp*1.8));
      setMinutes((int)(Xtemp/3.5));
      
      //setSeconds((int)map(Ztemp, -80, 80, 0, 59));
      //setMinutes((int)map(Xtemp, 200, 800, 0, 59));
    }
    
    // if pinch just happened, set coordinates
    else{
      leapHandIsPinched = true;
      leapPinchZPosNull = leapHandZPos;
      leapPinchXPosNull = leapHandXPos;
    }
  }else{
    leapHandIsPinched = false;
  }

  

  drawTimeOnRing();
  //background(255);
}

public void listen() {
  // do nothing, wait for hand input
}

// showing the remaining time on the ring
// this is called every frame as long as appStateMain is 4 (running) or 5 (paused)
public void stepRun() {

  if (appStateMain == 4) {
    timerCurrentFrame--;
    if (timerCurrentFrame < 0) {
      timerCurrentFrame = 59;
      timerSeconds--;
      if (timerMinutes == 0 && timerSeconds == 0) {
        appStateMain = 6;
      } 
      if (timerSeconds < 0) {
        timerSeconds = 59;
        timerMinutes--;
      }
    }
  }

  drawTimeOnRing();
}

// alarm function to call when countdown reached 0
// this is called every frame as long as appStatemain is 6

public void stepAlarm() {

  // animatonCounter is helper variable
  // if 0, animation was just started
  if (animationCounter == 0) {
    animationCounter = 1;
  }
  // if other then 0, calculate what to display
  else {
    // let this run repeatedly for 1 second
    if (animationCounter <= 60) {
      animationCounter++;

      // animation increases from 0 to 255 in 60 steps:
      animationHelper = int(lerp(0, 255, (float)animationCounter/60));

      //draw full circle
      for (int i = 0; i < 60; i++) {
        LEDs[i].setColor(255, animationHelper, 255);
      }
    }
    //repeat after 1s
    if (animationCounter >= 60) {
      animationCounter = 1;
    }
  }
}



/*
-------
 LEAP
 -------
 */
 
 
void leapOnSwipeGesture(SwipeGesture g, int state) {
  int     id               = g.getId();
  Finger  finger           = g.getFinger();
  PVector position         = g.getPosition();
  PVector positionStart    = g.getStartPosition();
  PVector direction        = g.getDirection();
  float   speed            = g.getSpeed();
  long    duration         = g.getDuration();
  float   durationSeconds  = g.getDurationInSeconds();

  switch(state) {
  case 1: // Start
    break;
  case 2: // Update
    break;
  case 3: // Stop
    println("SwipeGesture: " + id);
    inputActionHandler("flick");
    break;
  }
}



// DISPLAY ONLY
// --> this function does not modify ANY variables
void drawTimeOnRing(){
  
  //draw color for minutes 
  for (int i = 0; i < timerMinutes; i++) {
    LEDs[i].setColor(0, 255, 255);
  }
  
  // if adjusting, for rest of ring, adjust according to dropzone accuracy
  currentBrightness = 51;
  
  if(appStateMain == 3){
    
    if(leapHandHeight < 400 && leapHandHeight > 200){
      if (leapHandHeight > 300){
        currentBrightness = (int)map(leapHandHeight,301,400,255,51);
        }
        else {
          currentBrightness = (int)map(leapHandHeight,200,301,51,255);
        }
      }
  }
  
  for (int j = timerMinutes; j < 60; j++) {
    LEDs[j].setColor(0, 0, currentBrightness);
  }
  
  // timerSeconds
  // when running, at least 1 minute left, for example 6:42 ?
  // --> draw 6 red LEDs for minutes (permanently)
  // --> draw 1 single green LED at position 42 for seconds
  if (timerMinutes <= 0 && (appStateMain == 4 || appStateMain == 5)) {
    
    for (int j = 0; j < timerSeconds; j++) {
      LEDs[j].setColor(100, 255, 255);
    }
    
    for (int j = timerSeconds; j < 60; j++) {
      LEDs[j].setColor(0, 0, currentBrightness);
    }
  }else{
    LEDs[timerSeconds].setColor(100, 255, 255);
  }
    
  // when running, draw cool pointer for current 1/60 second
  if(appStateMain == 4){
    LEDs[timerCurrentFrame].setColor(120, 255, 255);
  }


}