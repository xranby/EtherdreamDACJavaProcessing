/**
 * EtherdreamVisualizer.pde
 * 
 * Extension of the Etherdream class with visualization capabilities
 * Adds a visual representation of laser output for testing without hardware
 */

class EtherdreamVisualizer extends Etherdream {
  // Visualization components
  private LaserVisualizer visualizer;
  private LaserUIController uiController;
  
  // Visualization mode
  private boolean simulationMode = true;
  private boolean isConnected = false;
  
  // Latest frame of points
  private DACPoint[] latestFrame;
  
  /**
   * Constructor
   */
  public EtherdreamVisualizer(PApplet processing) {
    super(processing);
    
    // Create visualizer with same dimensions as the processing sketch
    visualizer = new LaserVisualizer(processing.width, processing.height);
    uiController = new LaserUIController(visualizer);
    
    // Start with an empty frame
    latestFrame = new DACPoint[0];
  }
  
  /**
   * Enable or disable simulation mode
   */
  public void setSimulationMode(boolean enabled) {
    simulationMode = enabled;
  }
  
  /**
   * Get current simulation mode
   */
  public boolean isSimulationMode() {
    return simulationMode;
  }
  
  /**
   * Check if connected to a real DAC
   */
  public boolean isConnectedToDAC() {
    return isConnected;
  }
  
  /**
   * Set connection status (called from Etherdream parent class)
   */
  public void setConnected(boolean connected) {
    isConnected = connected;
  }
  
  /**
   * Store the latest frame for visualization
   */
  public void setLatestFrame(DACPoint[] frame) {
    if (frame != null) {
      this.latestFrame = frame;
      
      // Update the visualizer
      visualizer.update(frame);
    }
  }
  
  /**
   * Draw the visualization
   */
  public void draw() {
    visualizer.draw();
    uiController.draw();
    
    // Draw connection status
    fill(255);
    textAlign(RIGHT, TOP);
    if (isConnected) {
      fill(0, 255, 0);
      text("CONNECTED TO DAC", width - 20, 15);
    } else if (simulationMode) {
      fill(0, 180, 255);
      text("SIMULATION MODE", width - 20, 15);
    } else {
      fill(255, 100, 100);
      text("NOT CONNECTED", width - 20, 15);
    }
    
    // Show frame info
    textAlign(RIGHT, TOP);
    fill(255);
    text("Points: " + latestFrame.length, width - 20, 35);
  }
  
  /**
   * Handle mouse pressed events
   */
  public void mousePressed() {
    uiController.mousePressed();
  }
  
  /**
   * Handle mouse dragged events
   */
  public void mouseDragged() {
    uiController.mouseDragged();
  }
  
  /**
   * Handle mouse released events
   */
  public void mouseReleased() {
    uiController.mouseReleased();
  }
  
  /**
   * Handle key pressed events
   */
  public void keyPressed() {
    if (key == 'h' || key == 'H') {
      uiController.toggleUI();
    }
    else if (key == 's' || key == 'S') {
      simulationMode = !simulationMode;
    }
  }
}
