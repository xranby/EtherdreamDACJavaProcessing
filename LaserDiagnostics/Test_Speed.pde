/**
 * Test 4: Speed Test
 * Tests the maximum speed capabilities of the galvanometers.
 * Simplified version to avoid DAC overloading.
 */
void drawSpeedTest(ArrayList<Point> p) {
  // Reduced line count for stability
  int numLines = 12;  // Reduced from 45 to avoid overwhelming the DAC
  
  // Animate the lines to move outward from center (slowed down)
  float animatedSize = (0.5 + 0.5 * sin(testPhase * 0.5)) * 0.6 + 0.2;  // Slowed and reduced amplitude
  int maxSize = mx * 3/4;  // Reduced size
  
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
  
  // Secondary speed test - simplified circle
  float pulseFreq = 2.0;  // Reduced from 5.0
  float pulsePhase = testPhase * pulseFreq;
  
  // Draw a circle that expands and contracts at a moderate rate
  int circleSteps = 12;  // Reduced from 24
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
  text("Test 4: Speed Test (Simplified)", 20, 30);
  text("Reduced complexity for DAC stability", 20, 50);
  text("Points per second: " + pointsPerSecond, 20, 70);
}
