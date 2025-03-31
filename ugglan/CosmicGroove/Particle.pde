/**
 * Particle class for dynamic element in laser visualization
 * Extracted from original CosmicGroove.pde file
 */
class Particle {
  PVector pos;
  PVector vel;
  float angle;
  float angleSpeed;
  float size;
  float lifespan;
  float maxLife;
  
  Particle() {
    reset();
  }
  
  void reset() {
    angle = random(TWO_PI);
    angleSpeed = random(0.01, 0.05) * (random(1) > 0.5 ? 1 : -1);
    size = random(2000, 5000);
    maxLife = random(100, 200);
    lifespan = maxLife;
    
    // Start from center
    pos = new PVector(0, 0);
    
    // Random velocity direction
    float a = random(TWO_PI);
    vel = new PVector(cos(a), sin(a));
    vel.mult(random(200, 500));
  }
  
  void update() {
    // Update position and angle
    pos.add(vel);
    angle += angleSpeed;
    lifespan -= 1;
    
    // Reset if out of bounds or lifespan ended
    if (lifespan <= 0 || abs(pos.x) > mx || abs(pos.y) > mx) {
      reset();
    }
  }
  
  void draw(ArrayList<Point> p) {
    // Calculate alpha based on lifespan
    float alpha = lifespan / maxLife;
    
    // Draw a spiral or star shape for each particle
    int segments = 4;  // Keep segment count low for performance
    
    // Move to first point without drawing
    int startX = (int)(pos.x + cos(angle) * size);
    int startY = (int)(pos.y + sin(angle) * size);
    p.add(new Point(startX, startY, 0, 0, 0));
    
    for (int i = 1; i <= segments; i++) {
      float a = angle + map(i, 0, segments, 0, TWO_PI);
      float r = (i % 2 == 0) ? size : size * 0.5;
      
      int x = (int)(pos.x + cos(a) * r);
      int y = (int)(pos.y + sin(a) * r);
      
      // Unique color for each particle
      int red = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.5)));
      int green = (int)(on * alpha * (0.5 + 0.5 * cos(hueShift * TWO_PI + i * 0.7)));
      int blue = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.9)));
      
      p.add(new Point(x, y, red, green, blue));
    }
    
    // Connect back to first point
    p.add(new Point(startX, startY, 0, 0, 0));
  }
}
