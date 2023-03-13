/**
 * Flocking 
 * by Daniel Shiffman.  
 * 
 * An implementation of Craig Reynold's Boids program to simulate
 * the flocking behavior of birds. Each boid steers itself based on 
 * rules of avoidance, alignment, and coherence.
 * 
 * Click the mouse to add a new boid.
 *
 * Added support for Etherdream laser output
 * by Xerxes Rånby
 */

Flock flock;

void setup() {
  size(640,640);
  flock = new Flock();
  // Add an initial set of boids into the system
  for (int i = 0; i < 14; i++) {
    flock.addBoid(new Boid(width/2,height/2),14);
  }
  
  ArrayList<Point> p = new ArrayList<Point>();
  p.add( new Point(mi,mx,0 ,0 ,0 ) );    // blank line to start of red line
  p.add( new Point(mx,mx,on,0,0) );
  p.add( new Point(mx,mi,0,on,0) );
  p.add( new Point(mi,mi,on,on,0) );
  p.add( new Point(mi,mx,0,0,on) );   
  p.add( new Point(mx,mx,0,0,0) );   // blank line

  laserpoint = p;
  
  // register Etherdream callback to this class
  // Etherream will call getDACPoints when it require new
  // laser points
  Etherdream laser = new Etherdream(this);
}

// Laser bounary constants
final int laserMax = 45535;
final int mx = laserMax/2;
final int mi = -mx;

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

void draw() {
  background(50);
  laserpoint = flock.run();
}

// Add a new boid into the System
void mousePressed() {
  //flock.addBoid(new Boid(mouseX,mouseY),14);
  for(Boid b:flock.boids){
    b.velocity = new PVector(0,0);
  }
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
        return color(0,255,0); // green
    case 3:
        return color(255,255,0); // yellow
    case 4:
        return color(0,0,255); // green
    case 5:
        return color(0,255,255); // cyan
    case 6: 
        return color(255,0,255); // violet
    case 7:
        return color(255,255,255); // white
    default:
        return color(255,0,255);
  }
}
