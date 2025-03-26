/**
 * Advanced Galvanometer Calibration System with Etherdream DAC Support
 *
 * An automated system to calibrate laser galvanometer parameters
 * using webcam feedback for true closed-loop optimization.
 *
 * This multi-file project consists of:
 * - GalvoCalibration.pde (main file)
 * - GalvoCallbacks.pde (Etherdream DAC callbacks)
 * - TestPatterns.pde (pattern generation)
 * - PhysicsSimulation.pde (galvo physics)
 * - CameraCapture.pde (webcam integration)
 * - AutoCalibrator.pde (optimization algorithms)
 * - UIManager.pde (interface elements)
 * - DataManager.pde (data handling)
 * - LaserController.pde (Etherdream interface)
 *
 * Requirements:
 * - Processing Video library
 * - Processing OpenCV library
 * - Etherdream DAC (or can run in simulation mode)
 * - Webcam with view of projection screen
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
  LIVE_TESTING
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

// Calibration parameters
GalvoParameters params;
boolean isSimulationRunning = true;
int frameCounter = 0;

void setup() {
  size(1280, 720);
  frameRate(60);
  
  // Initialize core modules
  params = new GalvoParameters();
  physics = new PhysicsSimulator(params);
  currentPattern = new TestPattern(params);
  dataManager = new DataManager(params);
  ui = new UIManager(this);
  
  // Initialize hardware-dependent modules
  setupLaser();
  setupCamera();
  
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
}

void draw() {
  background(0);
  frameCounter++;
  
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
      updateLiveTesting();
      break;
  }
  
  // Draw UI regardless of mode
  ui.draw(currentMode);
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

void keyPressed() {
  // Pass key events to UI
  ui.keyPressed();
  
  // Global shortcuts
  if (key == TAB) {
    // Cycle through modes
    currentMode = AppMode.values()[(currentMode.ordinal() + 1) % AppMode.values().length];
  } else if (key == 't' || key == 'T') {
    // Run laser test pattern
    runLaserTestPattern();
  }
}

void mousePressed() {
  ui.mousePressed();
}

void mouseDragged() {
  ui.mouseDragged();
}

void mouseReleased() {
  ui.mouseReleased();
}

// This class stores and manages all galvo parameters
class GalvoParameters {
  // Main physics parameters
  float springConstant = 0.8;    // Spring stiffness (0.1-2.0)
  float dampingRatio = 0.65;     // Damping ratio (0.1-2.0, 1.0 is critical damping)
  float naturalFrequency = 40;   // Natural frequency in Hz (10-100)
  float pointsPerSecond = 34384; // Points per second capability
  float accelerationLimit = 0.2; // Maximum acceleration limit (0.05-1.0)
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
