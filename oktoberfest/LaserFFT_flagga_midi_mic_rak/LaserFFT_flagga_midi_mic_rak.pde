import themidibus.*;

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
int pointsPerBand = 3;
// The demonstation has 3 threads, the midi thread, the draw thread and the Etherdream thread
// The ConcurrentHashMaps allow storing data about each received midi pitch, piano key,
// and sharing the data safely with the draw and Etherdream thread.
ConcurrentHashMap<Integer,Integer> pitchVelocityMap = new ConcurrentHashMap<Integer,Integer>();

// We stora a float value for each pitch that is used to fade from key on to key off
// and rapid fade when the key is released, this allows the light to mimic the fade of the sound.
ConcurrentHashMap<Integer,Float> pitchFadeMap = new ConcurrentHashMap<Integer,Float>();

// https://github.com/Notnasiul/R2D2-Processing-Pitch/
int bands = 7;
float[] spectrum = new float[bands*25];

void setup() {
  
  size(512, 360);
  background(255);
  MidiBus.list(); // List all available Midi devices on STDOUT. This will show each device's index and name.

 myBus = new MidiBus(this, 1, 2); // Create a new MidiBus with no input device and the default Java Sound Synthesizer as the output device.
  
  minim = new Minim(this);
  minim.debugOn();

  AS = new AudioSource(minim);
  
  AS.OpenMicrophone();

  //PD = new PitchDetectorFFT();
  //PD.ConfigureFFT(2048, AS.GetSampleRate());
  PD = new PitchDetectorAutocorrelation();  //This one uses Autocorrelation
  //PD = new PitchDetectorHPS(); //This one uses Harmonit Product Spectrum -not working yet-
  PD.SetSampleRate(AS.GetSampleRate());
  AS.SetListener(PD);
  
  ArrayList<Point> p = new ArrayList<Point>();
  for(int i=0; i<10; i++){
      int y = ((laserMax / 10)*i)-mx;
      p.add( new Point(mi,y));
      p.add( new Point(mx,y)); 
  }
  laserpoint = p;
  
    Etherdream laser = new Etherdream(this);
}     

float[] sum = new float[bands*25];
int lasers = bands;
float smoothing = 0.4;

int[] bass = {20, 140};
int[] lowMid = {140, 400};
int[] mid = {400, 2600};
int[] highMid = {2600, 5200};
int[] treble = {5200, 14000};


import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import ddf.minim.signals.*;
import ddf.minim.*;

PitchDetectorAutocorrelation PD; //Autocorrelation
//PitchDetectorHPS PD; //Harmonic Product Spectrum -not working yet-
//PitchDetectorFFT PD; // Naive
AudioSource AS;
Minim minim;

//Some arrays just to smooth output frequencies with a simple median.
float []freq_buffer = new float[bands*25];
float []sorted;
int freq_buffer_index = 0;

long last_t = -1;
float avg_level = 0;
float last_level = 0;
int våg = 0;
void draw() {
  våg+=1;
  
  // midi
  
  
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
  
  
  
  //
  
  
  colorMode(RGB,255);
  background(255);

  float f = 0;
  float level = AS.GetLevel();
  long t = PD.GetTime();
  if (t == last_t) return;
  last_t = t;
  int xpos = (int)t % width;
  if (xpos >= width-1) {
     rect(0,0,width,height);
  }
  
  f = PD.GetFrequency();
  /*
  if(f<60){
    freq_buffer_index = 1;
  } else if(f<100){
    freq_buffer_index = 2;
  } else if(f<200){
    freq_buffer_index = 3;
  } else if(f<300){
    freq_buffer_index = 4;
  } else if(f<350){
    freq_buffer_index = 5;
  } else if(f<400){
    freq_buffer_index = 6;
  } else {
    freq_buffer_index = 7;
  }*/

if(f<55){
    freq_buffer_index = 1;
  } else if(f<88){
    freq_buffer_index = 2;
  } else if(f<99){
    freq_buffer_index = 3;
  } else if(f<190){
    freq_buffer_index = 4;
  } else if(f<230){
    freq_buffer_index = 5;
  } else { 
    freq_buffer_index = 6;
  }
  freq_buffer_index = (int)f%(25*bands);

  freq_buffer[freq_buffer_index] = level*laserMax;
  System.out.println("freq_buffer_index "+freq_buffer_index+" level "+level+" f "+f);  
  ArrayList<Point> p = new ArrayList<Point>();
    
  /*
  for(int i = 1; i < bands; i++){
  // The result of the FFT is normalized
  // draw the line for frequency band i scaling it up by 5 to get more amplitude.
  //fft.spectrum[i+32]
      sum[i] += ( freq_buffer[i] - sum[i]) * smoothing;
      int m=0;
      //for(int j=0;j<7;j++){
      //  m = (int)max(m,spectrum[1+(i*8)+j]*laserMax*j*1234);
      //}
      
      m = (int)(sum[i]*i*10);
      int lsum = mi + m;
      
     // int y = (int)min(lsum,mx2-(mx2/4))+(int)(sin(våg/100.0f)*1000);
     // int x = -(int)(mx/8*0.8)+((laserMax / lasers)*i);
      int y = (int)min(lsum,mx-(mx/4));
      int x = (mx/8)+((laserMax / lasers)*i)-mx;
      color c = numberToColor(i%7);
      colorMode(RGB, on);
      int r=(int) red(c);
      int g=(int) green(c);
      int b=(int) blue(c);
      if(i==1){
        p.add( new Point(x-(laserMax / (lasers)),y)); // blank
      } else {
        p.add( new Point(x-(laserMax / (lasers)),y,r,g,b));
      }
      
      p.add( new Point(x,y,r,g,b)); // color
      
  }*/
 /* 
  int y = mi;
  p.add( new Point(mi+(mx/8),y)); // blank
  for(int i = 1; i < 300; i++){
    
    int x = (mx/8)+((laserMax / 300)*i)-mx;
      
     color c = numberToColor(i%7);
      colorMode(RGB, on);
      int r=(int) red(c);
      int g=(int) green(c);
      int b=(int) blue(c);
       p.add( new Point(x,y,r,g,b)); // color
      
  }*/
  int by = (int)(mx2);//*sin((våg/5.0)/10.0))-mx2/2; 
  p.add( new Point(mi,by/4)); // blank
  
  for(int i = 1; i < 25; i++){
   color c = numberToColor(min(1+(int)i/(25/6),6));
   colorMode(RGB, on);
      int r=(int) red(c);
      int g=(int) green(c);
      int b=(int) blue(c);
   //int y = (int)(mx2*sin((våg/6.0+i)/10.0))-mx2/2; 
   int y = (int)(mx2);//*sin((våg/6.0+i)/2.0))-mx2/2; 
   
      int x = (mx/8)+((laserMax / 25)*i)-mx;
      
      int offset = 0;
    for(Integer k : keys){
        //if((1+k/12)%6==0){
          if(k%25==i){
         
          Float faded = new Float(pitchFadeMap.getOrDefault(k,Float.valueOf(0)).floatValue());
          offset+=100*faded;
        }
     }
     
   /*  for(int i = 1; i < bands; i++){
  // The result of the FFT is normalized
  // draw the line for frequency band i scaling it up by 5 to get more amplitude.
  //fft.spectrum[i+32]
      sum[i] += ( freq_buffer[i] - sum[i]) * smoothing;
      int m=0;
      //for(int j=0;j<7;j++){
      //  m = (int)max(m,spectrum[1+(i*8)+j]*laserMax*j*1234);
      //}
      
      m = (int)(sum[i]*i*10);
      int lsum = mi + m;
      
     // int y = (int)min(lsum,mx2-(mx2/4))+(int)(sin(våg/100.0f)*1000);
     // int x = -(int)(mx/8*0.8)+((laserMax / lasers)*i);
      int y = (int)min(lsum,mx-(mx/4));
      int x = (mx/8)+((laserMax / lasers)*i)-mx;
      color c = numberToColor(i%7);
      colorMode(RGB, on);
      int r=(int) red(c);
      int g=(int) green(c);
      int b=(int) blue(c);
      if(i==1){
        p.add( new Point(x-(laserMax / (lasers)),y)); // blank
      } else {
        p.add( new Point(x-(laserMax / (lasers)),y,r,g,b));
      }
      
      p.add( new Point(x,y,r,g,b)); // color
      
  }*/
  offset+=freq_buffer[i];
     
    p.add( new Point((int)(x*1.5),(y/4)+offset,r,g,b)); 
    
    
  }
  
  
     //List<Integer> keys = Collections.list(pitchVelocityMap.keys());
    /* DACPoint[] result = new DACPoint[pointsPerBand*bands];
    int i = 0;
    
    int numKeys = keys.size();
    int pointsPerKey = pointsPerBand/(numKeys+1);
    for(Integer k : keys){
    
      Float faded = new Float(pitchFadeMap.getOrDefault(k,Float.valueOf(0)).floatValue());
    
      color c = octaveToColor(k/12);
      //27000
      colorMode(RGB, 30000+(k*3));
      int red = (int)red(c);
      int green = (int)green(c);
      int blue = (int)blue(c);
      int offset = 0;
      for(int j=0;j<pointsPerKey;j++){
        int w = 32767;
        
        if (i>300){
          w = (int)(32767/1.5);
          int d = (int)(32767-(32767/1.5)-(32767/2));
          //offset = d*(width/mouseX);
        }
        if(faded!=Float.valueOf(0)){
             result[i] = new DACPoint(((int) (offset+w * Math.sin((i) / 24.0+(((faded+1)/5.0)/10.0)))), (int) (w * Math.cos(i / 24.0)),
             red,     green,     blue);
             p.add(new Point
        }
        i++;
      }
    }*/
  
  
  // visualize a line for each key, colored by the octave
  /*for(Integer k : keys){
    
    Float value = pitchFadeMap.getOrDefault(k,Float.valueOf(0));
    
    if(value!=0){
      stroke(octaveToColor((k/12)));
      //stroke(value);
      noFill();
      strokeCap(SQUARE);
      strokeWeight(value);
      line(width/2,0,width/12*(k%12),height-(8*12)+(12*(k/12)));
    }
  }*/
  
  
  p.add( new Point(mx,by/4)); // blank
  
  
  
  
  
  laserpoint = p;
  
}


  
  
// Laser bounary constants
final int laserMax = 35535;
final int mx = laserMax/2;
final int mi = -mx;
final int mx2 = mx/2;
final int mi2 = mi/2;

// Laser light constants
final int on = 65535;
final int off = 0;

// Convert the screen coordinates 0 to width
// to laser coordinates ranging from 32767 to -32767
int xToLaserX(float x){
  return int((laserMax/width)*x)-mx;
}

// Convert the screen coordinates height to 0
// to laser coordinates ranging from 32767 to -32767
int yToLaserY(float y){
  return int((-laserMax/height)*y)+mx;
}

int yToScreenY(float y){
  float absy = y+mx;
  return int(height-((absy/laserMax)*height));
}

int xToScreenX(float x){
  float absx = x+mx;
  return int((absx/laserMax)*width);
}


// store uncoverted laser points updated by draw()
// to be converted
// when the laser request new points using the getDACPoints
// callback
volatile ArrayList<Point> laserpoint;

// Callback used by Etherdream laser to fetch next points to display
// helper functions to add extra points are found from line 200 and down in this file
DACPoint[] getDACPoints() {
    
    return pointsMinimum(getDACPointsAdjusted(laserpoint.toArray(new Point[0])),600);
}

// Etherdream help functions below to beam lines

import java.util.Queue;
import java.util.List;
import java.util.Collections;

public class Point {
  public final int x, y, r, g, b;
  Point(int x, int y, int r, int g, int b) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;           
  }
  Point(int x, int y) {
     this.x=x;this.y=y;this.r=0;this.g=0;this.b=0;           
  }
}

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

/**
 * Generate more precise laser lines by
 * adding extra points in between
 *
 * mult = 10; float d = 0.066;// round
 * mult = 15; float d = 0.066;// round
 * mult = 20; float d = 0.166;// round
 * mult = 25; float d = 0.14; // looks OK
 * mult = 50; float d = 0.117; // flickery due to reduced draw speed
 * mult = 100; float d = 0.05; // flickery due to reduced draw speed
 * mult = 150; float d = 0.036; // flickery due to reduced draw speed
 */
DACPoint[] getDACPointsLerpAdjusted(Point a, Point p, int mult, float d) {
    //float d = 0.023*mult+0.627;
    DACPoint[] result = new DACPoint[mult];
    int x = a.x;
    int y = a.y;
    int ip=0;
    for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
        
        /*int linearx = a.x+(i*((p.x-a.x)/mult));
        int lineary = a.y+(i*((p.y-a.y)/mult));
        int sx = xToScreenX(linearx);
        int sy = yToScreenY(lineary);
        
        color c = get(sx,sy);
        
       
        //System.out.println("sx "+sx+" sy "+sy+"r"+r);
        
        int r = (int)red(c);
        
        int lr=0;
        if(r>128){
          lr = on;
        } else {
          lr =0;
        }
        
        int g = (int)green(c);
        
        int lg=0;
        if(g>128){
          lg = on;
        } else {
          lg =0;
        }
       
       int b = (int)blue(c);
        
        int lb=0;
        if(b>128){
          lb = on;
        } else {
          lb =0;
        }*/
        
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
      //int l = distance(last,p);
      //System.out.println(l);
      
      // delay adjusted
      //result = concatPoints(result,getDACPointsDelayAdjusted(p,22));
     
      result = concatPoints(result,getDACPointsLinearAdjusted(last,p,20));
     
      //lerp adjusted
      //result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      
     /*
      
      if((l<500)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,5,0.14));
      } else if((l<7000)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,10,0.14));
      } else if((l<13000)&&(l!=0)){
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,15,0.14));
      } else {
          result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      }*/
      
      last = p;
    }
    return result;
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

color numberToColor(Integer o) {
  colorMode(RGB, 255);
  switch(o){
    case 1:
        return color(255,0,0); // red
    case 2:
       return color(255,128,0); // orange
    case 3:
        return color(255,255,0); // yellow
    case 4:
        return color(0,255,0); // green
    case 5:
        return color(0,0,255); // blue
    case 6: 
        return color(255,0,255); // violet
    case 7:
        return color(255,255,255); // white
    default:
        return color(255,0,255);
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
