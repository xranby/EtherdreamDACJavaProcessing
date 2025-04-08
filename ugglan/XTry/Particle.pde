class Particle {
  float x, y;
  float xSpeed, ySpeed;
  int lifespan;
  float size;
  
  Particle(float x, float y) {
    this.x = x;
    this.y = y;
    this.xSpeed = random(-3, 3);
    this.ySpeed = random(-3, 3);
    this.lifespan = 60;
    this.size = random(2, 6);
  }
  
  void update() {
    x += xSpeed;
    y += ySpeed;
    lifespan -= 1;
  }
  
  int draw(ArrayList<Point> p) {
    // Only draw if lifespan is high enough
    if (lifespan < 30) return 0;
    
    // Convert screen coordinates to laser coordinates
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserSize = (int)map(size, 0, width, 0, mx-mi);
    
    // Yellow-orange explosion color
    int r = on;
    int g = (int)(on * 0.7);
    int b = 0;
    
    // Draw point
    p.add(new Point(laserX, laserY, r, g, b));
    
    return 1;
  }
  
  void drawOnScreen() {
    // Draw with screen effects
    float alpha = map(lifespan, 0, 60, 0, 255);
    fill(255, 200, 0, alpha);
    noStroke();
    ellipse(x, y, size * 2, size * 2);
  }
}
