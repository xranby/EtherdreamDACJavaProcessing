/**
 * UI.pde
 * 
 * UI elements for the laser visualizer.
 */

/**
 * Draw the control panel
 */
void drawControlPanel() {
  // Draw control panel background
  fill(20);
  stroke(50);
  rect(controlPanelArea.x, controlPanelArea.y, controlPanelArea.width, controlPanelArea.height);
  
  // Add header
  fill(255);
  textAlign(CENTER);
  textSize(16);
  text("Laser Visualizer Controls", width/2, controlPanelArea.y + 20);
  
  // Draw control elements
  int yPos = controlPanelArea.y + 40;
  int xStep = 180;
  int x1 = 20;
  int x2 = x1 + xStep;
  int x3 = x2 + xStep;
  int x4 = x3 + xStep;
  int x5 = x4 + xStep;
  int x6 = x5 + xStep;
  
  textAlign(LEFT);
  textSize(14);
  
  // Column 1: Visualization controls
  fill(180);
  text("Visualization Mode:", x1, yPos);
  fill(currentMode == MODE_GAME_POINTS ? color(0, 255, 0) : color(180));
  text("1: Game Points", x1, yPos + 20);
  fill(currentMode == MODE_ENHANCED_POINTS ? color(0, 255, 0) : color(180));
  text("2: Enhanced Points", x1, yPos + 40);
  fill(currentMode == MODE_PHYSICS_SIM ? color(0, 255, 0) : color(180));
  text("3: Physics Simulation", x1, yPos + 60);
  fill(currentMode == MODE_LASER_OUTPUT ? color(0, 255, 0) : color(180));
  text("4: Laser Output", x1, yPos + 80);
  fill(currentMode == MODE_ALL ? color(0, 255, 0) : color(180));
  text("5: All Visualizations", x1, yPos + 100);
  
  // Column 2: Simulation controls
  fill(180);
  text("Simulation Controls:", x2, yPos);
  fill(pauseSimulation ? color(255, 0, 0) : color(0, 255, 0));
  text("Space: " + (pauseSimulation ? "Paused" : "Running"), x2, yPos + 20);
  fill(180);
  text("Speed: " + nf(simulationSpeed, 0, 1) + "x", x2, yPos + 40);
  text("+/-: Adjust Speed", x2, yPos + 60);
  text("R: Reset Simulation", x2, yPos + 80);
  
  // Column 3: Display controls
  fill(180);
  text("Display Options:", x3, yPos);
  fill(showTraces ? color(0, 255, 0) : color(180));
  text("T: Traces " + (showTraces ? "On" : "Off"), x3, yPos + 20);
  text("H: History Length: " + traceHistoryLength, x3, yPos + 40);
  fill(showPerformanceStats ? color(0, 255, 0) : color(180));
  text("P: Performance Stats " + (showPerformanceStats ? "On" : "Off"), x3, yPos + 60);
  
  // Column 4: System stats
  fill(180);
  text("System Stats:", x4, yPos);
  text("Frame Rate: " + frameRate + " fps", x4, yPos + 20);
  text("Points: " + pointCount, x4, yPos + 40);
  text("Enhanced Points: " + enhancedPointCount, x4, yPos + 60);
  
  // Column 5: Galvo parameters
  fill(180);
  text("Galvo Parameters:", x5, yPos);
  text("Spring: " + nf(galvoParams.springConstant, 0, 2), x5, yPos + 20);
  text("Damping: " + nf(galvoParams.dampingRatio, 0, 2), x5, yPos + 40);
  text("Freq: " + nf(galvoParams.naturalFrequency, 0, 0) + " Hz", x5, yPos + 60);
  
  // Column 6: Laser Output Controls
  fill(180);
  text("Laser Output Controls:", x6, yPos);
  text("B+↑/↓: Bloom Strength " + bloomStrength, x6, yPos + 20);
  text("S+↑/↓: Bloom Size " + bloomSize, x6, yPos + 40);
  text("L+↑/↓: Brightness " + nf(laserBrightness, 0, 1), x6, yPos + 60);
  fill(atmosphericScatter ? color(0, 255, 0) : color(180));
  text("A: Atmosphere " + (atmosphericScatter ? "On" : "Off"), x6, yPos + 80);
  fill(180);
  text("Q: Quality Level " + (laserOutputQuality == 0 ? "Fast" : laserOutputQuality == 1 ? "Medium" : "High"), x6, yPos + 100);
}
