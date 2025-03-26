/**
 * Laser Diagnostic Test Screen
 * 
 * Main program file that coordinates all tests.
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

// Buffer size parameters - smaller buffers for complex tests
int maxBufferSize = 80;    // Maximum points to send at once
int highComplexityMaxPoints = 60;  // Even smaller buffer for complex tests

// Store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

void setup() {
  size(640, 360);
  frameRate(30);  // Lower framerate for more stability
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  laserpoint = p;
  
  // Register Etherdream callback
  Etherdream laser = new Etherdream(this);
  
  println("Laser Diagnostic Test Screen - Optimized for DAC Stability");
  println("---------------------------");
  println("Press keys 1-9 to switch between different test patterns:");
  println("1: Boundary Test");
  println("2: Color Test");
  println("3: Precision Grid");
  println("4: Speed Test (Simplified)");
  println("5: Line Interpolation Test");
  println("6: Circle Precision Test (Simplified)");
  println("7: Complex Curve Test (Simplified)");
  println("8: Response Time Test (Simplified)");
  println("9: All Tests Sequential");
  println("0: Performance Monitor");
  println("");
  println("NOTE: Tests 4, 6, 7, and 8 have been simplified to avoid DAC overloading");
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
