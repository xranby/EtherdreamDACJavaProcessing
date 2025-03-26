/**
 * GalvoCallbacks.pde
 * 
 * Implementation of callback functions required by the Etherdream library
 * and helper methods for the main sketch to communicate with hardware.
 */

/**
 * This is the main callback method for the Etherdream library
 * It MUST be in the main sketch (not in a class) to be found by reflection
 */
DACPoint[] getDACPoints() {
  // Simply pass through to our laser controller
  if (laser != null) {
    return laser.getDACPoints();
  }
  
  // Fallback test pattern if controller not available
  DACPoint[] points = new DACPoint[4];
  points[0] = new DACPoint(-10000, -10000, 65535, 65535, 65535);
  points[1] = new DACPoint(10000, -10000, 65535, 65535, 65535);
  points[2] = new DACPoint(10000, 10000, 65535, 65535, 65535);
  points[3] = new DACPoint(-10000, 10000, 65535, 65535, 65535);
  return points;
}

/**
 * Handle application shutdown to ensure clean laser shutdown
 */
void exit() {
  println("Shutting down application");
  
  // Clean up laser connection
  if (laser != null) {
    laser.shutdown();
  }
  
  // Call the parent exit handler
  super.exit();
}

/**
 * Utility function to create a test pattern with the laser
 * This can be called from any mode to verify the laser is working
 */
void runLaserTestPattern() {
  if (laser == null || !laser.isReady()) {
    println("Laser not available for test pattern");
    return;
  }
  
  // Create a test pattern (circle)
  ArrayList<PVector> testPoints = new ArrayList<PVector>();
  int numPoints = 100;
  float radius = min(width, height) * 0.3;
  
  // Generate circle
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI);
    float x = width/2 + cos(angle) * radius;
    float y = height/2 + sin(angle) * radius;
    testPoints.add(new PVector(x, y));
  }
  
  // Send to laser
  laser.sendPoints(testPoints);
  
  println("Test pattern sent to laser (" + testPoints.size() + " points)");
}

/**
 * Function to change laser color (if supported)
 * Note: Basic Etherdream implementation uses white for all points
 * This would need to be extended for color-capable hardware
 */
void setLaserColor(int r, int g, int b) {
  // Store desired color values for use in point generation
  // In a more complete implementation, this would modify the
  // color values sent to the laser
  println("Laser color set to R:" + r + " G:" + g + " B:" + b);
}

/**
 * Helper function for camera calibration
 * Sends a single bright point to a specific screen location
 */
void pointLaserAt(int x, int y) {
  if (laser != null && laser.isReady()) {
    laser.sendCalibrationPoint(x, y);
    println("Pointing laser at screen coordinates (" + x + ", " + y + ")");
  } else {
    println("Laser not available for calibration point");
  }
}

/**
 * Send the current pattern to the laser with physics applied
 * This is called regularly from the main application
 */
void updateLaser(ArrayList<PVector> targetPoints, PhysicsSimulator physics) {
  if (laser == null || !laser.isReady()) {
    return;
  }
  
  // Apply physics to get actual galvo positions
  ArrayList<PVector> galvoPoints = physics.processPoints(targetPoints);
  
  // Send to laser
  laser.sendPoints(galvoPoints);
}
