/**
 * GamePointsViz.pde
 * 
 * Visualization for original game points.
 */

/**
 * Draw the original game points visualization
 */
void drawGamePointsVisualization() {
  Rectangle area = currentMode == MODE_ALL ? gamePointsArea : new Rectangle(0, 0, width, height - (showControlPanel ? 150 : 0));
  
  // Draw border and background
  fill(10);
  stroke(30);
  rect(area.x, area.y, area.width, area.height);
  
  // Add header
  fill(255);
  textAlign(CENTER);
  textSize(14);
  text("Original Game Points", area.x + area.width/2, area.y + 20);
  
  // Draw coordinate axes
  stroke(40);
  line(area.x, area.y + area.height/2, area.x + area.width, area.y + area.height/2);  // X-axis
  line(area.x + area.width/2, area.y, area.x + area.width/2, area.y + area.height);   // Y-axis
  
  // Get current points to visualize
  ArrayList<PVector> currentPoints = visualizerCallback.getOriginalPoints();
  ArrayList<RenderPriority> priorities = visualizerCallback.getOriginalPriorities();
  
  if (currentPoints != null && currentPoints.size() > 0) {
    pointCount = currentPoints.size();
    
    // Draw trace history if enabled
    if (showTraces && gameTraceHistory.size() > 0) {
      drawTraceHistory(gameTraceHistory, area, gamePointColors[4], 128);
    }
    
    // Transform DAC coordinates to screen coordinates
    ArrayList<PVector> screenPoints = transformPointsToScreen(currentPoints, area);
    
    // Draw the points with colors based on priority
    for (int i = 0; i < screenPoints.size(); i++) {
      PVector p = screenPoints.get(i);
      
      // Determine color based on priority
      color pointColor = gamePointColors[0]; // Default to critical priority
      
      if (priorities != null && i < priorities.size()) {
        RenderPriority priority = priorities.get(i);
        int colorIndex = priority.ordinal();
        if (colorIndex >= 0 && colorIndex < gamePointColors.length) {
          pointColor = gamePointColors[colorIndex];
        }
      }
      
      // Draw the point
      stroke(pointColor);
      point(p.x, p.y);
      
      // Connect with lines if blanking isn't happening
      if (i > 0) {
        boolean blanking = false;
        
        if (priorities != null && i-1 < priorities.size() && priorities.get(i-1) == null) {
          blanking = true;
        }
        
        if (!blanking) {
          PVector prev = screenPoints.get(i-1);
          stroke(pointColor, 128);
          line(prev.x, prev.y, p.x, p.y);
        }
      }
    }
  }
}
