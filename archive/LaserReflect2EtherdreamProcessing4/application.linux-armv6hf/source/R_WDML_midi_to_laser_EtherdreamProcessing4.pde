// R-WDML (Re-wake the Dead with Musical Light) by Xerxes Rånby 2021
//
// midi using MidiBus to laser using Etherdream DAC
// The MidiBus can be downloaded from processing -> sketch -> import library... -> The MidiBus

import themidibus.*; //Import the library
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Queue;
import java.util.List;
import java.util.Collections;

MidiBus myBus; // The MidiBus

ConcurrentHashMap<Integer,Integer> h = new ConcurrentHashMap<Integer,Integer>();

void setup() {
  
  fullScreen(P3D);
  background(0);

  MidiBus.list(); // List all available Midi devices on STDOUT. This will show each device's index and name.

  // Either you can
  //                   Parent In Out
  //                     |    |  |
  //myBus = new MidiBus(this, 0, 1); // Create a new MidiBus using the device index to select the Midi input and output devices respectively.

  // or you can ...
  //                   Parent         In                   Out
  //                     |            |                     |
  //myBus = new MidiBus(this, "IncomingDeviceName", "OutgoingDeviceName"); // Create a new MidiBus using the device names to select the Midi input and output devices respectively.

  // or for testing you could ...
  //                 Parent  In        Out
  //                   |     |          |
  myBus = new MidiBus(this, 1, 0); // Create a new MidiBus with no input device and the default Java Sound Synthesizer as the output device.
  
  
  Etherdream laser = new Etherdream(this);
}

// Callback used by Etherdream laser to fetch next points to display
DACPoint[] getDACPoints() {
    DACPoint[] result = new DACPoint[600];

    for (int i = 0; i < 600; i++) {

        /* x,y   int min -32767 to max 32767
         * r,g,b int min 0 to max 65535
         *
         * NOTE: TTL r,g,b transistors float from ~26100 to ~26800 up to ~27400
         * this can be used as a hack to output reduced  on
         * when using undimmable TTL laser driver boards
         * 
         * 26800, 26800, 27900  all dimmed  white
         * 26200,     0,     0  only dimmed red
         *     0, 26500,     0  only dimmed green
         *     0,     0, 27400  only dimmed blue
         */

        result[i] = new DACPoint((int) (32767 * Math.sin((i / 24.0))), (int) (32767 * Math.cos(i / 24.0)),
            0,     26800,     0);
   }
   
    List<Integer> keys = Collections.list(h.keys());
  
    h.values();
  
    int i = 0;
    
    int numKeys = keys.size();
    int pointsPerKey = 600/(numKeys+1);
    for(Integer k : keys){
    
      Float value = new Float(h.getOrDefault(k,Integer.valueOf(0)).intValue());
    
      color c = octaveToColor(k/12);
      for(int j=0;j<pointsPerKey;j++){
        if(value!=0){
             result[i] = new DACPoint((int) (32767 * Math.sin((i) / 24.0+((value+1)/10.0))), (int) (32767 * Math.cos(i / 24.0)),
             c,     26800,     0);
        }
        i++;
      }
    }

   
   return result;
}

void draw() {
  background(0);
  
  List<Integer> keys = Collections.list(h.keys());
  
  h.values();
  
  for(Integer k : keys){
    
    Integer value = h.getOrDefault(k,Integer.valueOf(0));
    
    if(value!=0){
      stroke(octaveToColor((k/12)));
      //stroke(value);
      noFill();
      strokeCap(SQUARE);
      strokeWeight(value);
      line(width/2,0,width/12*(k%12),height-(8*12)+(12*(k/12)));
    }
  }
}

void noteOn(int channel, int pitch, int velocity) {
  // Receive a noteOn
  /*println();
  println("Note On:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);*/
  
  h.put(Integer.valueOf(pitch),Integer.valueOf(velocity));
}

void noteOff(int channel, int pitch, int velocity) {
  // Receive a noteOff
  /*
  println();
  println("Note Off:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
  */
  h.put(Integer.valueOf(pitch),Integer.valueOf(0));
}

void controllerChange(int channel, int number, int value) {
  // Receive a controllerChange
  /*  println();
  println("Controller Change:");
  println("--------");
  println("Channel:"+channel);
  println("Number:"+number);
  println("Value:"+value); */
}

void rawMidi(byte[] data) { // You can also use rawMidi(byte[] data, String bus_name)

  myBus.sendMessage((int)(data[0] & 0xF0),0,(int)(data[1] & 0xFF),(int)(data[2] & 0xFF));

}

void delay(int time) {
  int current = millis();
  while (millis () < current+time) Thread.yield();
}

color octaveToColor(Integer o) {
  switch(o){
    case 1:
        return color(255,0,0); // red
    case 2:
        return color(255,128,0); // orange
    case 3:
        return color(255,255,0); // yellow
    case 4:
        return color(128,255,0); // green
    case 5:
        return color(0,255,128); // cyan
    case 6: 
        return color(0,0,255); // blue
    case 7:
        return color(128,0,255); // violet
    default:
        return color(255,0,255);
  }
}
