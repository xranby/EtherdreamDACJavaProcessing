/**
 * Test 2: Color Test
 * Tests all primary and secondary colors, as well as color gradients.
 */
void drawColorTest(ArrayList<Point> p) {
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
