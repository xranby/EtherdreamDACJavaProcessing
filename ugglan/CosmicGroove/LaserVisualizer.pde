/**
 * LaserVisualizer.pde
 * 
 * A visualizer for Etherdream laser DAC outputs without requiring actual hardware
 * Shows the laser beam path, points, and movement characteristics
 * Thread-safe version - draw() and update() can be called from different threads
 */

import java.util.concurrent.locks.ReentrantReadWriteLock;
import java.util.concurrent.locks.Lock;

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
  
  // Thread synchronization
  private final ReentrantReadWriteLock rwLock = new ReentrantReadWriteLock();
  private final Lock readLock = rwLock.readLock();
  private final Lock writeLock = rwLock.writeLock();
  
  // Laser point history for visualization - these are shared between threads
  // Volatile for thread visibility
  private volatile ArrayList<DACPoint> pointHistory = new ArrayList<DACPoint>();
  private volatile ArrayList<PVector> velocityHistory = new ArrayList<PVector>();
  private volatile ArrayList<Float> intensityHistory = new ArrayList<Float>();
  
  // UI components
  private PGraphics canvas;                   // Drawing canvas
  private volatile PVector lastPosition;      // Last position of laser - make volatile for visibility
  private volatile PVector currentVelocity;   // Current velocity of laser - make volatile for visibility
  
  // Volatile flag to signal new data is available
  private volatile boolean dataUpdated = false;
  
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
    writeLock.lock();
    try {
      for (int i = 0; i < 10; i++) {
        float angle = map(i, 0, 10, 0, TWO_PI);
        int x = (int)(cos(angle) * 10000);
        int y = (int)(sin(angle) * 10000);
        
        DACPoint testPoint = new DACPoint(x, y, 65535, 0, 0);
        pointHistory.add(testPoint);
        velocityHistory.add(new PVector(0, 0));
        intensityHistory.add(1.0f);
      }
    } finally {
      writeLock.unlock();
    }
    
    println("LaserVisualizer initialized with canvas size: " + width + "x" + height);
  }
  
  /**
   * Update the visualizer with new points
   * This method is called from a separate thread
   */
  public void update(DACPoint[] points) {
    if (points == null || points.length == 0) return;
    
    // Debug - show point count
    println("Visualizer received " + points.length + " points");
    
    // Create thread-local temporary buffers for the new data
    ArrayList<DACPoint> newPoints = new ArrayList<DACPoint>(points.length);
    ArrayList<PVector> newVelocities = new ArrayList<PVector>(points.length);
    ArrayList<Float> newIntensities = new ArrayList<Float>(points.length);
    
    // Create a local copy of lastPosition to avoid locking during calculation
    PVector localLastPosition;
    PVector localCurrentVelocity;
    
    // Get the current position/velocity values under read lock
    readLock.lock();
    try {
      localLastPosition = lastPosition.copy();
      localCurrentVelocity = currentVelocity.copy();
    } finally {
      readLock.unlock();
    }
    
    // Process ALL new points - no sampling
    for (int i = 0; i < points.length; i++) {
      DACPoint point = points[i];
      
      // Add to our new points collection
      newPoints.add(point);
      
      // Calculate current position in screen coordinates
      PVector currentPos = dacToScreen(point);
      
      // Calculate velocity
      PVector velocity = PVector.sub(currentPos, localLastPosition);
      localCurrentVelocity.lerp(velocity, 0.3); // Smooth the velocity
      newVelocities.add(localCurrentVelocity.copy());
      
      // Calculate intensity based on RGB values
      float intensity = (point.r + point.g + point.b) / (float)(3 * 65535);
      newIntensities.add(intensity);
      
      // Update last position
      localLastPosition = currentPos.copy();
    }
    
    // Ensure all three collections have exactly the same size
    int minSize = Math.min(Math.min(newPoints.size(), newVelocities.size()), newIntensities.size());
    if (newPoints.size() > minSize) newPoints.subList(minSize, newPoints.size()).clear();
    if (newVelocities.size() > minSize) newVelocities.subList(minSize, newVelocities.size()).clear();
    if (newIntensities.size() > minSize) newIntensities.subList(minSize, newIntensities.size()).clear();
    
    // Now acquire the write lock to update the shared data
    writeLock.lock();
    try {
      // Replace the shared collections atomically
      pointHistory = new ArrayList<DACPoint>(newPoints);
      velocityHistory = new ArrayList<PVector>(newVelocities);
      intensityHistory = new ArrayList<Float>(newIntensities);
      
      // Update the shared position/velocity states
      lastPosition = localLastPosition;
      currentVelocity = localCurrentVelocity;
      
      // Set the flag to indicate new data is available
      dataUpdated = true;
    } finally {
      writeLock.unlock();
    }
    
    // Debug - show how many points are now in the history
    println("Visualizer pointHistory now contains " + newPoints.size() + " points");
  }
  
  /**
   * Draw the visualization
   * This method is called from the main Processing thread
   */
  public void draw() {
    // Create local copies of data to minimize lock duration
    ArrayList<DACPoint> localPointHistory;
    ArrayList<PVector> localVelocityHistory;
    ArrayList<Float> localIntensityHistory;
    int localPointCount;
    
    // Acquire read lock to copy data - create deep copies to prevent any chance of concurrent modification
    readLock.lock();
    try {
      localPointHistory = new ArrayList<DACPoint>(pointHistory);
      localVelocityHistory = new ArrayList<PVector>(velocityHistory);
      localIntensityHistory = new ArrayList<Float>(intensityHistory);
      localPointCount = pointHistory.size();
      dataUpdated = false; // Reset the updated flag
    } finally {
      readLock.unlock();
    }
    
    canvas.beginDraw();
    canvas.background(0); // Solid black background for better contrast
    
    // Debug info - display point count
    canvas.fill(255);
    canvas.textSize(14);
    canvas.text("Points: " + localPointCount, 10, 20);
    
    // Debug - draw a test pattern if no points are available
    if (localPointCount < 2) {
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
    if (showMotionBlur && localPointCount > blurTrailLength) {
      drawMotionBlur(localPointHistory, localIntensityHistory);
    }
    
    // Draw beam path if enabled
    if (showBeam) {
      drawBeamPath(localPointHistory, localVelocityHistory);
    }
    
    // Draw points if enabled
    if (showPoints) {
      drawPoints(localPointHistory);
    }
    
    canvas.endDraw();
    image(canvas, 0, 0);
  }
  
  /**
   * Draw the laser beam path
   */
  private void drawBeamPath(ArrayList<DACPoint> points, ArrayList<PVector> velocities) {
    if (points.size() < 2) return;
    
    // Draw all points in the history
    for (int i = 0; i < points.size() - 1; i++) {
      DACPoint current = points.get(i);
      DACPoint next = points.get(i + 1);
      
      // Skip blanking segments (where RGB values are all 0)
      if (isBlanking(current) && isBlanking(next)) {
        continue;
      }
      
      PVector pos1 = dacToScreen(current);
      PVector pos2 = dacToScreen(next);
      
      // Calculate color based on velocity or use the actual beam color
      if (showVelocityColors) {
        // Velocity-based coloring
        PVector vel = velocities.get(i);
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
  private void drawPoints(ArrayList<DACPoint> points) {
    if (points.size() < 1) return;
    
    // Draw all points in the history
    for (int i = 0; i < points.size(); i++) {
      DACPoint point = points.get(i);
      
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
  private void drawMotionBlur(ArrayList<DACPoint> points, ArrayList<Float> intensities) {
    int startIdx = max(0, points.size() - blurTrailLength);
    
    for (int i = startIdx; i < points.size(); i++) {
      DACPoint point = points.get(i);
      
      // Skip blanking points
      if (isBlanking(point)) {
        continue;
      }
      
      PVector pos = dacToScreen(point);
      float alpha = map(i, startIdx, points.size(), 50, 150);
      
      // Check if we have a matching intensity value
      float intensity = 1.0f;
      if (i < intensities.size()) {
        intensity = intensities.get(i);
      }
      
      // Map RGB values from DAC range to Processing RGB range
      float r = map(point.r, 0, 65535, 0, 255) * intensity;
      float g = map(point.g, 0, 65535, 0, 255) * intensity;
      float b = map(point.b, 0, 65535, 0, 255) * intensity;
      
      // Draw the glow effect
      canvas.noStroke();
      canvas.fill(r, g, b, alpha / 3);
      float size = map(i, startIdx, points.size(), 15, 5);
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
    writeLock.lock();
    try {
      showPoints = !showPoints;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Toggle showing beam
   */
  public void toggleBeam() {
    writeLock.lock();
    try {
      showBeam = !showBeam;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Toggle velocity-based coloring
   */
  public void toggleVelocityColors() {
    writeLock.lock();
    try {
      showVelocityColors = !showVelocityColors;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Toggle motion blur
   */
  public void toggleMotionBlur() {
    writeLock.lock();
    try {
      showMotionBlur = !showMotionBlur;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Set point size
   */
  public void setPointSize(int size) {
    writeLock.lock();
    try {
      this.pointSize = size;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Set blur trail length
   */
  public void setBlurTrailLength(int length) {
    writeLock.lock();
    try {
      this.blurTrailLength = length;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Set velocity scale for visualization
   */
  public void setVelocityScale(float scale) {
    writeLock.lock();
    try {
      this.velocityScale = scale;
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Reset the visualizer
   */
  public void reset() {
    writeLock.lock();
    try {
      pointHistory.clear();
      velocityHistory.clear();
      intensityHistory.clear();
      lastPosition = new PVector(0, 0);
      currentVelocity = new PVector(0, 0);
    } finally {
      writeLock.unlock();
    }
  }
  
  /**
   * Get a copy of the current DAC points
   * This method can be called from any thread
   * @return An array of the current DAC points
   */
  public DACPoint[] getDACPoints() {
    readLock.lock();
    try {
      // Create a defensive copy of the points to ensure thread safety
      DACPoint[] points = new DACPoint[pointHistory.size()];
      
      // Copy each point (assuming DACPoint is immutable or we make a deep copy)
      for (int i = 0; i < pointHistory.size(); i++) {
        // If DACPoint has a copy constructor or clone method, use it here
        // Otherwise, we're returning a reference to the original point objects
        // which is okay if DACPoint is immutable (doesn't have setters)
        points[i] = pointHistory.get(i);
      }
      
      return points;
    } finally {
      readLock.unlock();
    }
  }
}
