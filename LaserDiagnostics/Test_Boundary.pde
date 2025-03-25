/**
 * Test 1: Boundary Test
 * Tests the full range of motion of the laser.
 */
void drawBoundaryTest(ArrayList<Point> p) {
  // Draw the full boundaries of the laser space
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
