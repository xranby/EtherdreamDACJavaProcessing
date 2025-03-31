/**
 * LaserVisualizer.pde
 * 
 * A visualizer for Etherdream laser DAC outputs without requiring actual hardware
 * Shows the laser beam path, points, and movement characteristics
 */

class LaserVisualizer {
  // Display settings
  private boolean showPoints = true;          // Show individual points
  private boolean showBeam = true;            // Show laser beam path
  private boolean showVelocityColors = true;  // Color paths based on velocity
  private boolean showMotionBlur = true;      // Show motion blur
  
  // Visual parameters
  private int pointSize = 3;                  // Size of points
  private int canvasWidth;                    // Width of visualization
  private int canvasHeight;                   // Height of visualization
  private float velocityScale = 0.5;          // Scale for velocity visualization
  private int blurTrailLength = 20;           // Length of motion blur trail
  
  // Laser point history for visualization
  private ArrayList<DACPoint> pointHistory = new ArrayList<DACPoint>();
  private ArrayList<PVector> velocityHistory = new ArrayList<PVector>();
  private ArrayList<Float> intensityHistory = new ArrayList<Float>();
  
  // UI components
  private PGraphics canvas;                   // Drawing canvas
  private PVector lastPosition;               // Last position of laser
  private PVector currentVelocity;            // Current velocity of laser
  
  /**
   * Constructor
   */
  public LaserVisualizer(int width, int height) {
    this.canvasWidth = width;
    this.canvasHeight = height;
    this.canvas = createGraphics(width, height); // Use P2D renderer for better performance
    this.lastPosition = new PVector(0, 0);
    this.currentVelocity = new PVector(0, 0);
    
    // Ensure we start with some points in history by adding defaults
    // This ensures the visualizer shows something even before real points arrive
    for (int i = 0; i < 10; i++) {
      float angle = map(i, 0, 10, 0, TWO_PI);
      int x = (int)(cos(angle) * 10000);
      int y = (int)(sin(angle) * 10000);
      
      DACPoint testPoint = new DACPoint(x, y, 65535, 0, 0);
      pointHistory.add(testPoint);
      velocityHistory.add(new PVector(0, 0));
      intensityHistory.add(1.0f);
    }
    
    println("LaserVisualizer initialized with canvas size: " + width + "x" + height);
  }
  
  /**
   * Update the visualizer with new points
   */
  public void update(DACPoint[] points) {
    if (points == null || points.length == 0) return;
    
    // Debug - show point count
    println("Visualizer received " + points.length + " points");
    
    // Clear old history completely when we get a new frame
    // This ensures we're only showing the current frame
    pointHistory.clear();
    velocityHistory.clear();
    intensityHistory.clear();
    
    // Process ALL new points - no sampling
    for (int i = 0; i < points.length; i++) {
      DACPoint point = points[i];
      
      // Add to history
      pointHistory.add(point);
      
      // Calculate current position in screen coordinates
      PVector currentPos = dacToScreen(point);
      
      // Calculate velocity
      PVector velocity = PVector.sub(currentPos, lastPosition);
      currentVelocity.lerp(velocity, 0.3); // Smooth the velocity
      velocityHistory.add(currentVelocity.copy());
      
      // Calculate intensity based on RGB values
      float intensity = (point.r + point.g + point.b) / (float)(3 * 65535);
      intensityHistory.add(intensity);
      
      // Update last position
      lastPosition = currentPos.copy();
    }
    
    // Debug - show how many points are now in the history
    println("Visualizer pointHistory now contains " + pointHistory.size() + " points");
  }
  
  /**
   * Draw the visualization
   */
  public void draw() {
    canvas.beginDraw();
    canvas.background(0); // Solid black background for better contrast
    
    // Debug info - display point count
    canvas.fill(255);
    canvas.textSize(14);
    canvas.text("Points: " + pointHistory.size(), 10, 20);
    
    // Debug - draw a test pattern if no points are available
    if (pointHistory.size() < 2) {
      canvas.stroke(255, 0, 0);
      canvas.strokeWeight(2);
      canvas.line(0, 0, canvasWidth/2, canvasHeight/2);
      canvas.stroke(0, 255, 0);
      canvas.line(canvasWidth, 0, canvasWidth/2, canvasHeight/2);
      canvas.stroke(0, 0, 255);
      canvas.line(0, canvasHeight, canvasWidth/2, canvasHeight/2);
      canvas.stroke(255, 255, 0);
      canvas.line(canvasWidth, canvasHeight, canvasWidth/2, canvasHeight/2);
      canvas.endDraw();
      image(canvas, 0, 0);
      return;
    }
    
    // Draw motion blur if enabled
    if (showMotionBlur && pointHistory.size() > blurTrailLength) {
      drawMotionBlur();
    }
    
    // Draw beam path if enabled
    if (showBeam) {
      drawBeamPath();
    }
    
    // Draw points if enabled
    if (showPoints) {
      drawPoints();
    }
    
    canvas.endDraw();
    image(canvas, 0, 0);
  }
  
  /**
   * Draw the laser beam path
   */
  private void drawBeamPath() {
    if (pointHistory.size() < 2) return;
    
    // Draw all points in the history
    for (int i = 0; i < pointHistory.size() - 1; i++) {
      DACPoint current = pointHistory.get(i);
      DACPoint next = pointHistory.get(i + 1);
      
      // Skip blanking segments (where RGB values are all 0)
      if (isBlanking(current) && isBlanking(next)) {
        continue;
      }
      
      PVector pos1 = dacToScreen(current);
      PVector pos2 = dacToScreen(next);
      
      // Calculate color based on velocity or use the actual beam color
      if (showVelocityColors) {
        // Velocity-based coloring
        PVector vel = velocityHistory.get(i);
        float speed = vel.mag() * velocityScale;
        speed = constrain(speed, 0, 255);
        
        canvas.stroke(255 - speed, speed, min(speed * 2, 255), 220); // Increased alpha for better visibility
        canvas.strokeWeight(1.5); // Thicker lines
      } else {
        // Actual beam color
        float r = map(current.r, 0, 65535, 0, 255);
        float g = map(current.g, 0, 65535, 0, 255);
        float b = map(current.b, 0, 65535, 0, 255);
        
        // Use a minimum brightness for visible lines
        float minBrightness = 50; // Increased from 30
        r = max(r, isBlanking(current) ? 0 : minBrightness);
        g = max(g, isBlanking(current) ? 0 : minBrightness);
        b = max(b, isBlanking(current) ? 0 : minBrightness);
        
        canvas.stroke(r, g, b, 220); // Increased alpha
        canvas.strokeWeight(1.8); // Thicker lines
      }
      
      canvas.line(pos1.x, pos1.y, pos2.x, pos2.y);
    }
  }
  
  /**
   * Draw the points
   */
  private void drawPoints() {
    if (pointHistory.size() < 1) return;
    
    // Draw all points in the history
    for (int i = 0; i < pointHistory.size(); i++) {
      DACPoint point = pointHistory.get(i);
      
      // Skip blanking points
      if (isBlanking(point)) {
        continue;
      }
      
      PVector pos = dacToScreen(point);
      
      // Map RGB values from DAC range to Processing RGB range
      float r = map(point.r, 0, 65535, 0, 255);
      float g = map(point.g, 0, 65535, 0, 255);
      float b = map(point.b, 0, 65535, 0, 255);
      
      // Draw the point
      canvas.noStroke();
      canvas.fill(r, g, b, 230); // Increased alpha
      canvas.ellipse(pos.x, pos.y, pointSize * 1.5, pointSize * 1.5); // Larger points
    }
  }
  
  /**
   * Draw motion blur effect
   */
  private void drawMotionBlur() {
    int startIdx = max(0, pointHistory.size() - blurTrailLength);
    
    for (int i = startIdx; i < pointHistory.size(); i++) {
      DACPoint point = pointHistory.get(i);
      
      // Skip blanking points
      if (isBlanking(point)) {
        continue;
      }
      
      PVector pos = dacToScreen(point);
      float alpha = map(i, startIdx, pointHistory.size(), 50, 150);
      float intensity = intensityHistory.get(i);
      
      // Map RGB values from DAC range to Processing RGB range
      float r = map(point.r, 0, 65535, 0, 255) * intensity;
      float g = map(point.g, 0, 65535, 0, 255) * intensity;
      float b = map(point.b, 0, 65535, 0, 255) * intensity;
      
      // Draw the glow effect
      canvas.noStroke();
      canvas.fill(r, g, b, alpha / 3);
      float size = map(i, startIdx, pointHistory.size(), 15, 5);
      canvas.ellipse(pos.x, pos.y, size, size);
    }
  }
  
  /**
   * Convert DAC coordinates to screen coordinates
   */
  private PVector dacToScreen(DACPoint point) {
    // DAC coordinates range from -32767 to 32767
    float x = map(point.x, -32767, 32767, 0, canvasWidth);
    float y = map(point.y, 32767, -32767, 0, canvasHeight); // Y is inverted
    return new PVector(x, y);
  }
  
  /**
   * Check if a point is a blanking point (no visible beam)
   */
  private boolean isBlanking(DACPoint point) {
    return (point.r == 0 && point.g == 0 && point.b == 0);
  }
  
  /**
   * Toggle showing points
   */
  public void togglePoints() {
    showPoints = !showPoints;
  }
  
  /**
   * Toggle showing beam
   */
  public void toggleBeam() {
    showBeam = !showBeam;
  }
  
  /**
   * Toggle velocity-based coloring
   */
  public void toggleVelocityColors() {
    showVelocityColors = !showVelocityColors;
  }
  
  /**
   * Toggle motion blur
   */
  public void toggleMotionBlur() {
    showMotionBlur = !showMotionBlur;
  }
  
  /**
   * Set point size
   */
  public void setPointSize(int size) {
    this.pointSize = size;
  }
  
  /**
   * Set blur trail length
   */
  public void setBlurTrailLength(int length) {
    this.blurTrailLength = length;
  }
  
  /**
   * Set velocity scale for visualization
   */
  public void setVelocityScale(float scale) {
    this.velocityScale = scale;
  }
  
  /**
   * Reset the visualizer
   */
  public void reset() {
    pointHistory.clear();
    velocityHistory.clear();
    intensityHistory.clear();
    lastPosition = new PVector(0, 0);
    currentVelocity = new PVector(0, 0);
  }
}
