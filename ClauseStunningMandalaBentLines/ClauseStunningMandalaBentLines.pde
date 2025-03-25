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

// Bent line parameters
int bezierPoints = 12;  // Number of points to generate per bezier curve
float curvature = 0.5;  // Curvature amount for bezier lines
float waveFreq = 0.03;  // Frequency of wave patterns
float waveAmp = 3000;   // Amplitude of wave patterns

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
  
  // Draw outer shape with curved segments
  for (int i = 0; i < numPoints; i++) {
    float angle1 = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    float angle2 = map(i+1, 0, numPoints, 0, TWO_PI) + rotation;
    
    int x1 = (int)(cos(angle1) * currentRadius);
    int y1 = (int)(sin(angle1) * currentRadius);
    int x2 = (int)(cos(angle2) * currentRadius);
    int y2 = (int)(sin(angle2) * currentRadius);
    
    // Calculate control points for bezier curve
    float midAngle = (angle1 + angle2) / 2;
    float ctrlDist = currentRadius * (1 + curvature);
    int ctrlX = (int)(cos(midAngle) * ctrlDist);
    int ctrlY = (int)(sin(midAngle) * ctrlDist);
    
    // Move to first point without drawing
    if (i == 0) {
      p.add(new Point(x1, y1, 0, 0, 0));
    }
    
    // Draw curved line with bezier interpolation
    for (int j = 1; j <= bezierPoints; j++) {
      float t = (float)j / bezierPoints;
      
      // Quadratic bezier formula
      float bx = (1-t)*(1-t)*x1 + 2*(1-t)*t*ctrlX + t*t*x2;
      float by = (1-t)*(1-t)*y1 + 2*(1-t)*t*ctrlY + t*t*y2;
      
      // Add wave pattern to the bezier curve
      float wave = sin(t * TWO_PI * 2 + frameCount * waveFreq) * waveAmp * sin(t * PI);
      float waveAngle = midAngle + PI/2;  // Perpendicular to curve direction
      bx += cos(waveAngle) * wave;
      by += sin(waveAngle) * wave;
      
      // Color with gradient along the curve
      float colorT = (float)(i + t) / numPoints;
      int r = (int)(on * (0.7 + 0.3 * sin(hueShift * TWO_PI + colorT * 5.0)));
      int g = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + colorT * 3.0 + PI/3)));
      int b = (int)(on * (0.2 + 0.8 * sin(hueShift * TWO_PI + colorT * 2.0 + PI*2/3)));
      
      p.add(new Point((int)bx, (int)by, r, g, b));
    }
  }
  
  // Draw inner shape with curved segments (rotated slightly)
  for (int i = 0; i < numPoints; i++) {
    float angle1 = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    float angle2 = map(i+1, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    
    int x1 = (int)(cos(angle1) * currentInnerRadius);
    int y1 = (int)(sin(angle1) * currentInnerRadius);
    int x2 = (int)(cos(angle2) * currentInnerRadius);
    int y2 = (int)(sin(angle2) * currentInnerRadius);
    
    // Calculate control points for bezier curve - negative curvature for inner shape
    float midAngle = (angle1 + angle2) / 2;
    float ctrlDist = currentInnerRadius * (1 - curvature);
    int ctrlX = (int)(cos(midAngle) * ctrlDist);
    int ctrlY = (int)(sin(midAngle) * ctrlDist);
    
    // Move to first point without drawing
    if (i == 0) {
      p.add(new Point(x1, y1, 0, 0, 0));
    }
    
    // Draw curved line with bezier interpolation
    for (int j = 1; j <= bezierPoints; j++) {
      float t = (float)j / bezierPoints;
      
      // Quadratic bezier formula
      float bx = (1-t)*(1-t)*x1 + 2*(1-t)*t*ctrlX + t*t*x2;
      float by = (1-t)*(1-t)*y1 + 2*(1-t)*t*ctrlY + t*t*y2;
      
      // Add inverse wave pattern to the bezier curve
      float wave = sin(t * TWO_PI * 3 - frameCount * waveFreq) * waveAmp * 0.5 * sin(t * PI);
      float waveAngle = midAngle + PI/2;
      bx += cos(waveAngle) * wave;
      by += sin(waveAngle) * wave;
      
      // Color with gradient along the curve - more blue/purple
      float colorT = (float)(i + t) / numPoints;
      int r = (int)(on * (0.3 + 0.3 * sin(hueShift * TWO_PI + colorT * 4.0 + PI/2)));
      int g = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + colorT * 2.5 + PI/6)));
      int b = on;
      
      p.add(new Point((int)bx, (int)by, r, g, b));
    }
  }
  
  // Draw complex connecting lines between inner and outer shapes
  for (int i = 0; i < numPoints; i++) {
    float outerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    float innerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    
    int outerX = (int)(cos(outerAngle) * currentRadius);
    int outerY = (int)(sin(outerAngle) * currentRadius);
    int innerX = (int)(cos(innerAngle) * currentInnerRadius);
    int innerY = (int)(sin(innerAngle) * currentInnerRadius);
    
    // Create curved connecting lines with multiple control points
    drawComplexCurve(p, outerX, outerY, innerX, innerY, i);
  }
}

// Draw a complex curved line between two points with multiple control points
void drawComplexCurve(ArrayList<Point> p, int x1, int y1, int x2, int y2, int colorIndex) {
  // Move to start without drawing
  p.add(new Point(x1, y1, 0, 0, 0));
  
  // Number of control points for this curve
  int numControls = 3;
  
  // Create an array of control points
  PVector[] controls = new PVector[numControls];
  for (int i = 0; i < numControls; i++) {
    float t = (float)(i + 1) / (numControls + 1);
    
    // Interpolate position between start and end
    float baseX = x1 * (1 - t) + x2 * t;
    float baseY = y1 * (1 - t) + y2 * t;
    
    // Add controlled randomness based on frameCount
    float noiseVal = noise(baseX * 0.0001, baseY * 0.0001, frameCount * 0.01);
    float angle = TWO_PI * noiseVal + frameCount * 0.01;
    float distance = 5000 + 3000 * sin(frameCount * 0.02 + colorIndex);
    
    // Create control point with variation
    controls[i] = new PVector(
      baseX + cos(angle) * distance,
      baseY + sin(angle) * distance
    );
  }
  
  // Number of points to generate along the curve
  int steps = 15;
  
  // Generate points along the curve using Catmull-Rom spline algorithm
  for (int i = 0; i <= steps; i++) {
    float t = (float)i / steps;
    
    // Start with linear interpolation
    float x = x1 * (1 - t) + x2 * t;
    float y = y1 * (1 - t) + y2 * t;
    
    // Apply influence from each control point
    for (int j = 0; j < numControls; j++) {
      // Calculate influence - stronger in the middle
      float influence = sin(t * PI) * sin((float)(j + 1) / (numControls + 1) * PI);
      
      // Additional wave effect that changes over time
      float wave = sin(t * (5 + colorIndex) + frameCount * 0.03) * sin(t * PI) * 1500;
      float waveDir = atan2(y2 - y1, x2 - x1) + PI/2;
      
      // Add the control point's influence and the wave
      x += (controls[j].x - x) * influence * 0.8;
      y += (controls[j].y - y) * influence * 0.8;
      x += cos(waveDir) * wave;
      y += sin(waveDir) * wave;
    }
    
    // Create gradient colors along the path
    int r = (int)(on * (0.2 + 0.8 * sin(hueShift * TWO_PI + t * 3.0 + colorIndex * 0.7)));
    int g = (int)(on * (0.8 + 0.2 * sin(hueShift * TWO_PI + t * 5.0 + colorIndex * 0.5 + PI/3)));
    int b = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + t * 4.0 + colorIndex * 0.9 + PI*2/3)));
    
    p.add(new Point((int)x, (int)y, r, g, b));
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
  float pathComplexity; // Controls the complexity of the particle's path
  ArrayList<PVector> trail; // Store recent positions for trail effect
  int trailLength; // Number of positions to store
  
  Particle() {
    trail = new ArrayList<PVector>();
    reset();
  }
  
  void reset() {
    angle = random(TWO_PI);
    angleSpeed = random(0.01, 0.05) * (random(1) > 0.5 ? 1 : -1);
    size = random(2000, 5000);
    maxLife = random(100, 200);
    lifespan = maxLife;
    pathComplexity = random(0.01, 0.05);
    trailLength = int(random(6, 15));
    
    // Start from center with some offset
    pos = new PVector(random(-3000, 3000), random(-3000, 3000));
    
    // Random velocity direction
    float a = random(TWO_PI);
    vel = new PVector(cos(a), sin(a));
    vel.mult(random(200, 500));
    
    // Clear trail
    trail.clear();
    trail.add(new PVector(pos.x, pos.y));
  }
  
  void update() {
    // Add some perlin noise to the velocity for more organic movement
    float noiseVal = noise(pos.x * 0.0001, pos.y * 0.0001, frameCount * 0.01);
    float noiseAngle = TWO_PI * noiseVal;
    
    // Apply noise influence to velocity (more pronounced near end of life)
    float noiseInfluence = 0.5 + 0.5 * (1 - lifespan / maxLife);
    vel.x += cos(noiseAngle) * 20 * noiseInfluence;
    vel.y += sin(noiseAngle) * 20 * noiseInfluence;
    
    // Apply some attraction to center
    float dist = pos.mag();
    if (dist > 10000) {
      float pullFactor = map(dist, 10000, 20000, 0, 0.02);
      pullFactor = constrain(pullFactor, 0, 0.02);
      vel.x -= pos.x * pullFactor;
      vel.y -= pos.y * pullFactor;
    }
    
    // Limit velocity
    float maxSpeed = 700;
    if (vel.mag() > maxSpeed) {
      vel.normalize();
      vel.mult(maxSpeed);
    }
    
    // Update position and angle
    pos.add(vel);
    angle += angleSpeed;
    lifespan -= 1;
    
    // Add current position to trail
    trail.add(new PVector(pos.x, pos.y));
    
    // Keep trail at designated length
    while (trail.size() > trailLength) {
      trail.remove(0);
    }
    
    // Reset if out of bounds or lifespan ended
    if (lifespan <= 0 || abs(pos.x) > mx || abs(pos.y) > mx) {
      reset();
    }
  }
  
  void draw(ArrayList<Point> p) {
    // Calculate alpha based on lifespan
    float alpha = lifespan / maxLife;
    
    if (trail.size() < 2) return;
    
    // Draw the trail with bezier curves
    PVector startPos = trail.get(0);
    p.add(new Point((int)startPos.x, (int)startPos.y, 0, 0, 0));
    
    // Draw trail as a smooth curve
    for (int i = 1; i < trail.size(); i++) {
      PVector current = trail.get(i);
      float t = (float)i / trail.size();
      
      // Color with gradient along the trail - fade out at tail
      float intensity = t * alpha;
      int r = (int)(on * intensity * (0.5 + 0.5 * sin(hueShift * TWO_PI + angle)));
      int g = (int)(on * intensity * (0.5 + 0.5 * cos(hueShift * TWO_PI + angle + PI/3)));
      int b = (int)(on * intensity * (0.5 + 0.5 * sin(hueShift * TWO_PI + angle + PI*2/3)));
      
      p.add(new Point((int)current.x, (int)current.y, r, g, b));
    }
    
    // Draw a more complex shape at the current position
    drawParticleShape(p, alpha);
  }
  
  void drawParticleShape(ArrayList<Point> p, float alpha) {
    // Number of points for this shape
    int points = 5 + (int)(sin(frameCount * 0.05) * 2);
    
    // Move to first point without drawing
    float spiralGrowth = 200; // Controls how quickly the spiral grows
    float firstAngle = angle;
    float firstRadius = size * 0.2;
    int firstX = (int)(pos.x + cos(firstAngle) * firstRadius);
    int firstY = (int)(pos.y + sin(firstAngle) * firstRadius);
    
    p.add(new Point(firstX, firstY, 0, 0, 0));
    
    // Draw a spiral shape
    for (int i = 1; i <= points * 3; i++) {
      float t = (float)i / (points * 3);
      float spiralAngle = angle + t * PI * 6;
      float spiralRadius = size * (0.2 + t * 0.8) + spiralGrowth * t * t;
      
      // Add wave pattern
      float wave = sin(t * TWO_PI * 3 + frameCount * 0.1) * size * 0.3;
      
      int x = (int)(pos.x + cos(spiralAngle) * (spiralRadius + wave));
      int y = (int)(pos.y + sin(spiralAngle) * (spiralRadius + wave));
      
      // Color with gradient and fade based on lifespan
      float intensity = alpha * (1.0 - 0.5 * t); // Fade toward the end of the spiral
      int r = (int)(on * intensity * (0.7 + 0.3 * sin(hueShift * TWO_PI + t * 5.0)));
      int g = (int)(on * intensity * (0.7 + 0.3 * sin(hueShift * TWO_PI + t * 7.0 + PI/2)));
      int b = (int)(on * intensity * (0.7 + 0.3 * sin(hueShift * TWO_PI + t * 9.0 + PI)));
      
      p.add(new Point(x, y, r, g, b));
    }
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
      
      // Adaptive interpolation based on distance between points
      // This optimizes for the 32,000 galvanometer changes per second capability
      if (l < 500) {
        // For very short distances, fewer points needed
        result = concatPoints(result, getDACPointsLerpAdjusted(last, p, 5, 0.2));
      } else if (l < 2000) {
        // For medium distances
        result = concatPoints(result, getDACPointsLerpAdjusted(last, p, 15, 0.15));
      } else if (l < 5000) {
        // For longer distances
        result = concatPoints(result, getDACPointsLerpAdjusted(last, p, 25, 0.12));
      } else {
        // For very long jumps, use more points with smoother transitions
        result = concatPoints(result, getDACPointsLerpAdjusted(last, p, 40, 0.08));
      }
      
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
