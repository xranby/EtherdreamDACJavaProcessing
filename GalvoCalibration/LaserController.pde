/**
 * LaserController.pde
 * 
 * Etherdream DAC integration for the galvanometer calibration system.
 * Provides direct control of the laser hardware with physics-based calibration.
 * Updated to support plugin system integration.
 */

class LaserController {
  PApplet parent;
  
  // Etherdream instance
  Etherdream etherdream;
  
  // Hardware connection status
  boolean connected = false;
  String deviceName = "None";
  String deviceStatus = "Not connected";
  
  // Hardware limits (Etherdream uses 16-bit signed values)
  final int MI = -32767;
  final int MX = 32767;
  
  // Configuration
  int maxPointRate = 34384; // Hardware point rate limit (will be updated from DAC)
  float brightnessScale = 1.0; // Overall brightness scaling
  boolean safetyLimitsEnabled = true; // Enable safety limits
  
  // Point tracking for callback
  ArrayList<PVector> currentPoints = new ArrayList<PVector>();
  ArrayList<DACPoint> dacPoints = new ArrayList<DACPoint>();
  
  // Test pattern for initialization
  DACPoint[] testPattern = null;
  
  // Mock mode for testing without hardware
  boolean mockMode = false;
  
  LaserController(PApplet parent) {
    this.parent = parent;
    
    // Initialize test pattern (simple square)
    createTestPattern();
    
    // Initialize Etherdream controller
    try {
      log("Initializing Etherdream DAC...");
      etherdream = new Etherdream(parent);
      connected = true;
      deviceName = "Etherdream DAC";
      deviceStatus = "Initializing...";
      
      // Configure the DAC
      etherdream.configure(800, true); // 800 max points, debug enabled
      etherdream.configureBuffer(0.65f, 34384); // 65% buffer utilization, 34K points/sec
      
      log("Etherdream DAC initialized. Waiting for connection...");
    } catch (Exception e) {
      log("Error initializing Etherdream: " + e.getMessage());
      e.printStackTrace();
      
      // Fall back to mock mode
      mockMode = true;
      connected = false;
      deviceName = "Error";
      deviceStatus = "Error: " + e.getMessage();
    }
  }
  
  /**
   * Create a test pattern (square) for initialization
   */
  void createTestPattern() {
    testPattern = new DACPoint[5];
    
    // Create a square
    testPattern[0] = new DACPoint(-10000, -10000, 65535, 65535, 65535); // Bottom-left
    testPattern[1] = new DACPoint(10000, -10000, 65535, 65535, 65535);  // Bottom-right
    testPattern[2] = new DACPoint(10000, 10000, 65535, 65535, 65535);   // Top-right
    testPattern[3] = new DACPoint(-10000, 10000, 65535, 65535, 65535);  // Top-left
    testPattern[4] = new DACPoint(-10000, -10000, 65535, 65535, 65535); // Back to Bottom-left
  }
  
  /**
   * Check if laser is ready for output
   */
  boolean isReady() {
    return connected || mockMode;
  }
  
  /**
   * Send Processing PVector points to the laser
   * This converts the points to DAC format
   */
  void sendPoints(ArrayList<PVector> points) {
    // Store current points for rendering
    synchronized(currentPoints) {
      currentPoints.clear();
      if (points != null) {
        currentPoints.addAll(points);
      }
    }
    
    // Convert to DAC points
    ArrayList<DACPoint> convertedPoints = new ArrayList<DACPoint>();
    
    if (points != null) {
      for (PVector p : points) {
        // Map from screen coordinates to laser coordinates
        int x = (int)map(p.x, 0, width, MI, MX);
        int y = (int)map(p.y, 0, height, MX, MI); // Y is inverted
        
        // Add to DAC points list
        convertedPoints.add(new DACPoint(x, y, 65535, 65535, 65535));
      }
    }
    
    // Send converted points
    sendDACPoints(convertedPoints);
  }
  
  /**
   * Send DAC points directly to the laser
   * This is used by plugins and the calibration system
   */
  void sendDACPoints(ArrayList<DACPoint> points) {
    // Store DAC points for the Etherdream callback
    synchronized(dacPoints) {
      dacPoints.clear();
      if (points != null) {
        dacPoints.addAll(points);
      }
    }
  }
  
  /**
   * Special method for camera calibration - send a specific point
   * without blanking (all are illuminated)
   */
  void sendCalibrationPoint(int x, int y) {
    synchronized(currentPoints) {
      currentPoints.clear();
      currentPoints.add(new PVector(x, y));
    }
    
    ArrayList<DACPoint> calibPoints = new ArrayList<DACPoint>();
    
    // Map from screen coordinates to laser coordinates
    int lx = (int)map(x, 0, width, MI, MX);
    int ly = (int)map(y, 0, height, MX, MI); // Y is inverted
    
    // Just send a single bright point
    calibPoints.add(new DACPoint(lx, ly, 65535, 65535, 65535));
    
    // Send to laser
    sendDACPoints(calibPoints);
  }
  
  /**
   * Draw connection status on the UI
   */
  void drawStatus(int x, int y) {
    // Draw connection status
    fill(0, 0, 0, 200);
    noStroke();
    rect(x, y, 250, 90);
    
    // Status text
    fill(255);
    textAlign(LEFT);
    textSize(12);
    text("Etherdream DAC Status", x + 10, y + 20);
    
    // Connection status indicator
    if (connected) {
      fill(0, 255, 0);
    } else if (mockMode) {
      fill(255, 255, 0);
    } else {
      fill(255, 0, 0);
    }
    ellipse(x + 15, y + 35, 10, 10);
    
    // Status details
    fill(255);
    text(deviceName, x + 30, y + 35);
    text(deviceStatus, x + 30, y + 50);
    
    // Mock mode indicator
    if (mockMode) {
      fill(255, 255, 0);
      text("[MOCK MODE]", x + 150, y + 35);
    }
    
    // Performance stats
    if (etherdream != null) {
      text(etherdream.getStats(), x + 30, y + 70);
    }
  }
  
  /**
   * Shutdown laser and close connection
   */
  void shutdown() {
    // Nothing special needed for shutdown
    // The Etherdream library handles cleanup with daemon threads
    connected = false;
  }
  
  /**
   * This is the callback method required by the Etherdream library
   * It MUST be implemented in the main sketch and will be called to get points
   * The main sketch forwards the call to this method
   */
  DACPoint[] getDACPoints() {
    if (mockMode) {
      return testPattern;
    }
    
    DACPoint[] points;
    
    // Get current set of points from synchronized list
    synchronized(dacPoints) {
      if (dacPoints.isEmpty()) {
        // Return test pattern if no points available
        return testPattern;
      }
      
      // Convert to array
      points = new DACPoint[dacPoints.size()];
      for (int i = 0; i < dacPoints.size(); i++) {
        points[i] = dacPoints.get(i);
      }
    }
    
    // Update device status
    deviceStatus = "Connected - " + points.length + " points";
    
    return points;
  }
  
  /**
   * Get maximum point rate supported by the DAC
   */
  int getMaxPointRate() {
    return maxPointRate;
  }
  
  /**
   * Get maximum points per frame supported by the DAC
   */
  int getMaxPoints() {
    return 600; // Default safe value for Etherdream
  }
  
  /**
   * Utility logging function
   */
  void log(String message) {
    println("[LaserController] " + message);
  }
}
