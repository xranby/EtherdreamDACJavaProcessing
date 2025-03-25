/**
 * Test 8: Response Time Test
 * Tests the system's ability to handle rapid changes in direction.
 * Simplified version to avoid DAC overloading.
 */
void drawResponseTimeTest(ArrayList<Point> p) {
  int size = mx * 1/2;  // Reduced from 2/3
  
  // Create a zigzag pattern with fewer points and less sharp turns
  int zigzagPoints = 14;  // Reduced from 40
  
  // Start at center left
  int startX = -size;
  int startY = 0;
  p.add(new Point(startX, startY, 0, 0, 0));  // Move without drawing
  
  for (int i = 1; i <= zigzagPoints; i++) {
    float t = (float)i / zigzagPoints;
    
    // X moves linearly from left to right
    int x = (int)map(t, 0, 1, -size, size);
    
    // Y zigzags, with gentler frequency
    float freq = 1 + 3 * t;  // Reduced frequency increase
    int y = (int)(sin(t * TWO_PI * freq) * size * 0.25);  // Reduced amplitude
    
    // Color varies along the path
    int r = (int)(on * (sin(t * PI) > 0 ? 1 : 0.2));
    int g = (int)(on * (sin(t * PI + PI/3) > 0 ? 1 : 0.2));
    int b = (int)(on * (sin(t * PI + PI*2/3) > 0 ? 1 : 0.2));
    
    p.add(new Point(x, y, r, g, b));
  }
  
  // Draw a simpler square with gentler corners
  int squareSize = size / 3;  // Smaller square
  int cornerRounding = (int)(squareSize * 0.3);
  float cornerSpeed = 1.0 + sin(testPhase * 0.5) * 0.5;  // Slower, less variable corner speed
  
  // Start at top left
  int sqX = -squareSize;
  int sqY = -squareSize;
  p.add(new Point(sqX, sqY, 0, 0, 0));  // Move without drawing
  
  // Draw the square with rounded corners - simplified
  drawSimplifiedRoundedCorner(p, -squareSize, -squareSize, -squareSize, squareSize, cornerRounding, cornerSpeed, 0);  // Left edge
  drawSimplifiedRoundedCorner(p, -squareSize, squareSize, squareSize, squareSize, cornerRounding, cornerSpeed, 1);   // Bottom edge
  drawSimplifiedRoundedCorner(p, squareSize, squareSize, squareSize, -squareSize, cornerRounding, cornerSpeed, 2);   // Right edge
  drawSimplifiedRoundedCorner(p, squareSize, -squareSize, -squareSize, -squareSize, cornerRounding, cornerSpeed, 3); // Top edge
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 8: Response Time Test (Simplified)", 20, 30);
  text("Reduced complexity for DAC stability", 20, 50);
  text("Check for direction change accuracy", 20, 70);
}

void drawSimplifiedRoundedCorner(ArrayList<Point> p, int x1, int y1, int x2, int y2, int rounding, float speed, int colorIndex) {
  // Simplified version with fewer points
  
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
  
  // Corner segment - fewer steps
  int steps = 5;  // Significantly reduced from original
  for (int i = 0; i <= steps; i++) {
    float t = (float)i / steps;
    
    // Apply simpler easing
    float easedT = t;
    
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
