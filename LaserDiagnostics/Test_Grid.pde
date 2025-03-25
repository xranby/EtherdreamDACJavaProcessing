/**
 * Test 3: Precision Grid
 * Tests the precision and linearity of the laser movement.
 */
void drawPrecisionGrid(ArrayList<Point> p) {
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
