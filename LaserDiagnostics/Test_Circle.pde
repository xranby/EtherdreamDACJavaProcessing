/**
 * Test 6: Circle Precision Test
 * Tests the system's ability to draw perfect circles of various sizes.
 * Simplified version to avoid DAC overloading.
 */
void drawCirclePrecisionTest(ArrayList<Point> p) {
  // Draw fewer concentric circles
  int numCircles = 3;  // Reduced from 6
  int maxRadius = mx * 2/3;
  
  for (int i = 0; i < numCircles; i++) {
    float radiusFactor = map(i, 0, numCircles-1, 0.2, 1.0);
    int radius = (int)(maxRadius * radiusFactor);
    
    // Fewer points for each circle
    int steps = (int)(12 + radiusFactor * 12);  // Reduced from 24 + 48
    
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
  
  // Simplified spiral - fewer points and slower movement
  int spiralSteps = 40;  // Reduced from 180
  float spiralRadius = maxRadius * 0.5;
  float spiralPhase = testPhase * 0.5;  // Slower animation
  
  // Start at center
  p.add(new Point(0, 0, 0, 0, 0));
  
  for (int i = 1; i <= spiralSteps; i++) {
    float t = (float)i / spiralSteps;
    float angle = t * TWO_PI * 2;  // Reduced spiral complexity (2 turns instead of 3)
    
    // Simpler pulsing effect
    float pulse = 1.0 + 0.1 * sin(t * 5 + spiralPhase);  // Reduced amplitude
    float radius = t * spiralRadius * pulse;
    
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    // Rainbow coloring
    int r = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI)));
    int g = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI + PI/3*2)));
    int b = (int)(on * (0.5 + 0.5 * sin(t * TWO_PI + PI/3*4)));
    
    p.add(new Point(x, y, r, g, b));
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 6: Circle Precision (Simplified)", 20, 30);
  text("Reduced complexity for DAC stability", 20, 50);
  text("Check for circle smoothness", 20, 70);
}
