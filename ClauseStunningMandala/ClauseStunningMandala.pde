/**
 * Cosmic Dance - Disco Laser Display
 * Based on Etherdream laser controller 
 * Designed for stunning visual impact with ~45 flickerfree lines
 */

// Laser boundary constants
final int mi = -32767;
final int mx = 32767;
final int laserMax = 65535;
// Laser light constants
final int on = 65535;
final int off = 0;

// Particle system
int numParticles = 8;
Particle[] particles;

// Geometric mandala variables
float rotation = 0;
float rotationSpeed = 0.005;
int numPoints = 5;  // Pentagon base
float radius = 15000;
float innerRadius = 7000;
float pulseAmount = 0.2;
float pulseSpeed = 0.02;
float pulse = 0;

// Color cycling variables
float hueShift = 0;
float hueShiftSpeed = 0.005;

// store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

void setup() {
  size(640, 360);
  
  // Create particles
  particles = new Particle[numParticles];
  for (int i = 0; i < numParticles; i++) {
    particles[i] = new Particle();
  }
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  
  laserpoint = p;
  
  // Register Etherdream callback
  Etherdream laser = new Etherdream(this);
}

void draw() {
  // Clear background
  background(0);
  
  // Update pulse
  pulse = sin(frameCount * pulseSpeed) * pulseAmount;
  
  // Update rotation
  rotation += rotationSpeed;
  
  // Update hue
  hueShift += hueShiftSpeed;
  if (hueShift > 1) hueShift -= 1;
  
  // Points to send to the laser
  ArrayList<Point> p = new ArrayList<Point>();
  
  // Start with a blank line
  p.add(new Point(mi, mx, 0, 0, 0));
  
  // Draw geometric mandala
  drawMandala(p);
  
  // Draw expanding/contracting particles
  drawParticles(p);
  
  // End with a blank line
  p.add(new Point(mi, mx, 0, 0, 0));
  
  // Update the laserpoint reference
  laserpoint = p;
}

void drawMandala(ArrayList<Point> p) {
  // Calculate pulsing radius
  float currentRadius = radius * (1 + pulse);
  float currentInnerRadius = innerRadius * (1 - pulse);
  
  // Draw outer shape
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    int x = (int)(cos(angle) * currentRadius);
    int y = (int)(sin(angle) * currentRadius);
    
    // Cycle colors - outer edges are more red/yellow
    int r = on;
    int g = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.5)));
    int b = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 0.8)));
    
    if (i == 0) {
      // Move without drawing for first point
      p.add(new Point(x, y, 0, 0, 0));
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // Draw inner shape (rotated slightly)
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    int x = (int)(cos(angle) * currentInnerRadius);
    int y = (int)(sin(angle) * currentInnerRadius);
    
    // Cycle colors - inner shape more blue/purple
    int r = (int)(on * (0.3 + 0.3 * sin(hueShift * TWO_PI + i * 0.8)));
    int g = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 0.5)));
    int b = on;
    
    if (i == 0) {
      // Move without drawing for first point
      p.add(new Point(x, y, 0, 0, 0));
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // Draw connecting lines between inner and outer shapes
  for (int i = 0; i < numPoints; i++) {
    float outerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    float innerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    
    int outerX = (int)(cos(outerAngle) * currentRadius);
    int outerY = (int)(sin(outerAngle) * currentRadius);
    int innerX = (int)(cos(innerAngle) * currentInnerRadius);
    int innerY = (int)(sin(innerAngle) * currentInnerRadius);
    
    // Move without drawing
    p.add(new Point(outerX, outerY, 0, 0, 0));
    
    // Draw line with green/cyan color
    int r = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 1.2)));
    int g = on;
    int b = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.7)));
    
    p.add(new Point(innerX, innerY, r, g, b));
  }
}

void drawParticles(ArrayList<Point> p) {
  // Update and draw each particle
  for (int i = 0; i < particles.length; i++) {
    particles[i].update();
    particles[i].draw(p);
  }
}

class Particle {
  PVector pos;
  PVector vel;
  float angle;
  float angleSpeed;
  float size;
  float lifespan;
  float maxLife;
  
  Particle() {
    reset();
  }
  
  void reset() {
    angle = random(TWO_PI);
    angleSpeed = random(0.01, 0.05) * (random(1) > 0.5 ? 1 : -1);
    size = random(2000, 5000);
    maxLife = random(100, 200);
    lifespan = maxLife;
    
    // Start from center
    pos = new PVector(0, 0);
    
    // Random velocity direction
    float a = random(TWO_PI);
    vel = new PVector(cos(a), sin(a));
    vel.mult(random(200, 500));
  }
  
  void update() {
    // Update position and angle
    pos.add(vel);
    angle += angleSpeed;
    lifespan -= 1;
    
    // Reset if out of bounds or lifespan ended
    if (lifespan <= 0 || abs(pos.x) > mx || abs(pos.y) > mx) {
      reset();
    }
  }
  
  void draw(ArrayList<Point> p) {
    // Calculate alpha based on lifespan
    float alpha = lifespan / maxLife;
    
    // Draw a spiral or star shape for each particle
    int segments = 4;  // Keep segment count low for performance
    
    // Move to first point without drawing
    int startX = (int)(pos.x + cos(angle) * size);
    int startY = (int)(pos.y + sin(angle) * size);
    p.add(new Point(startX, startY, 0, 0, 0));
    
    for (int i = 1; i <= segments; i++) {
      float a = angle + map(i, 0, segments, 0, TWO_PI);
      float r = (i % 2 == 0) ? size : size * 0.5;
      
      int x = (int)(pos.x + cos(a) * r);
      int y = (int)(pos.y + sin(a) * r);
      
      // Unique color for each particle
      int red = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.5)));
      int green = (int)(on * alpha * (0.5 + 0.5 * cos(hueShift * TWO_PI + i * 0.7)));
      int blue = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.9)));
      
      p.add(new Point(x, y, red, green, blue));
    }
    
    // Connect back to first point
    p.add(new Point(startX, startY, 0, 0, 0));
  }
}

// Etherdream callback - reusing the function from the original code
DACPoint[] getDACPoints() {
    return pointsMinimum(getDACPointsAdjusted(laserpoint.toArray(new Point[0])), 600);
}

// Convert coordinates - direct from the original code
int xToLaserX(int x) {
  return ((laserMax/width)*x)-mx;
}

int yToLaserY(int y) {
  return ((-laserMax/height)*y)+mx;
}

// Below are all the helper functions from the original code
// Included without modification to maintain compatibility

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

DACPoint[] getDACPointsLerpAdjusted(Point a, Point p, int mult, float d) {
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
      
      //lerp adjusted - consistent approach for clean lines
      result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      
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
