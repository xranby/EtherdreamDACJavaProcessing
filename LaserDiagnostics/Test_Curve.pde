/**
 * Test 7: Complex Curve Test
 * Tests the system's ability to handle complex curves and shapes.
 * Simplified version to avoid DAC overloading.
 */
void drawComplexCurveTest(ArrayList<Point> p) {
  // Draw fewer bezier curves
  int numCurves = 4;  // Reduced from 8
  int maxDist = mx * 1/2;  // Reduced scale
  
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
    float ctrlDist = maxDist * 0.6;  // Reduced control point distance
    
    int cx1 = (int)(cos(ctrlAngle1) * ctrlDist);
    int cy1 = (int)(sin(ctrlAngle1) * ctrlDist);
    int cx2 = (int)(cos(ctrlAngle2) * ctrlDist);
    int cy2 = (int)(sin(ctrlAngle2) * ctrlDist);
    
    // Draw the bezier curve with fewer points
    drawSimplifiedBezier(p, x1, y1, cx1, cy1, cx2, cy2, x2, y2, i);
  }
  
  // Simplified flower pattern
  int petalCount = 3;  // Reduced from 5
  float petalSize = maxDist * 0.5;
  float innerRadius = maxDist * 0.2;
  
  // Rotate the entire flower slowly
  float flowerRotation = testPhase * 0.5;  // Slower rotation
  
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
    
    // Draw simplified petal
    p.add(new Point(ix1, iy1, 0, 0, 0));  // Move without drawing
    p.add(new Point(x1, y1, r, g, b));
    p.add(new Point(x2, y2, r, g, b));
    p.add(new Point(ix2, iy2, r, g, b));
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 7: Complex Curve (Simplified)", 20, 30);
  text("Reduced complexity for DAC stability", 20, 50);
  text("Check curve rendering quality", 20, 70);
}

void drawSimplifiedBezier(ArrayList<Point> p, int x1, int y1, int cx1, int cy1, int cx2, int cy2, int x2, int y2, int colorIndex) {
  // Helper function to draw a cubic bezier curve with fewer points
  
  int steps = 12;  // Reduced from 24
  
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
