/**
 * Test 5: Line Interpolation Test
 * Tests how the system handles line interpolation of varying distances.
 */
void drawLineInterpolationTest(ArrayList<Point> p) {
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
