/**
 * UIStats.pde
 * 
 * Performance statistics and UI overlays.
 */

/**
 * Draw UI elements (help, etc)
 */
void drawUI() {
  fill(255);
  textAlign(LEFT);
  textSize(12);
  
  // Help text at the bottom
  text("Press 'H' for help, 'C' to toggle control panel", 10, height - 10);
  
  // Stats display if enabled
  if (showPerformanceStats) {
    fill(0, 60);
    rect(0, 0, 200, 60);
    
    fill(255);
    text("FPS: " + frameRate, 10, 20);
    text("Points: " + pointCount, 10, 35);
    text("Enhanced: " + enhancedPointCount, 10, 50);
  }
}
