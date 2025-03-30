/**
 * Callback.pde
 * 
 * Contains the LaserVisualizerCallback class that handles
 * communication between the plugins and the DAC.
 */

/**
 * LaserVisualizerCallback - implementation of LaserCallback for visualization
 */
class LaserVisualizerCallback implements LaserCallback {
  private SimulatedDAC simulatedDAC;
  private ArrayList<PVector> originalPoints;
  private ArrayList<RenderPriority> originalPriorities;
  private ArrayList<PVector> enhancedPoints;
  private ArrayList<Integer> enhancedColors;
  private ArrayList<PVector> physicsPoints;
  
  public LaserVisualizerCallback(SimulatedDAC dac) {
    this.simulatedDAC = dac;
    this.originalPoints = new ArrayList<PVector>();
    this.originalPriorities = new ArrayList<RenderPriority>();
    this.enhancedPoints = new ArrayList<PVector>();
    this.enhancedColors = new ArrayList<Integer>();
    this.physicsPoints = new ArrayList<PVector>();
  }
  
  @Override
  public void sendPoints(ArrayList<DACPoint> points) {
    // Store enhanced points (after BangBang processing)
    enhancedPoints.clear();
    enhancedColors.clear();
    
    for (DACPoint p : points) {
      enhancedPoints.add(new PVector(p.x, p.y));
      enhancedColors.add(p.r);
      enhancedColors.add(p.g);
      enhancedColors.add(p.b);
    }
    
    // Send to simulated DAC for physics processing
    simulatedDAC.sendPoints(points);
  }
  
  public void recordOriginalPoints(ArrayList<PVector> points, ArrayList<RenderPriority> priorities) {
    this.originalPoints = new ArrayList<PVector>(points);
    this.originalPriorities = new ArrayList<RenderPriority>(priorities);
  }
  
  @Override
  public boolean isLaserConnected() {
    // Always return true for visualization
    return true;
  }
  
  @Override
  public int getMaxPoints() {
    // Return a reasonable max points per frame
    return 1000;
  }
  
  @Override
  public int getPointRate() {
    // Return the point rate from galvo parameters
    return (int)galvoParams.pointsPerSecond;
  }
  
  @Override
  public int getBufferFillPercentage() {
    // Return simulated buffer fill
    return simulatedDAC.getBufferFillPercentage();
  }
  
  @Override
  public int getAvailablePointCapacity() {
    // Return simulated available capacity
    return 1000 - simulatedDAC.getBufferFillPercentage() * 10;
  }
  
  @Override
  public int getActualPointRate() {
    // Return the actual point rate
    return (int)galvoParams.pointsPerSecond;
  }
  
  @Override
  public long getLastFrameRenderTime() {
    // Return simulated render time
    return (long)(1000000.0 / frameRate);
  }
  
  // Getters for visualization data
  public ArrayList<PVector> getOriginalPoints() {
    return originalPoints;
  }
  
  public ArrayList<RenderPriority> getOriginalPriorities() {
    return originalPriorities;
  }
  
  public ArrayList<PVector> getEnhancedPoints() {
    return enhancedPoints;
  }
  
  public ArrayList<Integer> getEnhancedColors() {
    return enhancedColors;
  }
  
  public ArrayList<PVector> getPhysicsPoints() {
    return simulatedDAC.getPhysicsTracePoints();
  }
}
