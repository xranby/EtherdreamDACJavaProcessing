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

int max = 65535;
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
//int mult = 20; float d = 0.166;// rounf
int mult = 25; float d = 0.14;
//int mult = 50; float d = 0.117;
//int mult = 100; float d = 0.05;
//int mult = 150; float d = 0.036;


DACPoint[] getDACPointsDelayAdjusted(Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    }
    return result;
}

DACPoint[] getDACPointsLinearAdjusted(Point a, Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(a.x+(i*((p.x-a.x)/mult)), a.y+(i*((p.y-a.y)/mult)),
            p.r,     p.g,     p.b);
    }
    return result;
}

DACPoint[] getDACPointsLerpAdjusted(Point a, Point p, int mult, float d) {
    //float d = 0.023*mult+0.627;
    DACPoint[] result = new DACPoint[mult];
    int x = a.x;
    int y = a.y;
    int ip=0;
    for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
//color c = octaveToColor(i%7);
//colorMode(RGB,max);
// result[ip] = new DACPoint(x, y,
//            (int)red(c),     (int)green(c), (int)blue(c));
        result[ip] = new DACPoint(x, y,
            p.r,     p.g,     p.b);
        ip++;
    }
    return result;
}

DACPoint[] getDACPoints(Point p) {
    DACPoint[] result = new DACPoint[1];
    result[0] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    return result;
}

int distance(Point a, Point b) {
  return (int)sqrt(((a.x-a.y)*(a.x-a.y))+((b.x-b.y)*(b.x-b.y)));
}

DACPoint[] getDACPointsAdjusted(Point[] points) {
    DACPoint[] result = new DACPoint[0];
    Point last = points[points.length-1];
    for(Point p: points){
      int l = distance(last,p);
      System.out.println(l);
      
      // delay adjusted
      //result = concatPoints(result,getDACPointsDelayAdjusted(p,22));
     
      //result = concatPoints(result,getDACPointsLinearAdjusted(last,p,20));
     
      //lerp adjusted
      result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      
     
      /*
      if((l<500)&&(l!=0)){
          result = concatPoints(result,getDACPointsDelayAdjusted(p,1));
      } else if((l<2000)&&(l!=0)){
          result = concatPoints(result,getDACPointsDelayAdjusted(p,6));
      } else if((l<7000)&&(l!=0)){
          result = concatPoints(result,getDACPointsLinearAdjusted(last,p,20));
      } else {
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      }*/
      
      last = p;
    }
    return result;
}
  
DACPoint[] pointsMinimum(DACPoint[] p,int minimum) {
  
  if(p.length>=minimum){
      return p;
  }
  
  if(p.length<=(minimum/4)){
      return pointsMinimum(concatPoints(p,p,p,p),minimum);    
  }
  
  if(p.length<=(minimum/3)){
      return pointsMinimum(concatPoints(p,p,p),minimum);
  }
  
  return pointsMinimum(concatPoints(p,p),minimum);  
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
  
  ArrayList<Point> p = new ArrayList<Point>();
  p.add( new Point(mx,mx,on,0,0) );
  p.add( new Point(mx,mi,0,on,0) );
  p.add(  new Point(mi,mi,on,on,0) );
  p.add(  new Point(mi,mx,0,0,on) );
    
 p.add(  new Point(mi/2,mx/2,0,0,0) );   // blank line
   
 p.add(  new Point(mx/2,mx/2,on,0,0) );
 p.add( new Point(mx/2,mi/2,0,on,0) );
 p.add( new Point(mi/2,mi/2,on,on,0) );
 p.add( new Point(mi/2,mx/2,0,0,on) );
    
    p.add(  new Point(mi/4,mx/4,0,0,0) );   // blank line
   
    p.add(  new Point(mx/4,mx/4,on,0,0) );
    p.add(  new Point(mx/4,mi/4,0,on,0) );
    p.add(  new Point(mi/4,mi/4,on,on,0) );
    p.add(  new Point(mi/4,mx/4,0,0,on) );
    
    p.add(  new Point(mi/10,mx/10,0,0,0) );   // blank line
   
    p.add(  new Point(mx/10,mx/10,on,0,0) );
    p.add(  new Point(mx/10,mi/10,0,on,0) );
    p.add(  new Point(mi/10,mi/10,on,on,0) );
    p.add(  new Point(mi/10,mx/10,0,0,on) );
    
    p.add(  new Point(mi/20,mx/20,0,0,0) );   // blank line
   
    p.add(  new Point(mx/20,mx/20,on,0,0) );
    p.add(  new Point(mx/20,mi/20,0,on,0) );
    p.add(  new Point(mi/20,mi/20,on,on,0) );
    p.add(  new Point(mi/20,mx/20,0,0,on) );
    
    p.add(  new Point(mi/40,mx/40,0,0,0) );   // blank line
   
    p.add(  new Point(mx/40,mx/40,on,0,0) );
    p.add(  new Point(mx/40,mi/40,0,on,0) );
    p.add(  new Point(mi/40,mi/40,on,on,0) );
    p.add(  new Point(mi/40,mx/40,0,0,on) );
    
    p.add(  new Point(mi/80,mx/80,0,0,0) );   // blank line
   
    p.add(  new Point(mx/80,mx/80,on,0,0) );
    p.add(  new Point(mx/80,mi/80,0,on,0) );
    p.add(  new Point(mi/80,mi/80,on,on,0) );
    p.add(  new Point(mi/80,mx/80,0,0,on) );
    
    p.add(  new Point(mi,mx,0,0,0) );      // blank line
    
    p.add(  new Point(mi,mx,0,0,0) );      // blank line
    
    return pointsMinimum(getDACPointsAdjusted(p.toArray(new Point[0])),600);
}

void draw() {
  background(0);
  
  d=1+((float)mouseY/(((float)height)));
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
