/**
 * Etherdream Laser Controller - Optimized for Buffer Stability
 * This sketch addresses buffer underrun issues by using multiple techniques
 * to ensure the laser DAC buffer never empties completely.
 */

Etherdream laser;
float angle = 0;
int frameCounter = 0;

// Buffer management
boolean preloadBuffer = true;
int preloadFrameCount = 5;

void setup() {
  size(640, 360);
  frameRate(30);  // Lower framerate for more stability
  
  // Initialize the Etherdream DAC with modified parameters
  // First, modify these constants in the Etherdream library:
  // private float maxBufferUtilization = 0.85f;  // Increase from 0.65 to 0.85
  // private int maxPointRate = 20000;           // Decrease from 25000 to 20000
  
  laser = new Etherdream(this);
  
  // Configure for improved stability - use even fewer points per frame
  laser.configure(150, true);  // Reduced point count, debug enabled
  
  println("Laser controller initialized with buffer optimization. Waiting for connection...");
  
  // Pre-buffer approach - queue up several frames immediately
  if (preloadBuffer) {
    println("Pre-buffering frames...");
    for (int i = 0; i < preloadFrameCount; i++) {
      DACPoint[] points = generatePoints(i * 0.1f);
      laser.queueFrame(points);
    }
  }
}

void draw() {
  // Update the visualization in the Processing window
  background(0);
  
  // Draw a representation of what's being sent to the laser
  stroke(255);
  strokeWeight(2);
  noFill();
  
  // Draw a circle representing the laser boundary
  ellipse(width/2, height/2, 300, 300);
  
  // Draw the current shape
  stroke(255, 255, 0);
  drawCurrentShape();
  
  // Update the rotation angle (slower rotation)
  angle += 0.005;
  
  // Count frames for debugging
  frameCounter++;
  if (frameCounter % 30 == 0) {
    // Print stats every 30 frames
    println("Stats: " + laser.getStats());
  }
}

// This method is required by the Etherdream library
DACPoint[] getDACPoints() {
  return generatePoints(angle);
}

// Separate point generation function that can be called with different angles
DACPoint[] generatePoints(float currentAngle) {
  // Create an array to hold our laser points
  int numPoints = 120;  // Slightly higher to ensure enough points
  DACPoint[] points = new DACPoint[numPoints];
  
  // Generate a more complex shape that spends more time drawing
  for (int i = 0; i < numPoints; i++) {
    float progress = (float)i / numPoints;
    
    // Calculate coordinates using a rounded square/circle hybrid
    // This creates smoother motion for the galvos
    float t = progress * TWO_PI;
    float radius = 0.8f + 0.2f * sin(t * 3); // Slightly varied radius
    
    // Super ellipse formula creates rounded corners - easier on the galvos
    float cosT = cos(t);
    float sinT = sin(t);
    float x = pow(abs(cosT), 0.7f) * signum(cosT) * radius;
    float y = pow(abs(sinT), 0.7f) * signum(sinT) * radius;
    
    // Apply rotation
    float rotatedX = x * cos(currentAngle) - y * sin(currentAngle);
    float rotatedY = x * sin(currentAngle) + y * cos(currentAngle);
    
    // Scale to only 65% of max range for better stability
    int dacX = (int)(rotatedX * 20000);
    int dacY = (int)(rotatedY * 20000);
    
    // Create the point with full brightness
    points[i] = new DACPoint(dacX, dacY, 65535, 32768, 0); // More orange (less green)
  }
  
  return points;
}

// Helper function for the super ellipse formula
float signum(float val) {
  if (val > 0) return 1;
  if (val < 0) return -1;
  return 0;
}

// Helper method to visualize the shape on the Processing window
void drawCurrentShape() {
  pushMatrix();
  translate(width/2, height/2);
  rotate(angle);
  
  // Draw the rounded square
  beginShape();
  for (int i = 0; i < 40; i++) {
    float t = (float)i / 40 * TWO_PI;
    float radius = 0.8f + 0.2f * sin(t * 3);
    float x = pow(abs(cos(t)), 0.7f) * signum(cos(t)) * radius * 150;
    float y = pow(abs(sin(t)), 0.7f) * signum(sin(t)) * radius * 150;
    vertex(x, y);
  }
  endShape(CLOSE);
  
  popMatrix();
}

// Handle laser shutdown when the sketch is closed
void stop() {
  println("Shutting down laser...");
  super.stop();
}
