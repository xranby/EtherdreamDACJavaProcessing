/**
 * Etherdream Laser Controller - TIE Fighter Pattern
 * Optimized for stable buffer performance at 15000 points per second
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
  
  // Initialize the Etherdream DAC
  // Make sure these values are set in the Etherdream library:
  // private float maxBufferUtilization = 0.85f;  // Increased from 0.65
  // private int maxPointRate = 15000;           // Reduced to 15000
  
  laser = new Etherdream(this);
  
  // Configure for improved stability
  laser.configure(180, true);  // 180 points per frame, debug enabled
  
  println("TIE Fighter Laser Pattern - Initializing...");
  
  // Pre-buffer approach - queue up several frames immediately
  if (preloadBuffer) {
    println("Pre-buffering frames...");
    for (int i = 0; i < preloadFrameCount; i++) {
      DACPoint[] points = generateTIEFighterPoints(i * 0.05f);
      laser.queueFrame(points);
    }
  }
}

void draw() {
  // Update the visualization in the Processing window
  background(0);
  
  // Draw a representation of what's being sent to the laser
  noFill();
  
  // Draw a circle representing the laser boundary
  stroke(40);
  strokeWeight(1);
  ellipse(width/2, height/2, 300, 300);
  
  // Draw the current TIE Fighter shape
  stroke(0, 255, 255); // Cyan for TIE Fighter
  strokeWeight(2);
  drawTIEFighterShape();
  
  // Update the rotation angle (slow rotation)
  angle += 0.005;
  
  // Count frames for debugging
  frameCounter++;
  if (frameCounter % 60 == 0) {
    // Print stats every 60 frames
    println("Stats: " + laser.getStats());
  }
}

// Required callback method for the Etherdream library
DACPoint[] getDACPoints() {
  return generateTIEFighterPoints(angle);
}

// TIE Fighter point generation - creates the distinctive shape with hexagonal wings and ball cockpit
DACPoint[] generateTIEFighterPoints(float currentAngle) {
  // Create an array to hold our laser points
  int numPoints = 180;  // Maintain point count for stability
  DACPoint[] points = new DACPoint[numPoints];
  
  // Distribute points between different parts of the TIE Fighter
  int cockpitPoints = 40;          // Center sphere
  int leftWingPoints = 70;         // Left hexagonal wing
  int rightWingPoints = 70;        // Right hexagonal wing
  
  // Draw the cockpit (center ball)
  for (int i = 0; i < cockpitPoints; i++) {
    float progress = (float)i / cockpitPoints;
    float t = progress * TWO_PI;
    
    // Circle for the cockpit, smaller radius
    float x = 0.0f;  // Center X
    float y = 0.0f;  // Center Y
    float radius = 0.25f;  // Small central cockpit
    
    x += radius * cos(t);
    y += radius * sin(t);
    
    // Apply rotation for the entire TIE fighter
    float rotatedX = x * cos(currentAngle) - y * sin(currentAngle);
    float rotatedY = x * sin(currentAngle) + y * cos(currentAngle);
    
    // Scale to 65% of max range for stability
    int dacX = (int)(rotatedX * 19000);
    int dacY = (int)(rotatedY * 19000);
    
    // Create the point with cyan color for TIE Fighter
    points[i] = new DACPoint(dacX, dacY, 0, 45000, 65535); // Blue-green
  }
  
  // Draw the left hexagonal wing
  for (int i = 0; i < leftWingPoints; i++) {
    float progress = (float)i / leftWingPoints;
    
    // Hexagon has 6 sides
    int side = (int)(progress * 6);
    float sideProgress = (progress * 6) - side;
    
    // Create coordinates for hexagon
    float x = 0, y = 0;
    float radius = 0.8f;  // Wing radius
    float angle1 = side * TWO_PI / 6;
    float angle2 = (side + 1) * TWO_PI / 6;
    
    // Interpolate between the corners of the hexagon
    float x1 = radius * cos(angle1);
    float y1 = radius * sin(angle1);
    float x2 = radius * cos(angle2);
    float y2 = radius * sin(angle2);
    
    x = x1 + sideProgress * (x2 - x1);
    y = y1 + sideProgress * (y2 - y1);
    
    // Position left wing
    x -= 0.9f;  // Move to the left
    
    // Connect to cockpit with struts (thicken the lines near center)
    if (side == 2 || side == 5) {
      // Adjust points on the inner sides to create strut effect
      float strut = 0.15f * sin(sideProgress * PI);
      y += strut;
    }
    
    // Apply rotation for the entire TIE fighter
    float rotatedX = x * cos(currentAngle) - y * sin(currentAngle);
    float rotatedY = x * sin(currentAngle) + y * cos(currentAngle);
    
    // Scale to 65% of max range for stability
    int dacX = (int)(rotatedX * 19000);
    int dacY = (int)(rotatedY * 19000);
    
    // Create the point with cyan color
    points[cockpitPoints + i] = new DACPoint(dacX, dacY, 0, 45000, 65535);
  }
  
  // Draw the right hexagonal wing
  for (int i = 0; i < rightWingPoints; i++) {
    float progress = (float)i / rightWingPoints;
    
    // Hexagon has 6 sides
    int side = (int)(progress * 6);
    float sideProgress = (progress * 6) - side;
    
    // Create coordinates for hexagon
    float x = 0, y = 0;
    float radius = 0.8f;  // Wing radius
    float angle1 = side * TWO_PI / 6;
    float angle2 = (side + 1) * TWO_PI / 6;
    
    // Interpolate between the corners of the hexagon
    float x1 = radius * cos(angle1);
    float y1 = radius * sin(angle1);
    float x2 = radius * cos(angle2);
    float y2 = radius * sin(angle2);
    
    x = x1 + sideProgress * (x2 - x1);
    y = y1 + sideProgress * (y2 - y1);
    
    // Position right wing
    x += 0.9f;  // Move to the right
    
    // Connect to cockpit with struts (thicken the lines near center)
    if (side == 2 || side == 5) {
      // Adjust points on the inner sides to create strut effect
      float strut = 0.15f * sin(sideProgress * PI);
      y += strut;
    }
    
    // Apply rotation for the entire TIE fighter
    float rotatedX = x * cos(currentAngle) - y * sin(currentAngle);
    float rotatedY = x * sin(currentAngle) + y * cos(currentAngle);
    
    // Scale to 65% of max range for stability
    int dacX = (int)(rotatedX * 19000);
    int dacY = (int)(rotatedY * 19000);
    
    // Create the point with cyan color
    points[cockpitPoints + leftWingPoints + i] = new DACPoint(dacX, dacY, 0, 45000, 65535);
  }
  
  return points;
}

// Helper method to visualize the TIE Fighter on the Processing window
void drawTIEFighterShape() {
  pushMatrix();
  translate(width/2, height/2);
  rotate(angle);
  scale(150);
  
  // Draw cockpit (center sphere)
  noFill();
  ellipse(0, 0, 0.5, 0.5);
  
  // Draw left wing (hexagon)
  pushMatrix();
  translate(-0.9, 0);
  beginShape();
  for (int i = 0; i < 6; i++) {
    float angle = i * TWO_PI / 6;
    float x = 0.8 * cos(angle);
    float y = 0.8 * sin(angle);
    vertex(x, y);
  }
  endShape(CLOSE);
  popMatrix();
  
  // Draw right wing (hexagon)
  pushMatrix();
  translate(0.9, 0);
  beginShape();
  for (int i = 0; i < 6; i++) {
    float angle = i * TWO_PI / 6;
    float x = 0.8 * cos(angle);
    float y = 0.8 * sin(angle);
    vertex(x, y);
  }
  endShape(CLOSE);
  popMatrix();
  
  // Draw struts connecting wings to cockpit
  line(-0.9, 0.25, -0.25, 0);
  line(-0.9, -0.25, -0.25, 0);
  line(0.9, 0.25, 0.25, 0);
  line(0.9, -0.25, 0.25, 0);
  
  popMatrix();
}

// Handle laser shutdown when the sketch is closed
void stop() {
  println("Shutting down laser...");
  super.stop();
}
