/**
 * PhysicsSimViz.pde
 * 
 * Visualization for physics simulation of galvo movement.
 */

/**
 * Draw the physics simulation showing actual galvo movement
 */
void drawPhysicsSimulation() {
  Rectangle area = currentMode == MODE_ALL ? physicsSimArea : new Rectangle(0, 0, width, height - (showControlPanel ? 150 : 0));
  
  // Draw border and background
  fill(10);
  stroke(30);
  rect(area.x, area.y, area.width, area.height);
  
  // Add header
  fill(255);
  textAlign(CENTER);
  textSize(14);
  text("Physics Simulation (Actual Galvo Movement)", area.x + area.width/2, area.y + 20);
  
  // Draw coordinate axes
  stroke(40);
  line(area.x, area.y + area.height/2, area.x + area.width, area.y + area.height/2);  // X-axis
  line(area.x + area.width/2, area.y, area.x + area.width/2, area.y + area.height);   // Y-axis
  
  // Draw simulation statistics
  fill(200);
  textAlign(LEFT);
  textSize(12);
  text("Spring Constant: " + nf(galvoParams.springConstant, 0, 2), area.x + 10, area.y + 40);
  text("Damping Ratio: " + nf(galvoParams.dampingRatio, 0, 2), area.x + 10, area.y + 55);
  text("Natural Frequency: " + nf(galvoParams.naturalFrequency, 0, 0) + " Hz", area.x + 10, area.y + 70);
  
  // Draw the trace history if enabled
  if (showTraces && physicsTraceHistory.size() > 0) {
    drawTraceHistory(physicsTraceHistory, area, physicsSimColors[5], 180);
  }
  
  // Get current state of the galvo
  PVector position = simulatedDAC.getPosition();
  PVector velocity = simulatedDAC.getVelocity();
  PVector acceleration = simulatedDAC.getAcceleration();
  PVector target = simulatedDAC.getTargetPosition();
  
  // Transform to screen coordinates
  PVector screenPos = transformPointToScreen(position, area);
  PVector screenVel = screenPos.copy().add(transformVectorToScreen(velocity.copy().mult(0.01), area));
  PVector screenAcc = screenPos.copy().add(transformVectorToScreen(acceleration.copy().mult(0.0001), area));
  PVector screenTarget = transformPointToScreen(target, area);
  
  // Draw the target position
  stroke(physicsSimColors[4]);
  strokeWeight(1);
  noFill();
  ellipse(screenTarget.x, screenTarget.y, 10, 10);
  
  // Draw velocity vector
  stroke(physicsSimColors[3]);
  strokeWeight(2);
  line(screenPos.x, screenPos.y, screenVel.x, screenVel.y);
  
  // Draw acceleration vector
  stroke(physicsSimColors[2]);
  strokeWeight(1);
  line(screenPos.x, screenPos.y, screenAcc.x, screenAcc.y);
  
  // Draw the current position
  stroke(physicsSimColors[1]);
  strokeWeight(5);
  point(screenPos.x, screenPos.y);
  
  // Reset stroke weight
  strokeWeight(1);
}
