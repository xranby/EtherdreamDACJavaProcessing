/**
 * Visualization.pde
 * 
 * Core visualization setup and management.
 */

/**
 * Setup visualization areas on screen
 */
void setupVisualizationAreas() {
  if (currentMode == MODE_ALL) {
    // Four equal areas for the different visualizations
    int visualAreaHeight = showControlPanel ? (height - 150) / 2 : height / 2;
    int visualAreaWidth = width / 2;
    
    gamePointsArea = new Rectangle(0, 0, visualAreaWidth, visualAreaHeight);
    enhancedPointsArea = new Rectangle(visualAreaWidth, 0, visualAreaWidth, visualAreaHeight);
    physicsSimArea = new Rectangle(0, visualAreaHeight, visualAreaWidth, visualAreaHeight);
    laserOutputArea = new Rectangle(visualAreaWidth, visualAreaHeight, visualAreaWidth, visualAreaHeight);
    
    controlPanelArea = new Rectangle(0, 2 * visualAreaHeight, width, 150);
  } else {
    // One large area for the selected visualization
    int visualAreaHeight = showControlPanel ? height - 150 : height;
    gamePointsArea = new Rectangle(0, 0, width, visualAreaHeight);
    enhancedPointsArea = new Rectangle(0, 0, width, visualAreaHeight);
    physicsSimArea = new Rectangle(0, 0, width, visualAreaHeight);
    laserOutputArea = new Rectangle(0, 0, width, visualAreaHeight);
    controlPanelArea = new Rectangle(0, visualAreaHeight, width, 150);
  }
}

/**
 * Setup color palettes for different visualizations
 */
void setupColorPalettes() {
  // Colors for game points visualization
  gamePointColors = new color[5];
  gamePointColors[0] = color(0, 255, 0);       // Critical priority - bright green
  gamePointColors[1] = color(100, 255, 100);   // High priority - pale green
  gamePointColors[2] = color(100, 100, 255);   // Medium priority - blue
  gamePointColors[3] = color(255, 100, 100);   // Low priority - reddish
  gamePointColors[4] = color(255, 255, 100);   // Very low priority - yellow
  
  // Colors for enhanced points visualization
  enhancedPointColors = new color[5];
  enhancedPointColors[0] = color(255, 0, 0);      // Critical - red
  enhancedPointColors[1] = color(255, 128, 0);    // High - orange
  enhancedPointColors[2] = color(255, 255, 0);    // Medium - yellow
  enhancedPointColors[3] = color(0, 255, 0);      // Low - green
  enhancedPointColors[4] = color(0, 255, 255);    // Very low - cyan
  
  // Colors for physics simulation
  physicsSimColors = new color[6];
  physicsSimColors[0] = color(255, 255, 255);  // Current position - white
  physicsSimColors[1] = color(255, 0, 255);    // Laser head - magenta
  physicsSimColors[2] = color(200, 200, 0);    // Acceleration - yellow
  physicsSimColors[3] = color(0, 200, 0);      // Velocity - green
  physicsSimColors[4] = color(0, 100, 255);    // Target position - blue
  physicsSimColors[5] = color(150, 0, 0);      // Trace - dark red
}

/**
 * Update the trace history for all visualization modes
 */
void updateTraceHistory() {
  // Get current points
  if (visualizerCallback != null) {
    // Get game points (original plugin output)
    ArrayList<PVector> gamePoints = visualizerCallback.getOriginalPoints();
    if (gamePoints != null && gamePoints.size() > 0) {
      gameTraceHistory.add(new ArrayList<PVector>(gamePoints));
      while (gameTraceHistory.size() > traceHistoryLength) {
        gameTraceHistory.remove(0);
      }
    }
    
    // Get enhanced points (after BangBang processing)
    ArrayList<PVector> enhancedPoints = visualizerCallback.getEnhancedPoints();
    if (enhancedPoints != null && enhancedPoints.size() > 0) {
      enhancedTraceHistory.add(new ArrayList<PVector>(enhancedPoints));
      while (enhancedTraceHistory.size() > traceHistoryLength) {
        enhancedTraceHistory.remove(0);
      }
    }
    
    // Get physics simulation points (after galvo physics)
    ArrayList<PVector> physicsPoints = visualizerCallback.getPhysicsPoints();
    if (physicsPoints != null && physicsPoints.size() > 0) {
      physicsTraceHistory.add(new ArrayList<PVector>(physicsPoints));
      while (physicsTraceHistory.size() > traceHistoryLength) {
        physicsTraceHistory.remove(0);
      }
    }
  }
}

/**
 * Transform a list of DAC points to screen coordinates
 */
ArrayList<PVector> transformPointsToScreen(ArrayList<PVector> points, Rectangle area) {
  ArrayList<PVector> screenPoints = new ArrayList<PVector>();
  
  for (PVector p : points) {
    screenPoints.add(transformPointToScreen(p, area));
  }
  
  return screenPoints;
}

/**
 * Transform a single DAC point to screen coordinates
 */
PVector transformPointToScreen(PVector p, Rectangle area) {
  // DAC coordinates are -32767 to 32767
  // Transform to screen coordinates for the given area
  float x = map(p.x, -32767, 32767, area.x, area.x + area.width);
  float y = map(p.y, 32767, -32767, area.y, area.y + area.height);  // Y is inverted
  
  return new PVector(x, y);
}

/**
 * Transform a vector to screen coordinates (for velocity, acceleration)
 */
PVector transformVectorToScreen(PVector v, Rectangle area) {
  // Scale the vector to fit the screen
  float x = map(v.x, -32767, 32767, 0, area.width);
  float y = map(v.y, 32767, -32767, 0, area.height);  // Y is inverted
  
  return new PVector(x, y);
}

/**
 * Draw trace history from a list of point lists
 */
void drawTraceHistory(ArrayList<ArrayList<PVector>> traceHistory, Rectangle area, color traceColor, int alpha) {
  if (traceHistory.size() < 2) return;
  
  noFill();
  strokeWeight(1);
  
  // Calculate alpha fade rate based on history length
  float fadeStep = alpha / (float)traceHistory.size();
  
  for (int i = 0; i < traceHistory.size() - 1; i++) {
    // Calculate alpha for this trace segment
    int currentAlpha = (int)(fadeStep * i);
    stroke(red(traceColor), green(traceColor), blue(traceColor), currentAlpha);
    
    ArrayList<PVector> currentFrame = traceHistory.get(i);
    ArrayList<PVector> nextFrame = traceHistory.get(i + 1);
    
    if (currentFrame.size() > 0 && nextFrame.size() > 0) {
      // Connect last point of current frame to first point of next frame
      PVector lastPoint = transformPointToScreen(currentFrame.get(currentFrame.size() - 1), area);
      PVector firstPoint = transformPointToScreen(nextFrame.get(0), area);
      line(lastPoint.x, lastPoint.y, firstPoint.x, firstPoint.y);
    }
  }
  
  // Reset stroke weight
  strokeWeight(1);
}
