/**
 * Laser Diagnostic Test Screen
 * 
 * This program helps diagnose issues with laser rendering by 
 * providing a series of calibration and test patterns.
 * Press keys 1-9 to switch between different test patterns.
 */

// Laser boundary constants
final int mi = -32767;
final int mx = 32767;
final int laserMax = 65535;
// Laser light constants
final int on = 65535;
final int off = 0;

// Test pattern selection
int currentTest = 1;
// For animating tests
float testPhase = 0;
float testSpeed = 0.02;
// For storing performance metrics
int frameStartTime;
int pointCount = 0;
float fps = 0;
int pointsPerSecond = 0;

// Store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

void setup() {
  size(640, 360);
  frameRate(60);
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  laserpoint = p;
  
  // Register Etherdream callback
  Etherdream laser = new Etherdream(this);
  
  println("Laser Diagnostic Test Screen");
  println("---------------------------");
  println("Press keys 1-9 to switch between different test patterns:");
  println("1: Boundary Test");
  println("2: Color Test");
  println("3: Precision Grid");
  println("4: Speed Test");
  println("5: Line Interpolation Test");
  println("6: Circle Precision Test");
  println("7: Complex Curve Test");
  println("8: Response Time Test");
  println("9: All Tests Sequential");
  println("0: Performance Monitor");
}

void draw() {
  // Clear background
  background(0);
  
  // Start timing this frame for performance metrics
  frameStartTime = millis();
  
  // Update test phase for animations
  testPhase += testSpeed;
  if (testPhase > TWO_PI) {
    testPhase -= TWO_PI;
  }
  
  // Points to send to the laser
  ArrayList<Point> p = new ArrayList<Point>();
  
  // Start with a blank line
  p.add(new Point(mi, mx, 0, 0, 0));
  
  // Run the selected test
  switch(currentTest) {
    case 1:
      drawBoundaryTest(p);
      break;
    case 2:
      drawColorTest(p);
      break;
    case 3:
      drawPrecisionGrid(p);
      break;
    case 4:
      drawSpeedTest(p);
      break;
    case 5:
      drawLineInterpolationTest(p);
      break;
    case 6:
      drawCirclePrecisionTest(p);
      break;
    case 7:
      drawComplexCurveTest(p);
      break;
    case 8:
      drawResponseTimeTest(p);
      break;
    case 9:
      drawSequentialTests(p);
      break;
    case 0:
      drawPerformanceMonitor(p);
      break;
  }
  
  // End with a blank line
  p.add(new Point(mi, mx, 0, 0, 0));
  
  // Update the laserpoint reference
  laserpoint = p;
  
  // Update performance metrics for display
  pointCount = p.size();
  fps = frameRate;
  pointsPerSecond = (int)(pointCount * fps);
  
  // Draw screen overlay with test info
  drawScreenOverlay();
}

void keyPressed() {
  if (key >= '0' && key <= '9') {
    currentTest = key - '0';
    println("Switched to test " + currentTest);
  }
}

// ===== TEST PATTERNS =====

void drawBoundaryTest(ArrayList<Point> p) {
  // Test 1: Draw the full boundaries of the laser space
  // This helps identify if the laser is correctly calibrated for the full range of motion
  
  // Draw full boundary rectangle
  p.add(new Point(mi, mi, on, 0, 0));  // Bottom left - red
  p.add(new Point(mx, mi, 0, on, 0));  // Bottom right - green
  p.add(new Point(mx, mx, 0, 0, on));  // Top right - blue
  p.add(new Point(mi, mx, on, on, 0));  // Top left - yellow
  p.add(new Point(mi, mi, on, 0, 0));  // Back to start - red
  
  // Draw center crosshair
  int crossSize = mx / 4;
  p.add(new Point(-crossSize, 0, 0, 0, 0));  // Move without drawing
  p.add(new Point(crossSize, 0, on, on, on));  // Horizontal line - white
  p.add(new Point(0, 0, 0, 0, 0));  // Move without drawing
  p.add(new Point(0, -crossSize, 0, 0, 0));  // Move without drawing
  p.add(new Point(0, crossSize, on, on, on));  // Vertical line - white
  
  // Draw center circle
  int steps = 36;
  int radius = mx / 6;
  for (int i = 0; i <= steps; i++) {
    float angle = map(i, 0, steps, 0, TWO_PI);
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0));  // Move without drawing for first point
    } else {
      // Cycle through colors
      int r = (int)(on * (0.5 + 0.5 * sin(i * 0.5)));
      int g = (int)(on * (0.5 + 0.5 * sin(i * 0.5 + PI/3*2)));
      int b = (int)(on * (0.5 + 0.5 * sin(i * 0.5 + PI/3*4)));
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 1: Boundary Test", 20, 30);
  text("Verify the laser draws a full rectangle with clear corners", 20, 50);
  text("Check if the center crosshair and circle are centered and circular", 20, 70);
}

void drawColorTest(ArrayList<Point> p) {
  // Test 2: Color calibration test
  // Tests all primary and secondary colors and gradients
  
  // Draw color squares in a grid
  int gridSize = 3;
  int spacing = mx / gridSize;
  
  for (int y = 0; y < gridSize; y++) {
    for (int x = 0; x < gridSize; x++) {
      int x1 = mi + x * spacing * 2;
      int y1 = mi + y * spacing * 2;
      int x2 = x1 + spacing;
      int y2 = y1 + spacing;
      
      // Determine color based on position
      int r = (x == 0) ? on : ((x == 1) ? on/2 : 0);
      int g = (y == 0) ? on : ((y == 1) ? on/2 : 0);
      int b = ((x + y) % 3 == 0) ? on : ((x + y) % 3 == 1) ? on/2 : 0;
      
      // Draw square
      p.add(new Point(x1, y1, 0, 0, 0));  // Move without drawing
      p.add(new Point(x1, y2, r, g, b));
      p.add(new Point(x2, y2, r, g, b));
      p.add(new Point(x2, y1, r, g, b));
      p.add(new Point(x1, y1, r, g, b));
    }
  }
  
  // Draw color wheel
  int radius = mx / 4;
  int wheelX = 0;
  int wheelY = 0;
  int steps = 60;
  
  for (int i = 0; i <= steps; i++) {
    float angle = map(i, 0, steps, 0, TWO_PI);
    int x = wheelX + (int)(cos(angle) * radius);
    int y = wheelY + (int)(sin(angle) * radius);
    
    // Hue based on angle
    float hue = angle / TWO_PI;
    
    // Convert HSB to RGB (simplified for laser)
    int r, g, b;
    float h = hue * 6;
    int hi = (int)h % 6;
    float f = h - (int)h;
    
    switch(hi) {
      case 0: r = on; g = (int)(on * f); b = 0; break;
      case 1: r = (int)(on * (1-f)); g = on; b = 0; break;
      case 2: r = 0; g = on; b = (int)(on * f); break;
      case 3: r = 0; g = (int)(on * (1-f)); b = on; break;
      case 4: r = (int)(on * f); g = 0; b = on; break;
      default: r = on; g = 0; b = (int)(on * (1-f)); break;
    }
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0));  // Move without drawing for first point
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 2: Color Test", 20, 30);
  text("Verify all colors are distinct and accurate", 20, 50);
  text("Check the color wheel for smooth transitions", 20, 70);
}

void drawPrecisionGrid(ArrayList<Point> p) {
  // Test 3: Precision grid test
  // Tests the precision of the laser with a fine grid pattern
  
  int gridSize = 10;  // 10x10 grid
  int spacing = mx / (gridSize / 2);
  
  // Draw horizontal lines
  for (int y = 0; y <= gridSize; y++) {
    int yPos = mi + (mx - mi) * y / gridSize;
    
    // Alternate colors for better visibility
    int r = (y % 2 == 0) ? on : 0;
    int g = (y % 2 == 1) ? on : 0;
    int b = on/3;
    
    p.add(new Point(mi, yPos, 0, 0, 0));  // Move without drawing
    p.add(new Point(mx, yPos, r, g, b));
  }
  
  // Draw vertical lines
  for (int x = 0; x <= gridSize; x++) {
    int xPos = mi + (mx - mi) * x / gridSize;
    
    // Alternate colors for better visibility
    int r = (x % 2 == 1) ? on : 0;
    int g = (x % 2 == 0) ? on : 0;
    int b = on/3;
    
    p.add(new Point(xPos, mi, 0, 0, 0));  // Move without drawing
    p.add(new Point(xPos, mx, r, g, b));
  }
  
  // Draw calibration markers at specific points
  drawCalibrationMarker(p, mi, mi, on, 0, 0);  // Bottom left
  drawCalibrationMarker(p, mx, mi, 0, on, 0);  // Bottom right
  drawCalibrationMarker(p, mx, mx, 0, 0, on);  // Top right
  drawCalibrationMarker(p, mi, mx, on, on, 0);  // Top left
  drawCalibrationMarker(p, 0, 0, on, on, on);  // Center
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 3: Precision Grid", 20, 30);
  text("Check for grid uniformity and straightness", 20, 50);
  text("Verify calibration markers are symmetrical", 20, 70);
}

void drawCalibrationMarker(ArrayList<Point> p, int x, int y, int r, int g, int b) {
  int size = mx / 20;
  
  // Draw a plus sign
  p.add(new Point(x - size, y, 0, 0, 0));  // Move without drawing
  p.add(new Point(x + size, y, r, g, b));
  
  p.add(new Point(x, y - size, 0, 0, 0));  // Move without drawing
  p.add(new Point(x, y + size, r, g, b));
  
  // Draw a small circle
  int steps = 12;
  for (int i = 0; i <= steps; i++) {
    float angle = map(i, 0, steps, 0, TWO_PI);
    int circleX = x + (int)(cos(angle) * (size/2));
    int circleY = y + (int)(sin(angle) * (size/2));
    
    if (i == 0) {
      p.add(new Point(circleX, circleY, 0, 0, 0));  // Move without drawing for first point
    } else {
      p.add(new Point(circleX, circleY, r, g, b));
    }
  }
}

void drawSpeedTest(ArrayList<Point> p) {
  // Test 4: Speed test
  // Tests the maximum speed capabilities of the galvanometers
  
  // Number of lines to draw
  int numLines = 45;  // You mentioned 45 lines is optimal for flickerfree
  
  // Animate the lines to move outward from center
  float animatedSize = (0.5 + 0.5 * sin(testPhase)) * 0.8 + 0.2;
  int maxSize = mx;
  
  for (int i = 0; i < numLines; i++) {
    float angle = map(i, 0, numLines, 0, TWO_PI);
    
    // Create speed test shapes at different distances
    float distance = maxSize * animatedSize;
    
    // Start point (center)
    int x1 = 0;
    int y1 = 0;
    
    // End point (perimeter)
    int x2 = (int)(cos(angle) * distance);
    int y2 = (int)(sin(angle) * distance);
    
    // Color based on angle
    int r = (int)(on * (0.5 + 0.5 * sin(angle)));
    int g = (int)(on * (0.5 + 0.5 * sin(angle + PI/3*2)));
    int b = (int)(on * (0.5 + 0.5 * sin(angle + PI/3*4)));
    
    // Draw line
    p.add(new Point(x1, y1, 0, 0, 0));  // Move without drawing
    p.add(new Point(x2, y2, r, g, b));
  }
  
  // Secondary speed test - moving circle
  float pulseFreq = 5.0;
  float pulsePhase = testPhase * pulseFreq;
  
  // Draw a circle that expands and contracts rapidly
  int circleSteps = 24;  // Fewer points for higher speed
  float pulseRadius = maxSize * 0.3 * (0.5 + 0.5 * sin(pulsePhase));
  
  for (int i = 0; i <= circleSteps; i++) {
    float angle = map(i, 0, circleSteps, 0, TWO_PI);
    int x = (int)(cos(angle) * pulseRadius);
    int y = (int)(sin(angle) * pulseRadius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0));  // Move without drawing for first point
    } else {
      // White circle
      p.add(new Point(x, y, on, on, on));
    }
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 4: Speed Test", 20, 30);
  text("Check for smooth animation without flickering", 20, 50);
  text("The circle should pulse rapidly while lines move smoothly", 20, 70);
  text("Points per second: " + pointsPerSecond, 20, 90);
}

void drawLineInterpolationTest(ArrayList<Point> p) {
  // Test 5: Line interpolation test
  // Tests how the system handles line interpolation of varying distances
  
  int centerX = 0;
  int centerY = 0;
  int numLines = 8;
  int maxDist = mx;
  
  // Draw lines with increasing distances
  for (int i = 0; i < numLines; i++) {
    float angle = map(i, 0, numLines, 0, TWO_PI);
    
    // Calculate multiple points along this line at different distances
    int segments = 5;
    
    for (int j = 0; j < segments; j++) {
      float dist = map(j, 0, segments-1, maxDist * 0.1, maxDist);
      int x = centerX + (int)(cos(angle) * dist);
      int y = centerY + (int)(sin(angle) * dist);
      
      // First point of each line - move without drawing
      if (j == 0) {
        p.add(new Point(centerX, centerY, 0, 0, 0));
        p.add(new Point(x, y, on, on, on));  // Short distance - white
      } else {
        // Color based on distance - more distant = more colorful
        float colorPhase = (float)j / segments;
        int r = (int)(on * (j % 3 == 0 ? 1 : 0.2));
        int g = (int)(on * (j % 3 == 1 ? 1 : 0.2));
        int b = (int)(on * (j % 3 == 2 ? 1 : 0.2));
        
        // Previous point position
        float prevDist = map(j-1, 0, segments-1, maxDist * 0.1, maxDist);
        int prevX = centerX + (int)(cos(angle) * prevDist);
        int prevY = centerY + (int)(sin(angle) * prevDist);
        
        // Move without drawing from previous point
        p.add(new Point(prevX, prevY, 0, 0, 0));
        // Draw to new point
        p.add(new Point(x, y, r, g, b));
      }
    }
  }
  
  // Draw diagonal test lines across the entire range
  int corners[][] = {
    {mi, mi}, {mx, mi}, {mx, mx}, {mi, mx}  // Bottom left, bottom right, top right, top left
  };
  
  // Connect each corner to all other corners
  for (int i = 0; i < corners.length; i++) {
    for (int j = i+1; j < corners.length; j++) {
      // Different color for each diagonal
      int r = (i == 0 || j == 0) ? on : on/3;
      int g = (i == 1 || j == 1) ? on : on/3;
      int b = (i == 2 || j == 2) ? on : on/3;
      
      // Draw line from corner i to corner j
      p.add(new Point(corners[i][0], corners[i][1], 0, 0, 0));  // Move without drawing
      p.add(new Point(corners[j][0], corners[j][1], r, g, b));
    }
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 5: Line Interpolation", 20, 30);
  text("Check for line straightness and consistency", 20, 50);
  text("Verify smooth transitions between line segments", 20, 70);
}

void drawCirclePrecisionTest(ArrayList<Point> p) {
  // Test 6: Circle precision test
  // Tests the system's ability to draw perfect circles of various sizes
  
  // Draw concentric circles
  int numCircles = 6;
  int maxRadius = mx * 3/4;
  
  for (int i = 0; i < numCircles; i++) {
    float radiusFactor = map(i, 0, numCircles-1, 0.1, 1.0);
    int radius = (int)(maxRadius * radiusFactor);
    
    // More points for larger circles
    int steps = (int)(24 + radiusFactor * 48);
    
    // Color based on circle size
    int r = (i % 3 == 0) ? on : on/4;
    int g = (i % 3 == 1) ? on : on/4;
    int b = (i % 3 == 2) ? on : on/4;
    
    for (int j = 0; j <= steps; j++) {
      float angle = map(j, 0, steps, 0, TWO_PI);
      int x = (int)(cos(angle) * radius);
      int y = (int)(sin(angle) * radius);
      
      if (j == 0) {
        p.add(new Point(x, y, 0, 0, 0));  // Move without drawing for first point
      } else {
        p.add(new Point(x, y, r, g, b));
      }
    }
  }
  
  // Draw a pulsing spiral to test precision during animation
  int spiralSteps = 180;
  float spiralRadius = maxRadius * 0.6;
  float spiralGrowth = 0.02;
  float spiralPhase = testPhase * 2;
  
  // Start at center
  p.add(new Point(0, 0, 0, 0, 0));
  
  for (int i = 1; i <= spiralSteps; i++) {
    float t = (float)i / spiralSteps;
    float angle = t * TWO_PI * 3;
    
    // Add pulsing effect
    float pulse = 1.0 + 0.2 * sin(t * 10 + spiralPhase);
    float radius = t * spiralRadius * pulse;
    
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    // Rainbow coloring
    int r = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI * 3)));
    int g = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI * 3 + PI/3*2)));
    int b = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI * 3 + PI/3*4)));
    
    p.add(new Point(x, y, r, g, b));
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 6: Circle Precision", 20, 30);
  text("Check for circle roundness and consistency", 20, 50);
  text("Verify the spiral is smooth with no jumps", 20, 70);
}

void drawComplexCurveTest(ArrayList<Point> p) {
  // Test 7: Complex curve test
  // Tests the system's ability to handle complex curves and shapes
  
  // Draw a series of bezier curves
  int numCurves = 8;
  int maxDist = mx * 2/3;
  
  for (int i = 0; i < numCurves; i++) {
    float angle1 = map(i, 0, numCurves, 0, TWO_PI);
    float angle2 = map((i + 1) % numCurves, 0, numCurves, 0, TWO_PI);
    
    // Start and end points
    int x1 = (int)(cos(angle1) * maxDist);
    int y1 = (int)(sin(angle1) * maxDist);
    int x2 = (int)(cos(angle2) * maxDist);
    int y2 = (int)(sin(angle2) * maxDist);
    
    // Control points - create interesting curves
    float ctrlAngle1 = angle1 + PI/2;
    float ctrlAngle2 = angle2 - PI/2;
    float ctrlDist = maxDist * 0.8;
    
    int cx1 = (int)(cos(ctrlAngle1) * ctrlDist);
    int cy1 = (int)(sin(ctrlAngle1) * ctrlDist);
    int cx2 = (int)(cos(ctrlAngle2) * ctrlDist);
    int cy2 = (int)(sin(ctrlAngle2) * ctrlDist);
    
    // Draw the bezier curve
    drawBezier(p, x1, y1, cx1, cy1, cx2, cy2, x2, y2, i);
  }
  
  // Draw a complex flower pattern
  int petalCount = 5;
  float petalSize = maxDist * 0.5;
  float innerRadius = maxDist * 0.2;
  
  // Rotate the entire flower slowly
  float flowerRotation = testPhase;
  
  for (int i = 0; i < petalCount; i++) {
    float angle = map(i, 0, petalCount, 0, TWO_PI) + flowerRotation;
    float nextAngle = map((i + 1) % petalCount, 0, petalCount, 0, TWO_PI) + flowerRotation;
    
    // Points around the edge of the flower
    int x1 = (int)(cos(angle) * petalSize);
    int y1 = (int)(sin(angle) * petalSize);
    int x2 = (int)(cos(nextAngle) * petalSize);
    int y2 = (int)(sin(nextAngle) * petalSize);
    
    // Points on the inner circle
    int ix1 = (int)(cos(angle) * innerRadius);
    int iy1 = (int)(sin(angle) * innerRadius);
    int ix2 = (int)(cos(nextAngle) * innerRadius);
    int iy2 = (int)(sin(nextAngle) * innerRadius);
    
    // Color based on petal
    int r = (int)(on * (0.5 + 0.5 * sin(angle)));
    int g = (int)(on * (0.5 + 0.5 * sin(angle + PI/3*2)));
    int b = (int)(on * (0.5 + 0.5 * sin(angle + PI/3*4)));
    
    // Draw outer petal
    p.add(new Point(ix1, iy1, 0, 0, 0));  // Move without drawing
    p.add(new Point(x1, y1, r, g, b));
    p.add(new Point(x2, y2, r, g, b));
    p.add(new Point(ix2, iy2, r, g, b));
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 7: Complex Curve Test", 20, 30);
  text("Check for smooth curve rendering", 20, 50);
  text("Verify the flower pattern has consistent shape", 20, 70);
}

void drawBezier(ArrayList<Point> p, int x1, int y1, int cx1, int cy1, int cx2, int cy2, int x2, int y2, int colorIndex) {
  // Helper function to draw a cubic bezier curve
  
  int steps = 24;  // Number of line segments to draw
  
  // Color based on curve index
  int r = (colorIndex % 3 == 0) ? on : on/4;
  int g = (colorIndex % 3 == 1) ? on : on/4;
  int b = (colorIndex % 3 == 2) ? on : on/4;
  
  // Move to first point without drawing
  p.add(new Point(x1, y1, 0, 0, 0));
  
  // Draw the bezier curve as a series of line segments
  for (int i = 1; i <= steps; i++) {
    float t = (float)i / steps;
    
    // Cubic bezier formula
    float xt = bezierPoint(x1, cx1, cx2, x2, t);
    float yt = bezierPoint(y1, cy1, cy2, y2, t);
    
    p.add(new Point((int)xt, (int)yt, r, g, b));
  }
}

float bezierPoint(float a, float b, float c, float d, float t) {
  // Calculate point on cubic bezier curve at parameter t
  float t1 = 1.0 - t;
  return a*t1*t1*t1 + 3*b*t*t1*t1 + 3*c*t*t*t1 + d*t*t*t;
}

void drawResponseTimeTest(ArrayList<Point> p) {
  // Test 8: Response time test
  // Tests the system's ability to handle rapid changes in direction
  
  int size = mx * 2/3;
  
  // Create a zigzag pattern with increasingly sharp turns
  int zigzagPoints = 40;
  
  // Start at center left
  int startX = -size;
  int startY = 0;
  p.add(new Point(startX, startY, 0, 0, 0));  // Move without drawing
  
  for (int i = 1; i <= zigzagPoints; i++) {
    float t = (float)i / zigzagPoints;
    
    // X moves linearly from left to right
    int x = (int)map(t, 0, 1, -size, size);
    
    // Y zigzags, with frequency increasing over time
    float freq = 1 + 10 * t;  // Increasing frequency
    int y = (int)(sin(t * TWO_PI * freq) * size * 0.3);
    
    // Color varies along the path
    int r = (int)(on * (sin(t * PI) > 0 ? 1 : 0.2));
    int g = (int)(on * (sin(t * PI + PI/3) > 0 ? 1 : 0.2));
    int b = (int)(on * (sin(t * PI + PI*2/3) > 0 ? 1 : 0.2));
    
    p.add(new Point(x, y, r, g, b));
  }
  
  // Draw a square with increasingly rapid corners
  int squareSize = size / 2;
  int cornerRounding = (int)(squareSize * 0.2);
  float cornerSpeed = 2.0 + sin(testPhase) * 1.5;  // Variable corner speed
  
  // Start at top left
  int sqX = -squareSize;
  int sqY = -squareSize;
  p.add(new Point(sqX, sqY, 0, 0, 0));  // Move without drawing
  
  // Draw the square with rounded corners
  drawRoundedCorner(p, -squareSize, -squareSize, -squareSize, squareSize, cornerRounding, cornerSpeed, 0);  // Left edge
  drawRoundedCorner(p, -squareSize, squareSize, squareSize, squareSize, cornerRounding, cornerSpeed, 1);   // Bottom edge
  drawRoundedCorner(p, squareSize, squareSize, squareSize, -squareSize, cornerRounding, cornerSpeed, 2);   // Right edge
  drawRoundedCorner(p, squareSize, -squareSize, -squareSize, -squareSize, cornerRounding, cornerSpeed, 3); // Top edge
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 8: Response Time Test", 20, 30);
  text("Check for accuracy during rapid direction changes", 20, 50);
  text("Look for corner smoothness and zigzag fidelity", 20, 70);
}

void drawRoundedCorner(ArrayList<Point> p, int x1, int y1, int x2, int y2, int rounding, float speed, int colorIndex) {
  // Helper function to draw a line with a rounded corner
  
  // Define direction vectors
  int dx1 = x2 - x1;
  int dy1 = 0;
  int dx2 = 0;
  int dy2 = y2 - y1;
  
  // Calculate corner points
  int cx1 = x1 + dx1 - (dx1 != 0 ? (dx1 > 0 ? rounding : -rounding) : 0);
  int cy1 = y1;
  int cx2 = x2;
  int cy2 = y1 + dy2 - (dy2 != 0 ? (dy2 > 0 ? rounding : -rounding) : 0);
  
  // First straight segment
  p.add(new Point(x1, y1, on, on, on));
  p.add(new Point(cx1, cy1, on, on, on));
  
  // Corner segment
  int steps = (int)(10 + speed * 5);  // More steps for faster corners
  for (int i = 0; i <= steps; i++) {
    float t = (float)i / steps;
    
    // Apply easing for more realistic acceleration/deceleration
    float easedT;
    if (speed > 3.0) {
      // Fast corners have abrupt changes
      easedT = t < 0.5 ? 2*t*t : -1+(4-2*t)*t;
    } else {
      // Slower corners have smoother transitions
      easedT = t;
    }
    
    // Simple curved corner
    float angle = easedT * PI/2;
    int cornerType = colorIndex % 4;  // 0: top-left, 1: bottom-left, 2: bottom-right, 3: top-right
    
    int rx = 0, ry = 0;
    switch(cornerType) {
      case 0:  // top-left
        rx = (int)(cos(angle + PI) * rounding);
        ry = (int)(sin(angle + PI) * rounding);
        break;
      case 1:  // bottom-left
        rx = (int)(cos(angle + PI/2) * rounding);
        ry = (int)(sin(angle + PI/2) * rounding);
        break;
      case 2:  // bottom-right
        rx = (int)(cos(angle) * rounding);
        ry = (int)(sin(angle) * rounding);
        break;
      case 3:  // top-right
        rx = (int)(cos(angle + PI*3/2) * rounding);
        ry = (int)(sin(angle + PI*3/2) * rounding);
        break;
    }
    
    int x = cx1 + rx;
    int y = cy1 + ry;
    
    // Color based on corner type
    int r = (cornerType == 0 || cornerType == 2) ? on : on/3;
    int g = (cornerType == 1 || cornerType == 3) ? on : on/3;
    int b = on/2;
    
    p.add(new Point(x, y, r, g, b));
  }
  
  // Second straight segment
  p.add(new Point(cx2, cy2, on, on, on));
  p.add(new Point(x2, y2, on, on, on));
}

void drawSequentialTests(ArrayList<Point> p) {
  // Test 9: Sequential Tests
  // Cycles through all tests over time
  int cycleLength = 600;  // frames to complete full cycle
  int testDuration = cycleLength / 8;  // duration of each test
  
  // Calculate which test to show
  int frameCCount = frameCount % cycleLength;
  int testIndex = frameCCount / testDuration + 1;
  
  // Run the current test
  switch(testIndex) {
    case 1: drawBoundaryTest(p); break;
    case 2: drawColorTest(p); break;
    case 3: drawPrecisionGrid(p); break;
    case 4: drawSpeedTest(p); break;
    case 5: drawLineInterpolationTest(p); break;
    case 6: drawCirclePrecisionTest(p); break;
    case 7: drawComplexCurveTest(p); break;
    case 8: drawResponseTimeTest(p); break;
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 9: Sequential Tests", 20, 30);
  text("Currently showing: Test " + testIndex, 20, 50);
  text("Tests cycle automatically every " + (testDuration/60) + " seconds", 20, 70);
}

void drawPerformanceMonitor(ArrayList<Point> p) {
  // Test 0: Performance Monitor
  // Shows performance metrics and draws a simple test pattern to measure performance
  
  // Draw a simple spinning star for laser visibility
  int points = 8;
  int innerRadius = mx / 5;
  int outerRadius = mx * 2/3;
  float rotation = testPhase;
  
  for (int i = 0; i <= points*2; i++) {
    float angle = map(i, 0, points*2, 0, TWO_PI) + rotation;
    float radius = (i % 2 == 0) ? outerRadius : innerRadius;
    
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0));  // Move without drawing for first point
    } else {
      // Rainbow coloring
      int r = (int)(on * (0.5 + 0.5 * sin(i * 0.5)));
      int g = (int)(on * (0.5 + 0.5 * sin(i * 0.5 + PI/3*2)));
      int b = (int)(on * (0.5 + 0.5 * sin(i * 0.5 + PI/3*4)));
      
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // On-screen display
  fill(255);
  textSize(16);
  text("Performance Monitor", 20, 30);
  textSize(14);
  text("Current FPS: " + nf(fps, 0, 1), 20, 60);
  text("Point count per frame: " + pointCount, 20, 80);
  text("Points per second: " + pointsPerSecond, 20, 100);
  text("Rendering time: " + (millis() - frameStartTime) + "ms", 20, 120);
  
  // Calculate recommended settings
  int recPointsPerFrame = (int)(32000 / frameRate);
  text("Optimal points per frame: ~" + recPointsPerFrame, 20, 150);
  
  // System warnings
  if (fps < 30) {
    fill(255, 0, 0);
    text("WARNING: Low frame rate detected", 20, 180);
  }
  
  if (pointsPerSecond > 32000) {
    fill(255, 0, 0);
    text("WARNING: Exceeding 32k points/sec", 20, 200);
  }
}

// Draw the on-screen overlay with test info and help
void drawScreenOverlay() {
  fill(255);
  textSize(12);
  text("Laser Diagnostic Test Screen - Test " + currentTest, width - 240, 20);
  text("Press 1-9 to change tests, 0 for metrics", width - 240, 40);
  
  if (currentTest == 0) {
    // Show additional performance details in performance mode
    textSize(10);
    text("Benchmark: " + (pointsPerSecond < 25000 ? "GOOD" : pointsPerSecond < 32000 ? "CAUTION" : "EXCEEDING LIMITS"), width - 240, 60);
    
    // Calculate and display laser load percentage
    float laserLoad = (float)pointsPerSecond / 32000.0 * 100.0;
    text("Laser load: " + nf(laserLoad, 0, 1) + "%", width - 240, 75);
    
    // Status color indicator
    if (laserLoad < 75) fill(0, 255, 0);
    else if (laserLoad < 100) fill(255, 255, 0);
    else fill(255, 0, 0);
    
    noStroke();
    rect(width - 240, 80, laserLoad * 2, 10);
  }
}

// Convert coordinates for screen visualization
int xToLaserX(int x) {
  return ((laserMax/width)*x)-mx;
}

int yToLaserY(int y) {
  return ((-laserMax/height)*y)+mx;
}

// Etherdream callback
DACPoint[] getDACPoints() {
    return pointsMinimum(getDACPointsAdjusted(laserpoint.toArray(new Point[0])), 600);
}

// Below are all the helper functions from the original code
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
