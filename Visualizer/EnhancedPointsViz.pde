/**
 * EnhancedPointsViz.pde
 * 
 * Visualization for enhanced points (after BangBang processing).
 */

/**
 * Draw the enhanced points visualization
 */
void drawEnhancedPointsVisualization() {
  Rectangle area = currentMode == MODE_ALL ? enhancedPointsArea : new Rectangle(0, 0, width, height - (showControlPanel ? 150 : 0));
  
  // Draw border and background
  fill(10);
  stroke(30);
  rect(area.x, area.y, area.width, area.height);
  
  // Add header
  fill(255);
  textAlign(CENTER);
  textSize(14);
  text("Enhanced Points (BangBang Output)", area.x + area.width/2, area.y + 20);
  
  // Draw coordinate axes
  stroke(40);
  line(area.x, area.y + area.height/2, area.x + area.width, area.y + area.height/2);  // X-axis
  line(area.x + area.width/2, area.y, area.x + area.width/2, area.y + area.height);   // Y-axis
  
  // Get current points to visualize
  ArrayList<PVector> currentPoints = visualizerCallback.getEnhancedPoints();
  ArrayList<Integer> colors = visualizerCallback.getEnhancedColors();
  
  if (currentPoints != null && currentPoints.size() > 0) {
    enhancedPointCount = currentPoints.size();
    
    // Draw trace history if enabled
    if (showTraces && enhancedTraceHistory.size() > 0) {
      drawTraceHistory(enhancedTraceHistory, area, enhancedPointColors[2], 128);
    }
    
    // Transform DAC coordinates to screen coordinates
    ArrayList<PVector> screenPoints = transformPointsToScreen(currentPoints, area);
    
    // Draw the points with colors
    for (int i = 0; i < screenPoints.size(); i++) {
      PVector p = screenPoints.get(i);
      
      // Determine color based on RGB values
      color pointColor = color(255);
      
      if (colors != null && i*3+2 < colors.size()) {
        int r = colors.get(i*3);
        int g = colors.get(i*3+1);
        int b = colors.get(i*3+2);
        
        // Map DAC color values (0-65535) to screen colors (0-255)
        r = (int)map(r, 0, 65535, 0, 255);
        g = (int)map(g, 0, 65535, 0, 255);
        b = (int)map(b, 0, 65535, 0, 255);
        
        pointColor = color(r, g, b);
      }
      
      // Draw the point
      stroke(pointColor);
      point(p.x, p.y);
      
      // Connect with lines if not a blanking move
      if (i > 0) {
        boolean blanking = false;
        
        if (colors != null && (i-1)*3+2 < colors.size()) {
          int r = colors.get((i-1)*3);
          int g = colors.get((i-1)*3+1);
          int b = colors.get((i-1)*3+2);
          
          if (r == 0 && g == 0 && b == 0) {
            blanking = true;
          }
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
