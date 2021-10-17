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
PFont f;
volatile int lastK = 1;

void setup() {

  fullScreen(P3D);
  background(0);

  f = createFont("Arial",16,true); 

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

int mi = -32767;
int mx = 32767;
int on = 65535;
int off = 0;

public class Point {
  public final int x, y, r, g, b;
  Point(int x, int y, int r, int g, int b) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;           
  }
}


//int mult = 10; float d = 0.066;// round
//int mult = 15; float d = 0.066;// round
//int mult = 20; float d = 0.166;
//int mult = 25; float d = 0.14;
//int mult = 50; float d = 0.117;
int mult = 100; float d = 0.05;
//int mult = 150; float d = 0.036;

DACPoint[] getDACPointsAdjusted(Point[] points) {
    DACPoint[] result = new DACPoint[points.length*mult];
    int x = points[points.length-1].x;
    int y = points[points.length-1].y;
    int ip=0;
    for(Point p: points){
      for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
        result[ip] = new DACPoint(x, y,
            p.r,     p.g,     p.b);
        ip++;
      }
    }
    return result;
}
  
DACPoint[] pointsMinimum(DACPoint[] p,int minimum) {
  
  if(p.length>=minimum){
      return p;
  }
    
    if(p.length<=(minimum/2)){
      return pointsMinimum(concatPoints(p,p),minimum);
    }
    
    if(p.length<=(minimum/3)){
      return pointsMinimum(concatPoints(p,p,p),minimum);
    }
    
    return pointsMinimum(concatPoints(p,p,p,p),minimum);
    
}

DACPoint[] concatPoints(DACPoint[]... arrays) {
        // Determine the length of the result array
        int totalLength = 0;
        for (int i = 0; i < arrays.length; i++) {
            totalLength += arrays[i].length;
        }

        // create the result array
        DACPoint[] result = new DACPoint[totalLength];

        // copy the source arrays into the result array
        int currentIndex = 0;
        for (int i = 0; i < arrays.length; i++) {
            System.arraycopy(arrays[i], 0, result, currentIndex, arrays[i].length);
            currentIndex += arrays[i].length;
        }

        return result;
}

// Callback used by Etherdream laser to fetch next points to display
DACPoint[] getDACPoints() {
  
    Point[] p = new Point[10];
    p[0] = new Point(mx,mx,on,0,0);
    p[1] = new Point(mx,mi,0,on,0);
    p[2] = new Point(mi,mi,on,on,0);
    p[3] = new Point(mi,mx,0,0,on);
    
    p[4] = new Point(mi/2,mx/2,0,0,0);   
   
    p[5] = new Point(mx/2,mx/2,on,0,0);
    p[6] = new Point(mx/2,mi/2,0,on,0);
    p[7] = new Point(mi/2,mi/2,on,on,0);
    p[8] = new Point(mi/2,mx/2,0,0,on);
    
    p[9] = new Point(mi,mx,0,0,0);
    
    return pointsMinimum(getDACPointsAdjusted(p),600);
}

void draw() {
  background(0);
  
  d=(float)mouseY/(((float)height));
  //ppp=(float)mouseX/(((float)width/3.0));
  
  textFont(f);
  textAlign(CENTER);
  text("d="+d,width/2,60);
  
  
  text("lastK="+lastK,width/2,180); 

  
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
  lastK = pitch-20;
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
