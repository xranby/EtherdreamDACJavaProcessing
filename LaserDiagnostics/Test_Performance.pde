/**
 * Test 0: Performance Monitor
 * Shows performance metrics and draws a simple test pattern to measure performance.
 */
void drawPerformanceMonitor(ArrayList<Point> p) {
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
