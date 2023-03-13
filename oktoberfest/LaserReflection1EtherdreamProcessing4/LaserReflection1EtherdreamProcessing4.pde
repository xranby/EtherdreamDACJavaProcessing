/**
 * Non-orthogonal Reflection 
 * by Ira Greenberg. 
 * 
 * Based on the equation (R = 2N(N*L)-L) where R is the 
 * reflection vector, N is the normal, and L is the incident
 * vector.
 *
 * Added support for Etherdream laser output
 * by Xerxes Rånby
 */

// Position of left hand side of floor
PVector base1;
// Position of right hand side of floor
PVector base2;
// Length of floor
float baseLength;

// An array of subpoints along the floor path
PVector[] coords;

// Variables related to moving ball
PVector position;
PVector velocity;
float r = 6;
float speed = 3.5;

void setup() {
  size(640, 360);

  fill(128);
  base1 = new PVector(0, height-150);
  base2 = new PVector(width, height);
  createGround();

  // start ellipse at middle top of screen
  position = new PVector(width/2, 0);

  // calculate initial random velocity
  velocity = PVector.random2D();
  velocity.mult(speed);
  
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
  laser = new Etherdream(this);
  //laser.debug=true;
}

Etherdream laser;

// Laser bounary constants
final int mi = -32767;
final int mx = 32767;
final int laserMax = 65535;
// Laser light constants
final int on = 65535;
final int off = 0;

// Convert the screen coordinates 0 to width
// to laser coordinates ranging from 32767 to -32767
int xToLaserX(int x){
  return ((laserMax/width)*x)-mx;
}

// Convert the screen coordinates height to 0
// to laser coordinates ranging from 32767 to -32767
int yToLaserY(int y){
  return ((-laserMax/height)*y)+mx;
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

// store old points used for the laser "ball" tail
volatile ArrayList<Point> laserfade = new ArrayList<Point>();

void draw() {
  
  // points to send to the laser.
  ArrayList<Point> p = new ArrayList<Point>();
  
  // draw a rectangle around the laser maximum limits
  p.add( new Point(mi,mx,0 ,0 ,0 ) );    // blank line to start of red line
  p.add( new Point(mx,mx,on,0 ,0 ) );    // beam red line
  p.add( new Point(mx,mi,0 ,on,0 ) );    // beam green line
  p.add( new Point(mi,mi,on,on,0 ) );    // beam yellow line
  p.add( new Point(mi,mx,0 ,0 ,on) );    // beam blue line  
  p.add( new Point(mi,mx,0,0,0) );      // blank line
  
  // draw background
  fill(0);
/*  noStroke();
  rect(0, 0, width, height);

  // draw base
  fill(200);
  quad(base1.x, base1.y, base2.x, base2.y, base2.x, height, 0, height);
*/
  // beam base to laser
  p.add(  new Point(xToLaserX((int)base1.x),yToLaserY((int)base1.y),0,0,0) );      // laser blank line, start of red base line
  p.add(  new Point(xToLaserX((int)base2.x),yToLaserY((int)base2.y),on,0,0) );     // laser draw the red base line to here
  
  // calculate base top normal
  PVector baseDelta = PVector.sub(base2, base1);
  baseDelta.normalize();
  PVector normal = new PVector(-baseDelta.y, baseDelta.x);
/*
  // draw ellipse
  noStroke();
  fill(255);
  ellipse(position.x, position.y, r*2, r*2);
  */
  // laser blank line to possition before ball move
  p.add(  new Point(xToLaserX((int)position.x),yToLaserY((int)position.y),0,0,0) );      // blank line
  
  // move elipse
  position.add(velocity);
  p.add(  new Point(xToLaserX((int)position.x),yToLaserY((int)position.y),0,on,0) );      // green laser ball
  
  // add tail after ball to laser
  laserfade.add(new Point(xToLaserX((int)position.x),yToLaserY((int)position.y),on,0,on));
  if(laserfade.size()>500){
   laserfade.remove(0);
   
   // ading the points in the wrong order to generate an interesting shape
   p.add(laserfade.get(0));
   p.add(laserfade.get(100));
   p.add(laserfade.get(200));
   p.add(laserfade.get(300));
   p.add(laserfade.get(400));
   p.add(laserfade.get(499));
   
   /*
   Adding the points in this order is correct..
   but it looked less interesting
   p.add(laserfade.get(399));
   p.add(laserfade.get(300));
   p.add(laserfade.get(200));
   p.add(laserfade.get(100));
   p.add(laserfade.get(0));
   */
   laserpoint =p ;
   laser.paint();
 }
 
 p.add( new Point(mi,mx,0 ,0 ,0 ) );    // blank line to start of red line to calm down galvoimeters efore next frame
 
  // update the laserpoint reference so that our generated points are sent
  // to the laser next time the laser request more points
  // usinf the getF
  laserpoint= p;

  // normalized incidence vector
  PVector incidence = PVector.mult(velocity, -1);
  incidence.normalize();

  // detect and handle collision
  for (int i=0; i<coords.length; i++) {
    // check distance between ellipse and base top coordinates
    if (PVector.dist(position, coords[i]) < r) {

      // calculate dot product of incident vector and base top normal 
      float dot = incidence.dot(normal);

      // calculate reflection vector
      // assign reflection vector to direction vector
      velocity.set(2*normal.x*dot - incidence.x, 2*normal.y*dot - incidence.y, 0);
      velocity.mult(speed);

      // draw base top normal at collision point
      stroke(255, 128, 0);
      line(position.x, position.y, position.x-normal.x*100, position.y-normal.y*100);
    }
  }

  // detect boundary collision
  // right
  if (position.x > width-r) {
    position.x = width-r;
    velocity.x *= -1;
  }
  // left 
  if (position.x < r) {
    position.x = r;
    velocity.x *= -1;
  }
  // top
  if (position.y < r) {
    position.y = r;
    velocity.y *= -1;
    // randomize base top
    base1.y = random(height-100, height);
    base2.y = random(height-100, height);
    createGround();
  }
}

// Calculate variables for the ground
void createGround() {
  // calculate length of base top
  baseLength = PVector.dist(base1, base2);

  // fill base top coordinate array
  coords = new PVector[ceil(baseLength)];
  for (int i=0; i<coords.length; i++) {
    coords[i] = new PVector();
    coords[i].x = base1.x + ((base2.x-base1.x)/baseLength)*i;
    coords[i].y = base1.y + ((base2.y-base1.y)/baseLength)*i;
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
