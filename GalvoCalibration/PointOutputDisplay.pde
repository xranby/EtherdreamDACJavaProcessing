/**
 * PointOutputDisplay.pde
 * 
 * Displays current laser points in plugin mode
 * Provides real-time visualization of what's being sent to the laser
 */

class PointOutputDisplay {
  // Display configuration
  private boolean visible = false;
  private int displayX = 10;
  private int displayY = 60;
  private int displayWidth = 260;
  private int displayHeight = 200;
  private float pointSize = 1.5f;
  
  // Point history
  private ArrayList<PointFrame> pointHistory = new ArrayList<PointFrame>();
  private int maxHistoryFrames = 60; // Keep about 1 second of history at 60fps
  
  // Statistics
  private int totalPoints = 0;
  private int minPoints = Integer.MAX_VALUE;
  private int maxPoints = 0;
  private float avgPoints = 0;
  
  // Display colors
  private color backgroundColor = color(0, 0, 0, 220);
  private color titleColor = color(255);
  private color textColor = color(200);
  private color pointColor = color(0, 255, 0, 150);
  private color blankingColor = color(255, 0, 0, 80);
  
  /**
   * Update with the latest points from a plugin
   */
  public void update(LaserPlugin plugin) {
    if (plugin == null) return;
    
    // Get current points from the plugin
    ArrayList<DACPoint> currentPoints = plugin.getPoints();
    
    // Skip if no points
    if (currentPoints == null || currentPoints.isEmpty()) return;
    
    // Add to history
    pointHistory.add(new PointFrame(currentPoints));
    
    // Trim history if needed
    while (pointHistory.size() > maxHistoryFrames) {
      pointHistory.remove(0);
    }
    
    // Update statistics
    updateStatistics();
  }
  
  /**
   * Update point statistics
   */
  private void updateStatistics() {
    // Reset statistics
    totalPoints = 0;
    minPoints = Integer.MAX_VALUE;
    maxPoints = 0;
    
    // Process all frames in history
    for (PointFrame frame : pointHistory) {
      int count = frame.points.size();
      totalPoints += count;
      minPoints = min(minPoints, count);
      maxPoints = max(maxPoints, count);
    }
    
    // Calculate average
    if (!pointHistory.isEmpty()) {
      avgPoints = totalPoints / (float)pointHistory.size();
    } else {
      avgPoints = 0;
      minPoints = 0;
    }
  }
  
  /**
   * Draw the point output display
   */
  public void draw() {
    if (!visible || pointHistory.isEmpty()) return;
    
    // Save current matrix state
    pushMatrix();
    resetMatrix();
    
    // Draw background panel
    fill(backgroundColor);
    noStroke();
    rect(displayX, displayY, displayWidth, displayHeight);
    
    // Draw title
    fill(titleColor);
    textAlign(LEFT);
    textSize(14);
    text("Point Output", displayX + 10, displayY + 20);
    
    // Draw statistics
    fill(textColor);
    textSize(11);
    String statsText = String.format("Points: %.1f avg (%d min, %d max)", 
                                     avgPoints, minPoints, maxPoints);
    text(statsText, displayX + 10, displayY + 38);
    
    // Draw point visualization area outline
    stroke(60);
    strokeWeight(1);
    noFill();
    rect(displayX + 10, displayY + 45, displayWidth - 20, displayHeight - 55);
    
    // Draw the points from most recent frame
    if (!pointHistory.isEmpty()) {
      PointFrame lastFrame = pointHistory.get(pointHistory.size() - 1);
      drawPointFrame(lastFrame, displayX + 10, displayY + 45, displayWidth - 20, displayHeight - 55);
    }
    
    // Draw help text
    fill(textColor);
    textSize(10);
    textAlign(RIGHT);
    text("Press 'O' to toggle point display", displayX + displayWidth - 10, displayY + displayHeight - 10);
    
    // Restore matrix state
    popMatrix();
  }
  
  /**
   * Draw a single frame of points
   */
  private void drawPointFrame(PointFrame frame, int x, int y, int w, int h) {
    if (frame == null || frame.points.isEmpty()) return;
    
    // Draw each point
    noStroke();
    
    for (DACPoint point : frame.points) {
      // Map from DAC coordinates to display coordinates
      float px = map(point.getX(), -32767, 32767, x, x + w);
      float py = map(point.getY(), 32767, -32767, y, y + h); // Y is inverted
      
      // Check if this is a blanking point (all colors zero)
      if (point.getR() == 0 && point.getG() == 0 && point.getB() == 0) {
        fill(blankingColor);
      } else {
        // Regular point
        fill(pointColor);
      }
      
      // Draw the point
      ellipse(px, py, pointSize, pointSize);
    }
    
    // Draw connecting lines between points
    stroke(pointColor);
    strokeWeight(0.5);
    noFill();
    beginShape();
    
    boolean drawing = false;
    for (DACPoint point : frame.points) {
      float px = map(point.getX(), -32767, 32767, x, x + w);
      float py = map(point.getY(), 32767, -32767, y, y + h);
      
      // Check if blanking
      if (point.getR() == 0 && point.getG() == 0 && point.getB() == 0) {
        // End current line if we were drawing
        if (drawing) {
          endShape();
          drawing = false;
        }
      } else {
        // Start a new line if we weren't drawing
        if (!drawing) {
          beginShape();
          drawing = true;
        }
        
        // Add vertex
        vertex(px, py);
      }
    }
    
    // End shape if we were drawing
    if (drawing) {
      endShape();
    }
  }
  
  /**
   * Toggle visibility
   */
  public void toggle() {
    visible = !visible;
  }
  
  /**
   * Class to store a frame of points
   */
  private class PointFrame {
    public ArrayList<DACPoint> points;
    public long timestamp;
    
    public PointFrame(ArrayList<DACPoint> points) {
      this.points = new ArrayList<DACPoint>(points); // Make a copy
      this.timestamp = System.currentTimeMillis();
    }
  }
}
