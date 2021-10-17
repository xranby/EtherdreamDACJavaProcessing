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

// The demonstation has 3 threads, the midi thread, the draw thread and the Etherdream thread
// The ConcurrentHashMaps allow storing data about each received midi pitch, piano key,
// and sharing the data safely with the draw and Etherdream thread.
ConcurrentHashMap<Integer,Integer> pitchVelocityMap = new ConcurrentHashMap<Integer,Integer>();

// We stora a float value for each pitch that is used to fade from key on to key off
// and rapid fade when the key is released, this allows the light to mimic the fade of the sound.
ConcurrentHashMap<Integer,Float> pitchFadeMap = new ConcurrentHashMap<Integer,Float>();

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

int mi = -12767;
int mx = 12767;

// Callback used by Etherdream laser to fetch next points to display
DACPoint[] getDACPoints() {
    DACPoint[] result = new DACPoint[2000];
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
    for (int i = 0; i < 500; i++) {
        result[i] = new DACPoint(mi, mx,
            27800,     0,     0);
    }
    for (int i = 500; i < 1000; i++) {
        result[i] = new DACPoint(mi, mi,
            0,     27800,     0);
    }
   for (int i = 1000; i < 1500; i++) {
        result[i] = new DACPoint(mx, mi,
            27800,     27800,     0);
    }
    for (int i = 1500; i < 2000; i++) {
        result[i] = new DACPoint(mx, mx,
            0,     0,     27800);
    }
   /*
    List<Integer> keys = Collections.list(pitchVelocityMap.keys());
  
    int i = 0;
    
    int numKeys = keys.size();
    int pointsPerKey = 600/(numKeys+1);
    for(Integer k : keys){
    
      Float faded = new Float(pitchFadeMap.getOrDefault(k,Float.valueOf(0)).floatValue());
    
      color c = octaveToColor(k/12);
      colorMode(RGB, 27800+(k*3));
      int red = (int)red(c);
      int green = (int)green(c);
      int blue = (int)blue(c);
      for(int j=0;j<pointsPerKey;j++){
        if(faded!=Float.valueOf(0)){
             result[i] = new DACPoint((int) (32767 * Math.sin((i) / 24.0+(((faded+1)/5.0)/10.0))), (int) (32767 * Math.cos(i / 24.0)),
             red,     green,     blue);
        }
        i++;
      }
    }

   */
   return result;
}

void draw() {
  background(0);
  
  List<Integer> keys = Collections.list(pitchVelocityMap.keys());
  
  // fade down to zero after key hit
  for(Integer k : keys){
    Float value = pitchFadeMap.getOrDefault(k,Float.valueOf(0));
    Integer on = pitchVelocityMap.getOrDefault(k,Integer.valueOf(0));
    if(on>0){
      value=max(value-0.001*(k+1),0);
    } else {
      value=max(value-(1.2+(k/20.0)),0);
    }
    pitchFadeMap.put(k,value);
  }
  
  // visualize a line for each key, colored by the octave
  for(Integer k : keys){
    
    Float value = pitchFadeMap.getOrDefault(k,Float.valueOf(0));
    
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
  
  pitchVelocityMap.put(Integer.valueOf(pitch),Integer.valueOf(velocity));
  pitchFadeMap.put(Integer.valueOf(pitch),Float.valueOf((float)velocity));
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
  pitchVelocityMap.put(Integer.valueOf(pitch),Integer.valueOf(0));
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

  // forward incomming midi in to midi out
  if(data.length>=3){
    myBus.sendMessage((int)(data[0] & 0xF0),0,(int)(data[1] & 0xFF),(int)(data[2] & 0xFF));
  }
  
  if(data.length==2){
    myBus.sendMessage((int)(data[0] & 0xF0),0,(int)(data[1] & 0xFF));
  }
}

color octaveToColor(Integer o) {
  colorMode(RGB, 255);
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
