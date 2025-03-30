/**
 * LaserGameVisualizer.pde
 * 
 * A visualization tool for testing laser games without actual hardware.
 * Shows original game points, enhanced points, simulates physical laser movement,
 * and provides realistic laser output visualization with color bloom effects.
 */

// Import necessary libraries
import java.util.concurrent.ConcurrentLinkedQueue;

// Visualization modes
static final int MODE_GAME_POINTS = 0;      // Show raw game points
static final int MODE_ENHANCED_POINTS = 1;  // Show points after BangBang processing
static final int MODE_PHYSICS_SIM = 2;      // Show physics simulation of actual galvo movement
static final int MODE_LASER_OUTPUT = 3;     // Show realistic laser output with bloom
static final int MODE_ALL = 4;              // Show all visualizations

// Current visualization state
int currentMode = MODE_ALL;
boolean showControlPanel = true;
boolean pauseSimulation = false;
float simulationSpeed = 1.0;
boolean showTraces = true;
int traceHistoryLength = 300;

// Laser output visualization settings
int bloomStrength = 20;      // Bloom strength (0-50)
int bloomSize = 6;           // Bloom size (1-20)
float laserBrightness = 1.0; // Laser brightness multiplier (0.1-2.0)
boolean atmosphericScatter = true; // Simulate atmospheric scattering
float beamWidth = 2.0;       // Laser beam width (1.0-5.0)
PGraphics laserOutputBuffer; // Off-screen buffer for laser rendering
PShader bloomShader;         // Shader for bloom effect
int laserOutputQuality = 1;  // Quality level (0=fast, 1=medium, 2=high)

// Simulated DAC
SimulatedDAC simulatedDAC;

// Plugin system and game reference
PluginManager pluginManager;
GalvoParameters galvoParams;
EnhancedBangBangController controller;
LaserVisualizerCallback visualizerCallback;

// Visualization areas
Rectangle gamePointsArea;
Rectangle enhancedPointsArea;
Rectangle physicsSimArea;
Rectangle laserOutputArea;
Rectangle controlPanelArea;

// Debug info
boolean showPerformanceStats = true;
int frameRate = 0;
int pointCount = 0;
int enhancedPointCount = 0;

// History for traces
ArrayList<ArrayList<PVector>> physicsTraceHistory;
ArrayList<ArrayList<PVector>> gameTraceHistory;
ArrayList<ArrayList<PVector>> enhancedTraceHistory;

// Color palettes
color[] gamePointColors;
color[] enhancedPointColors;
color[] physicsSimColors;

/**
 * Setup function
 */
void setup() {
  size(1200, 800, P2D);  // Use P2D renderer for shader support
  background(0);
  
  // Initialize bloom shader if running in compatible mode
  try {
    bloomShader = loadShader("bloomFrag.glsl", "bloomVert.glsl");
    println("Bloom shader loaded successfully");
  } catch (Exception e) {
    println("Could not load bloom shader: " + e.getMessage());
    println("Will use fallback bloom effect");
    bloomShader = null;
  }
  
  // Create off-screen buffer for laser output
  laserOutputBuffer = createGraphics(width, height, P2D);
  
  // Initialize galvo parameters with optimized defaults
  galvoParams = new GalvoParameters();
  galvoParams.resetToOptimizedDefaults();
  
  // Create controller with the parameters
  controller = new EnhancedBangBangController(galvoParams);
  
  // Create the simulated DAC
  simulatedDAC = new SimulatedDAC(galvoParams);
  
  // Create visualizer callback
  visualizerCallback = new LaserVisualizerCallback(simulatedDAC);
  
  // Create plugin manager with visualizer callback
  pluginManager = new PluginManager(visualizerCallback);
  
  // Register your game plugin - example with Spelide
  pluginManager.registerPlugin(new SpelidePlugin());
  
  // Initialize visualization areas
  setupVisualizationAreas();
  
  // Initialize trace history
  physicsTraceHistory = new ArrayList<ArrayList<PVector>>();
  gameTraceHistory = new ArrayList<ArrayList<PVector>>();
  enhancedTraceHistory = new ArrayList<ArrayList<PVector>>();
  
  // Initialize color palettes
  setupColorPalettes();
}

/**
 * Main draw function
 */
void draw() {
  background(0);
  
  // Update frame rate display
  if (frameCount % 10 == 0) {
    frameRate = (int)frameRate;
  }
  
  // Update the plugin if not paused
  if (!pauseSimulation) {
    for (int i = 0; i < simulationSpeed; i++) {
      pluginManager.draw();
      // Add to trace history after each update
      updateTraceHistory();
    }
  }
  
  // Draw visualizations based on current mode
  if (currentMode == MODE_ALL || currentMode == MODE_GAME_POINTS) {
    drawGamePointsVisualization();
  }
  
  if (currentMode == MODE_ALL || currentMode == MODE_ENHANCED_POINTS) {
    drawEnhancedPointsVisualization();
  }
  
  if (currentMode == MODE_ALL || currentMode == MODE_PHYSICS_SIM) {
    drawPhysicsSimulation();
  }
  
  if (currentMode == MODE_ALL || currentMode == MODE_LASER_OUTPUT) {
    drawLaserOutputVisualization();
  }
  
  // Draw control panel if enabled
  if (showControlPanel) {
    drawControlPanel();
  }
  
  // Draw UI elements
  drawUI();
}

/**
 * Handle key press events
 */
void keyPressed() {
  // Visualization mode selection
  if (key == '1') {
    currentMode = MODE_GAME_POINTS;
    setupVisualizationAreas();
  } else if (key == '2') {
    currentMode = MODE_ENHANCED_POINTS;
    setupVisualizationAreas();
  } else if (key == '3') {
    currentMode = MODE_PHYSICS_SIM;
    setupVisualizationAreas();
  } else if (key == '4') {
    currentMode = MODE_LASER_OUTPUT;
    setupVisualizationAreas();
  } else if (key == '5') {
    currentMode = MODE_ALL;
    setupVisualizationAreas();
  }
  
  if (key == ' ') {
    pauseSimulation = !pauseSimulation;
  } else if (key == '+' || key == '=') {
    simulationSpeed = min(simulationSpeed + 0.1, 5.0);
  } else if (key == '-' || key == '_') {
    simulationSpeed = max(simulationSpeed - 0.1, 0.1);
  } else if (key == 'r' || key == 'R') {
    // Reset simulation
    simulatedDAC.reset();
    physicsTraceHistory.clear();
    gameTraceHistory.clear();
    enhancedTraceHistory.clear();
  }
  
  // Display controls
  if (key == 't' || key == 'T') {
    showTraces = !showTraces;
  } else if (key == 'h' || key == 'H') {
    // Cycle through history lengths
    if (keyCode == SHIFT) {
      // Show help dialog
      // TODO: Add help dialog
    } else {
      int[] historyLengths = {50, 100, 200, 300, 500, 1000};
      int currentIndex = 0;
      
      for (int i = 0; i < historyLengths.length; i++) {
        if (traceHistoryLength <= historyLengths[i]) {
          currentIndex = i;
          break;
        }
      }
      
      currentIndex = (currentIndex + 1) % historyLengths.length;
      traceHistoryLength = historyLengths[currentIndex];
    }
  } else if (key == 'p' || key == 'P') {
    showPerformanceStats = !showPerformanceStats;
  } else if (key == 'c' || key == 'C') {
    showControlPanel = !showControlPanel;
    setupVisualizationAreas();
  }
  
  // Laser output visualization controls
  if (key == 'a' || key == 'A') {
    atmosphericScatter = !atmosphericScatter;
  } else if (key == 'q' || key == 'Q') {
    // Cycle through quality levels
    laserOutputQuality = (laserOutputQuality + 1) % 3;
  } else if (key == 'b' || key == 'B') {
    // Bloom strength controls with arrow keys
    if (keyCode == UP) {
      bloomStrength = min(bloomStrength + 1, 50);
    } else if (keyCode == DOWN) {
      bloomStrength = max(bloomStrength - 1, 0);
    }
  } else if (key == 's' || key == 'S') {
    // Bloom size controls with arrow keys
    if (keyCode == UP) {
      bloomSize = min(bloomSize + 1, 20);
    } else if (keyCode == DOWN) {
      bloomSize = max(bloomSize - 1, 1);
    }
  } else if (key == 'l' || key == 'L') {
    // Brightness controls with arrow keys
    if (keyCode == UP) {
      laserBrightness = min(laserBrightness + 0.1, 2.0);
    } else if (keyCode == DOWN) {
      laserBrightness = max(laserBrightness - 0.1, 0.1);
    }
  } else if (key == 'w' || key == 'W') {
    // Beam width controls with arrow keys
    if (keyCode == UP) {
      beamWidth = min(beamWidth + 0.5, 10.0);
    } else if (keyCode == DOWN) {
      beamWidth = max(beamWidth - 0.5, 1.0);
    }
  }
  
  // Forward keys to plugin manager
  pluginManager.keyPressed();
}

/**
 * Handle key release events
 */
void keyReleased() {
  // Forward key release to plugin manager
  pluginManager.keyReleased();
}

/**
 * Handle mouse press events
 */
void mousePressed() {
  // Forward mouse press to plugin manager
  pluginManager.mousePressed();
}

/**
 * Handle mouse drag events
 */
void mouseDragged() {
  // Forward mouse drag to plugin manager
  pluginManager.mouseDragged();
}

/**
 * Handle mouse release events
 */
void mouseReleased() {
  // Forward mouse release to plugin manager
  pluginManager.mouseReleased();
}
