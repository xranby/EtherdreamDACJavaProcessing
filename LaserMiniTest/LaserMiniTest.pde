
// Store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

void setup() {
  size(640, 360);
  frameRate(30);  // Lower framerate for more stability
  
  
  // Register Etherdream callback
  Etherdream laser = new Etherdream(this);
}
