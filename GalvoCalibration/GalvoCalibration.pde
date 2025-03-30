/**
 * Advanced Galvanometer Calibration System with Plugin Support
 *
 * An automated system to calibrate laser galvanometer parameters
 * using webcam feedback for true closed-loop optimization.
 * Now includes plugin support for running CosmicGroove and other creative apps.
 *
 * This multi-file project consists of:
 * - GalvoCalibration.pde (main file)
 * - PluginInterface.pde (plugin system)
 * - CosmicGroovePlugin.pde (sound-reactive laser show)
 * - GalvoCallbacks.pde (Etherdream DAC callbacks)
 * - TestPatterns.pde (pattern generation)
 * - PhysicsSimulation.pde (galvo physics)
 * - CameraCapture.pde (webcam integration)
 * - AutoCalibrator.pde (optimization algorithms)
 * - UIManager.pde (interface elements)
 * - DataManager.pde (data handling)
 * - LaserController.pde (Etherdream interface)
 */

import processing.video.*;
import gab.opencv.*;
import java.awt.Rectangle;

// Global variables
enum AppMode {
  MANUAL_CALIBRATION,
  AUTO_CALIBRATION,
  CAMERA_SETUP,
  PARAMETER_EXPORT,
  LIVE_TESTING,
  PLUGIN_MODE, // Plugin mode
  VISUALIZATION_MODE // Visualization mode
}

// Current application state
AppMode currentMode = AppMode.MANUAL_CALIBRATION;
TestPattern currentPattern;
PhysicsSimulator physics;
CameraCapture camera;
AutoCalibrator calibrator;
UIManager ui;
DataManager dataManager;
LaserController laser;
PluginManager pluginManager; // Plugin manager
VisualizationMode visualizer; // Visualization mode
PointOutputDisplay pointDisplay; // Point output display

// Laser callback for plugins
LaserCallback laserCallbackImpl;

// Calibration parameters
GalvoParameters params;
boolean isSimulationRunning = true;
int frameCounter = 0;

// UI positioning for plugin selector
int pluginSelectorX = 150;
int pluginSelectorY = 10;
int pluginSelectorWidth = 200;
int pluginSelectorHeight = 30;

void setup() {
  size(1280, 720);
  frameRate(60);
  
  // Initialize core modules
  params = new GalvoParameters();
  physics = new PhysicsSimulator(params);
  currentPattern = new TestPattern(params);
  dataManager = new DataManager(params);
  
  // Initialize hardware-dependent modules
  setupLaser();
  setupCamera();
  
  // Set up laser callback for plugins
  laserCallbackImpl = new LaserCallbackImpl();
  
  // Create plugin manager
  pluginManager = new PluginManager(laserCallbackImpl);
  
  // Initialize plugins
  initializePlugins();
  
  // Initialize visualization mode
  visualizer = new VisualizationMode(this, pluginManager, physics);
  
  // Initialize point output display
  pointDisplay = new PointOutputDisplay();
  
  // Initialize UI after plugins are loaded
  ui = new UIManager(this);
  
  // Initialize auto-calibrator (requires both camera and laser)
  if (camera != null && laser != null) {
    calibrator = new AutoCalibrator(params, physics, camera, laser);
  }
  
  // Load last saved config (if exists)
  dataManager.loadConfig();
  
  // Set initial test pattern
  currentPattern.setPattern(PatternType.STEP_RESPONSE);
  
  // Show startup message
  println("Galvanometer Calibration System initialized");
  println("Using Etherdream DAC for laser control");
  println("Loaded " + pluginManager.getPluginCount() + " plugins");
}

void draw() {
  background(0);
  frameCounter++;
  
      pluginManager.draw();
  // Special handling for visualization mode
  if (currentMode == AppMode.VISUALIZATION_MODE) {
    visualizer.update();
    visualizer.draw();
    drawPluginSelector();
    return;
  }
  
  // Plugin mode runs separately from other modes
  if (currentMode == AppMode.PLUGIN_MODE) {
    if (pluginManager.getActivePlugin() != null) {
      // Update point display with current plugin points
      pointDisplay.update(pluginManager.getActivePlugin());
      
      // Draw the plugin
      pluginManager.draw();
      
      // Draw point display on top of plugin
      pointDisplay.draw();
    }
    drawPluginUI();
  } else {
    // Update pattern
    currentPattern.update(frameCounter);
    
    // Main application workflow based on current mode
    switch(currentMode) {
      case MANUAL_CALIBRATION:
        updateManualCalibration();
        break;
        
      case AUTO_CALIBRATION:
        updateAutoCalibration();
        break;
        
      case CAMERA_SETUP:
        updateCameraSetup();
        break;
        
      case PARAMETER_EXPORT:
        updateParameterExport();
        break;
        
      case LIVE_TESTING:
        break;
    }
    
    // Draw UI
    ui.draw(currentMode);
    
        updateLiveTesting();
  }
  
  // Draw plugin selector in all modes
  drawPluginSelector();
}

void drawPluginSelector() {
  // Draw plugin selector
  fill(0, 0, 0, 200);
  noStroke();
  rect(pluginSelectorX, pluginSelectorY, pluginSelectorWidth, pluginSelectorHeight);
  
  // Draw text
  if (currentMode == AppMode.PLUGIN_MODE) {
    fill(255, 255, 0); // Highlight when in plugin mode
  } else if (currentMode == AppMode.VISUALIZATION_MODE) {
    fill(0, 255, 255); // Cyan for visualization mode
  } else {
    fill(255);
  }
  textAlign(CENTER, CENTER);
  textSize(14);
  
  String modeName = "Calibration";
  if (currentMode == AppMode.PLUGIN_MODE && pluginManager.getActivePlugin() != null) {
    modeName = pluginManager.getActivePlugin().getName();
  } else if (currentMode == AppMode.VISUALIZATION_MODE) {
    modeName = "Visualization";
  }
  
  text("Mode: " + modeName, 
       pluginSelectorX + pluginSelectorWidth/2, 
       pluginSelectorY + pluginSelectorHeight/2);
}

void drawPluginUI() {
  // Draw small help UI when in plugin mode
  fill(0, 0, 0, 150);
  noStroke();
  rect(10, height - 35, 600, 25);
  
  fill(255);
  textAlign(LEFT, CENTER);
  textSize(12);
  text("Press 'P' to switch plugins, 'V' for visualization, 'O' to show point output, ESC to exit plugin mode", 
       20, height - 23);
}

void updateManualCalibration() {
  // Simulate galvo physics on the current pattern
  if (isSimulationRunning) {
    physics.update(currentPattern.getPoints());
    
    // Send to laser if in live mode
    if (laser != null && laser.isReady()) {
      updateLaser(currentPattern.getPoints(), physics);
    }
  }
  
  // Draw pattern and simulated output
  currentPattern.draw();
  physics.draw();
  
  // Calculate and display metrics
  physics.calculateMetrics();
}

void updateAutoCalibration() {
  if (calibrator != null) {
    calibrator.update();
    calibrator.draw();
  } else {
    // Show instructions for setting up camera and laser
    ui.showHardwareRequiredMessage();
  }
}

void updateCameraSetup() {
  // Show camera feed with detection overlay
  if (camera != null) {
    camera.update();
    camera.draw();
  } else {
    ui.showCameraRequiredMessage();
  }
}

void updateParameterExport() {
  // Show export options and preview
  ui.drawExportOptions();
  
  // Draw pattern and physics for reference
  currentPattern.draw();
  physics.draw();
}

void updateLiveTesting() {
  // Test with real hardware
  if (laser != null && laser.isReady()) {
    // Update pattern
    currentPattern.update(frameCounter);
    
    // Apply physics simulation
    ArrayList<PVector> simPoints = physics.processPoints(currentPattern.getPoints());
    
    // Send points to laser
    laser.sendPoints(simPoints);
    
    // Draw pattern for reference
    currentPattern.draw();
    
    // If camera available, show actual position
    if (camera != null) {
      camera.update();
      camera.drawLaserDetection();
    }
  } else {
    ui.showLaserRequiredMessage();
  }
  
  // Draw laser status
  if (laser != null) {
    laser.drawStatus(10, height - 120);
  }
}

void setupCamera() {
  try {
    camera = new CameraCapture(this);
    println("Camera initialized successfully");
  } catch (Exception e) {
    println("Camera initialization error: " + e.getMessage());
    camera = null;
  }
}

void setupLaser() {
  try {
    laser = new LaserController(this);
    println("Laser initialized successfully");
  } catch (Exception e) {
    println("Laser initialization error: " + e.getMessage());
    laser = null;
  }
}

void initializePlugins() {
  // Create and register CosmicGroove plugin
  CosmicGroovePlugin cosmicGroove = new CosmicGroovePlugin(this);
  pluginManager.registerPlugin(cosmicGroove);
  
  // Register calibration as a "plugin" so we can switch back easily
  CalibrationPlugin calibrationPlugin = new CalibrationPlugin(this);
  pluginManager.registerPlugin(calibrationPlugin);
  
  // Additional plugins could be registered here
}

void keyPressed() {
  // Global key handlers for all modes
  if (key == TAB) {
    // In special modes, tab exits to calibration
    if (currentMode == AppMode.PLUGIN_MODE || currentMode == AppMode.VISUALIZATION_MODE) {
      currentMode = AppMode.MANUAL_CALIBRATION;
    } else {
      // Cycle through calibration modes
      int nextMode = (currentMode.ordinal() + 1) % (AppMode.values().length - 2); // Skip PLUGIN_MODE and VISUALIZATION_MODE
      currentMode = AppMode.values()[nextMode];
    }
    return;
  } else if (key == 'p' || key == 'P') {
    if (currentMode == AppMode.PLUGIN_MODE) {
      // Next plugin
      pluginManager.nextPlugin();
    } else {
      // Enter plugin mode
      currentMode = AppMode.PLUGIN_MODE;
    }
    return;
  } else if (key == 'v' || key == 'V') {
    // Toggle visualization mode
    if (currentMode == AppMode.VISUALIZATION_MODE) {
      // Exit to previous mode
      currentMode = AppMode.PLUGIN_MODE;
    } else {
      // Enter visualization mode
      currentMode = AppMode.VISUALIZATION_MODE;
      visualizer.toggle();
    }
    return;
  } else if (key == 'o' || key == 'O') {
    // Toggle point output display (in plugin mode)
    if (currentMode == AppMode.PLUGIN_MODE) {
      pointDisplay.toggle();
    }
    return;
  } else if (key == 't' || key == 'T') {
    // Run laser test pattern
    runLaserTestPattern();
    return;
  }
  
  // Mode-specific key handlers
  if (currentMode == AppMode.VISUALIZATION_MODE) {
    visualizer.keyPressed();
  } else if (currentMode == AppMode.PLUGIN_MODE) {
    // Forward key events to active plugin
    pluginManager.keyPressed();
  } else {
    // Pass key events to UI
    ui.keyPressed();
  }
}

void keyReleased() {
  if (currentMode == AppMode.PLUGIN_MODE) {
    pluginManager.keyReleased();
  }
}

void mousePressed() {
  // Check plugin selector first
  if (mouseX >= pluginSelectorX && mouseX <= pluginSelectorX + pluginSelectorWidth &&
      mouseY >= pluginSelectorY && mouseY <= pluginSelectorY + pluginSelectorHeight) {
    // Toggle between plugin mode and calibration mode
    if (currentMode == AppMode.PLUGIN_MODE) {
      currentMode = AppMode.MANUAL_CALIBRATION;
    } else {
      currentMode = AppMode.PLUGIN_MODE;
    }
    return;
  }
  
  // Forward mouse events based on mode
  if (currentMode == AppMode.PLUGIN_MODE) {
    pluginManager.mousePressed();
  } else {
    ui.mousePressed();
  }
}

void mouseDragged() {
  if (currentMode == AppMode.PLUGIN_MODE) {
    pluginManager.mouseDragged();
  } else {
    ui.mouseDragged();
  }
}

void mouseReleased() {
  if (currentMode == AppMode.PLUGIN_MODE) {
    pluginManager.mouseReleased();
  } else {
    ui.mouseReleased();
  }
}

/**
 * Implementation of the LaserCallback interface for plugins
 */
class LaserCallbackImpl implements LaserCallback {
  public void sendPoints(ArrayList<DACPoint> points) {
    // Forward points to the laser controller
    if (laser != null && laser.isReady()) {
      laser.sendDACPoints(points);
    }
  }
  
  public boolean isLaserConnected() {
    return laser != null && laser.isReady();
  }
  
  public int getMaxPoints() {
    return 600; // Default value
  }
  
  public int getPointRate() {
    return 34384; // Default point rate
  }
}

/**
 * Special "plugin" that represents the calibration system
 * This allows switching back to calibration mode easily
 */
class CalibrationPlugin implements LaserPlugin {
  PApplet parent;
  
  CalibrationPlugin(PApplet parent) {
    this.parent = parent;
  }
  
  public void setup() {
    // Nothing to set up
  }
  
  public void draw() {
    // This won't actually be called, as we'll switch back to regular mode
  }
  
  public void cleanup() {
    // Nothing to clean up
  }
  
  public void keyPressed() {}
  public void keyReleased() {}
  public void mousePressed() {}
  public void mouseDragged() {}
  public void mouseReleased() {}
  
  public String getName() {
    return "Calibration System";
  }
  
  public String getDescription() {
    return "Galvanometer calibration and testing tools";
  }
  
  public ArrayList<DACPoint> getPoints() {
    return new ArrayList<DACPoint>();
  }
  
  public void setLaserCallback(LaserCallback callback) {
    // Nothing to do
  }
}

// This class stores and manages all galvo parameters
class GalvoParameters {
  // Main physics parameters
  float springConstant = 0.8;    // Spring stiffness (0.1-2.0)
  float dampingRatio = 0.65;     // Damping ratio (0.1-2.0, 1.0 is critical damping)
  float naturalFrequency = 250;   // Natural frequency in Hz (10-100)
  float pointsPerSecond = 34384; // Points per second capability
  float accelerationLimit = 1000; // Maximum acceleration limit (0.05-1.0)
  float cornerSmoothing = 0.5;   // Corner smoothing factor (0.1-1.0)

  // Derived constants
  float angularFrequency;        // Calculated from naturalFrequency
  float samplePeriod;            // Calculated from pointsPerSecond

  // Pattern parameters
  float patternSpeed = 0.5;      // Speed of moving patterns
  float patternSize = 0.8;       // Size of patterns (relative to display)
  float patternComplexity = 0.5; // Pattern complexity (0.1-1.0)

  // Calibration metrics
  float avgError = 0;            // Average position error
  float maxError = 0;            // Maximum position error
  float overshootMetric = 0;     // Overshoot metric
  float cornerMetric = 0;        // Corner handling metric

  GalvoParameters() {
    updateDerivedParams();
  }

  void updateDerivedParams() {
    angularFrequency = naturalFrequency * TWO_PI;
    samplePeriod = 1.0 / pointsPerSecond;
  }
  
  void setFromArray(float[] values) {
    springConstant = values[0];
    dampingRatio = values[1];
    naturalFrequency = values[2];
    pointsPerSecond = values[3];
    accelerationLimit = values[4];
    cornerSmoothing = values[5];
    patternSpeed = values[6];
    patternSize = values[7];
    patternComplexity = values[8];
    updateDerivedParams();
  }
  
  float[] toArray() {
    return new float[] {
      springConstant,
      dampingRatio,
      naturalFrequency,
      pointsPerSecond,
      accelerationLimit,
      cornerSmoothing,
      patternSpeed,
      patternSize,
      patternComplexity
    };
  }
  
  String[] getParamLabels() {
    return new String[] {
      "Spring Constant",
      "Damping Ratio",
      "Natural Frequency (Hz)",
      "Points Per Second",
      "Acceleration Limit",
      "Corner Smoothing",
      "Pattern Speed",
      "Pattern Size",
      "Pattern Complexity"
    };
  }
  
  float[] getParamMin() {
    return new float[] {0.1, 0.1, 10, 1000, 0.05, 0.1, 0.1, 0.1, 0.1};
  }
  
  float[] getParamMax() {
    return new float[] {2.0, 2.0, 100, 100000, 1.0, 1.0, 2.0, 1.0, 1.0};
  }
  
  float[] getParamStep() {
    return new float[] {0.05, 0.05, 1, 1000, 0.01, 0.05, 0.05, 0.05, 0.05};
  }
  
  void copyFrom(GalvoParameters other) {
    this.springConstant = other.springConstant;
    this.dampingRatio = other.dampingRatio;
    this.naturalFrequency = other.naturalFrequency;
    this.pointsPerSecond = other.pointsPerSecond;
    this.accelerationLimit = other.accelerationLimit;
    this.cornerSmoothing = other.cornerSmoothing;
    this.patternSpeed = other.patternSpeed;
    this.patternSize = other.patternSize;
    this.patternComplexity = other.patternComplexity;
    updateDerivedParams();
  }
}
