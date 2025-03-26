/**
 * UIManager.pde
 * 
 * Handles user interface elements and interactions.
 * Provides controls, feedback, and visualization of calibration process.
 * FIXED: Ensures proper coordinate system alignment for button interaction.
 */

class UIManager {
  PApplet parent;
  
  // UI state
  int selectedParameter = 0;
  boolean showStats = true;
  boolean showHelp = false;
  
  // UI colors
  color bgColor = color(0, 0, 0, 200);
  color highlightColor = color(255, 255, 0, 50);
  color textColor = color(255);
  color accentColor = color(0, 255, 0);
  
  // UI components
  Button[] modeButtons;
  Slider[] paramSliders;
  
  // UI metrics
  int sidePanelWidth = 250;
  int sidePanelMargin = 10;
  boolean draggingSlider = false;
  
  UIManager(PApplet parent) {
    this.parent = parent;
    
    // Create mode buttons
    createModeButtons();
  }
  
  void createModeButtons() {
    AppMode[] modes = AppMode.values();
    modeButtons = new Button[modes.length];
    
    for (int i = 0; i < modes.length; i++) {
      int x = 10 + i * 150;
      int y = 10;
      String label = formatModeLabel(modes[i].toString());
      modeButtons[i] = new Button(x, y, 140, 30, label);
    }
  }
  
  void createParameterSliders(GalvoParameters params) {
    String[] labels = params.getParamLabels();
    float[] values = params.toArray();
    float[] mins = params.getParamMin();
    float[] maxs = params.getParamMax();
    
    paramSliders = new Slider[labels.length];
    
    for (int i = 0; i < labels.length; i++) {
      int x = width - sidePanelWidth - sidePanelMargin;
      int y = 70 + i * 30;
      paramSliders[i] = new Slider(x, y, sidePanelWidth - 20, 15, 
                                   labels[i], values[i], mins[i], maxs[i]);
    }
  }
  
  void draw(AppMode currentMode) {
    // FIXED: Reset coordinate system and drawing modes to ensure consistency
    pushMatrix();
    resetMatrix();
    rectMode(CORNER);
    ellipseMode(CENTER);
    
    // Update button states
    for (int i = 0; i < modeButtons.length; i++) {
      modeButtons[i].selected = (i == currentMode.ordinal());
    }
    
    // Draw top bar with mode selection
    fill(bgColor);
    noStroke();
    rect(0, 0, width, 50);
    
    // Draw mode buttons
    for (Button button : modeButtons) {
      button.draw();
    }
    
    // Draw mode-specific UI
    switch(currentMode) {
      case MANUAL_CALIBRATION:
        drawManualCalibrationUI();
        break;
        
      case AUTO_CALIBRATION:
        drawAutoCalibrationUI();
        break;
        
      case CAMERA_SETUP:
        drawCameraSetupUI();
        break;
        
      case PARAMETER_EXPORT:
        drawParameterExportUI();
        break;
        
      case LIVE_TESTING:
        drawLiveTestingUI();
        break;
    }
    
    // Draw help if enabled
    if (showHelp) {
      drawHelp(currentMode);
    }
    
    // FIXED: Restore coordinate system
    popMatrix();
  }
  
  void drawManualCalibrationUI() {
    // Side panel for parameters
    fill(bgColor);
    noStroke();
    rect(width - sidePanelWidth, 60, sidePanelWidth, height - 70);
    
    // Draw parameter controls
    // We'll use sliders in a complete implementation
    // For now, show basic parameter display and controls
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Parameters", width - sidePanelWidth + 10, 80);
    
    // Get parameter info
    GalvoParameters params = ((GalvoCalibration)parent).params;
    String[] paramLabels = params.getParamLabels();
    float[] paramValues = params.toArray();
    
    // Create sliders if needed
    if (paramSliders == null) {
      createParameterSliders(params);
    }
    
    // Draw parameter sliders
    for (int i = 0; i < paramSliders.length; i++) {
      // Update slider value
      paramSliders[i].value = paramValues[i];
      
      // Highlight selected parameter
      if (i == selectedParameter) {
        fill(highlightColor);
        rect(width - sidePanelWidth + 5, 95 + i * 30, sidePanelWidth - 10, 25);
      }
      
      // Draw the slider
      paramSliders[i].draw();
    }
    
    // Draw performance metrics
    drawMetricsPanel();
    
    // Draw keyboard shortcuts
    fill(textColor);
    textSize(12);
    text("Tab: Select Parameter | Arrows: Adjust | P: Change Pattern | Space: Pause/Resume", 
         10, height - 10);
    text("H: Help | S: Save | L: Load | T: Test Laser", 
         10, height - 30);
  }
  
  void drawAutoCalibrationUI() {
    // Auto-calibration progress is drawn by the AutoCalibrator
    
    // Add some instructions
    if (!((GalvoCalibration)parent).calibrator.isActive()) {
      fill(bgColor);
      noStroke();
      rect(10, 60, 400, 80);
      
      fill(textColor);
      textAlign(LEFT);
      textSize(16);
      text("Automatic Calibration", 20, 80);
      
      textSize(12);
      text("Press 'A' to start the automatic calibration process.", 20, 105);
      text("Make sure the camera is calibrated first.", 20, 125);
    }
  }
  
  void drawCameraSetupUI() {
    // Most camera UI is drawn by the CameraCapture class
    
    // Add some instructions
    fill(bgColor);
    noStroke();
    rect(10, 60, 400, 80);
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Camera Setup", 20, 80);
    
    textSize(12);
    text("Press 'C' to start camera calibration.", 20, 105);
    text("Use +/- to adjust laser detection threshold.", 20, 125);
  }
  
  void drawParameterExportUI() {
    // Draw export panel
    fill(bgColor);
    noStroke();
    rect(10, 60, 400, 300);
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Export Parameters", 20, 80);
    
    // Get parameters
    GalvoParameters params = ((GalvoCalibration)parent).params;
    
    // Display export options
    textSize(12);
    text("Current parameters:", 20, 105);
    
    String[] paramLabels = params.getParamLabels();
    float[] paramValues = params.toArray();
    
    for (int i = 0; i < 6; i++) { // Show only the main physics parameters
      text(paramLabels[i] + ": " + nf(paramValues[i], 0, 3), 30, 130 + i * 20);
    }
    
    // Draw export buttons
    Button exportJavaButton = new Button(20, 250, 180, 30, "Export as Java");
    Button exportProcssingButton = new Button(20, 290, 180, 30, "Export as Processing");
    
    exportJavaButton.draw();
    exportProcssingButton.draw();
    
    // Show sample code
    fill(bgColor);
    noStroke();
    rect(420, 60, width - 430, 300);
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Code Preview", 430, 80);
    
    textSize(12);
    text("// Galvanometer Spring Physics Constants", 430, 105);
    text("final float SPRING_CONSTANT = " + nf(params.springConstant, 0, 3) + "f;", 430, 125);
    text("final float DAMPING_RATIO = " + nf(params.dampingRatio, 0, 3) + "f;", 430, 145);
    text("final float NATURAL_FREQUENCY = " + nf(params.naturalFrequency, 0, 3) + "f;", 430, 165);
    text("final float POINTS_PER_SECOND = " + nf(params.pointsPerSecond, 0, 0) + "f;", 430, 185);
    text("final float ACCELERATION_LIMIT = " + nf(params.accelerationLimit, 0, 3) + "f;", 430, 205);
    text("final float CORNER_SMOOTHING = " + nf(params.cornerSmoothing, 0, 3) + "f;", 430, 225);
  }
  
  void drawLiveTestingUI() {
    // Draw testing panel
    fill(bgColor);
    noStroke();
    rect(10, 60, 400, 100);
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Live Testing", 20, 80);
    
    textSize(12);
    text("Testing live performance with real hardware.", 20, 105);
    text("Press 'P' to change pattern.", 20, 125);
    text("Press 'Space' to pause/resume.", 20, 145);
  }
  
  void drawExportOptions() {
    // This is called by GalvoCalibration in PARAMETER_EXPORT mode
  }
  
  void drawMetricsPanel() {
    // Draw metrics panel
    fill(bgColor);
    noStroke();
    rect(10, height - 150, 400, 120);
    
    fill(textColor);
    textAlign(LEFT);
    textSize(16);
    text("Performance Metrics", 20, height - 130);
    
    // Get metrics
    GalvoParameters params = ((GalvoCalibration)parent).params;
    
    textSize(12);
    text("Average Position Error: " + nf(params.avgError, 0, 2) + " px", 20, height - 110);
    text("Maximum Position Error: " + nf(params.maxError, 0, 2) + " px", 20, height - 90);
    text("Overshoot: " + nf(params.overshootMetric * 100, 0, 2) + "%", 20, height - 70);
    text("Corner Quality: " + nf((1 - params.cornerMetric) * 100, 0, 2) + "%", 20, height - 50);
    
    // Score calculation
    float overallScore = (1 - params.avgError / 100) * 0.4 + 
                        (1 - params.maxError / 200) * 0.2 + 
                        (1 - params.overshootMetric) * 0.2 + 
                        (1 - params.cornerMetric) * 0.2;
    
    overallScore = constrain(overallScore, 0, 1) * 100;
    
    text("Overall Score: " + nf(overallScore, 0, 1) + "%", 20, height - 30);
  }
  
  void drawHelp(AppMode currentMode) {
    // Draw help overlay
    fill(0, 0, 0, 200);
    rect(0, 0, width, height);
    
    fill(255);
    textAlign(CENTER);
    textSize(24);
    text("Galvanometer Calibration Help", width/2, 40);
    
    textSize(16);
    text("Mode: " + formatModeLabel(currentMode.toString()), width/2, 70);
    
    textAlign(LEFT);
    textSize(14);
    
    // Common controls
    text("Common Controls:", 50, 110);
    textSize(12);
    text("TAB - Switch between application modes", 70, 135);
    text("H - Toggle this help screen", 70, 155);
    text("T - Test laser pattern", 70, 175);
    text("ESC - Exit application", 70, 195);
    
    // Mode-specific controls
    textSize(14);
    text("Mode-Specific Controls:", 50, 230);
    textSize(12);
    
    switch(currentMode) {
      case MANUAL_CALIBRATION:
        text("↑/↓ - Adjust selected parameter", 70, 255);
        text("←/→ - Make larger adjustments to parameter", 70, 275);
        text("P - Change test pattern", 70, 295);
        text("SPACE - Pause/resume simulation", 70, 315);
        text("S - Save configuration", 70, 335);
        text("L - Load configuration", 70, 355);
        break;
        
      case AUTO_CALIBRATION:
        text("A - Start/stop automatic calibration", 70, 255);
        text("C - Camera calibration must be done first", 70, 275);
        break;
        
      case CAMERA_SETUP:
        text("C - Start camera calibration", 70, 255);
        text("SPACE - Capture calibration point", 70, 275);
        text("+/- - Adjust laser threshold", 70, 295);
        break;
        
      case PARAMETER_EXPORT:
        text("Click a button to export parameters", 70, 255);
        break;
        
      case LIVE_TESTING:
        text("P - Change test pattern", 70, 255);
        text("SPACE - Pause/resume", 70, 275);
        break;
    }
    
    // Draw close button
    fill(255, 0, 0);
    rect(width - 40, 20, 20, 20);
    fill(255);
    textAlign(CENTER);
    text("X", width - 30, 35);
  }
  
  void showHardwareRequiredMessage() {
    fill(bgColor);
    rect(width/2 - 200, height/2 - 50, 400, 100);
    
    fill(textColor);
    textAlign(CENTER);
    textSize(16);
    text("Hardware Required", width/2, height/2 - 20);
    
    textSize(12);
    text("This feature requires both camera and laser to be connected.", width/2, height/2 + 10);
  }
  
  void showCameraRequiredMessage() {
    fill(bgColor);
    rect(width/2 - 200, height/2 - 50, 400, 100);
    
    fill(textColor);
    textAlign(CENTER);
    textSize(16);
    text("Camera Required", width/2, height/2 - 20);
    
    textSize(12);
    text("This feature requires a camera to be connected.", width/2, height/2 + 10);
  }
  
  void showLaserRequiredMessage() {
    fill(bgColor);
    rect(width/2 - 200, height/2 - 50, 400, 100);
    
    fill(textColor);
    textAlign(CENTER);
    textSize(16);
    text("Laser Required", width/2, height/2 - 20);
    
    textSize(12);
    text("This feature requires a laser to be connected.", width/2, height/2 + 10);
  }
  
  String formatModeLabel(String modeStr) {
    String result = "";
    for (int i = 0; i < modeStr.length(); i++) {
      char c = modeStr.charAt(i);
      if (i > 0 && Character.isUpperCase(c)) {
        result += " " + c;
      } else {
        result += c;
      }
    }
    return result;
  }
  
  void keyPressed() {
    GalvoCalibration app = (GalvoCalibration)parent;
    AppMode currentMode = app.currentMode;
    
    // Global key handlers
    if (key == 'h' || key == 'H') {
      showHelp = !showHelp;
      return;
    }
    
    // If help is showing, only respond to H and mouse clicks
    if (showHelp) return;
    
    // Mode-specific key handlers
    switch(currentMode) {
      case MANUAL_CALIBRATION:
        handleManualCalibrationKeys();
        break;
        
      case AUTO_CALIBRATION:
        handleAutoCalibrationKeys();
        break;
        
      case CAMERA_SETUP:
        // Camera class handles its own key events
        if (app.camera != null) {
          app.camera.keyPressed();
        }
        break;
        
      case PARAMETER_EXPORT:
        // No specific key handlers for export mode
        break;
        
      case LIVE_TESTING:
        handleLiveTestingKeys();
        break;
    }
  }
  
  void handleManualCalibrationKeys() {
    GalvoCalibration app = (GalvoCalibration)parent;
    GalvoParameters params = app.params;
    float[] values = params.toArray();
    float[] minValues = params.getParamMin();
    float[] maxValues = params.getParamMax();
    float[] stepSizes = params.getParamStep();
    
    if (key == TAB) {
      // Select next parameter
      selectedParameter = (selectedParameter + 1) % values.length;
    } else if (key == ' ') {
      // Toggle simulation
      app.isSimulationRunning = !app.isSimulationRunning;
    } else if (key == 's' || key == 'S') {
      // Save configuration
      app.dataManager.saveConfig();
    } else if (key == 'l' || key == 'L') {
      // Load configuration
      app.dataManager.loadConfig();
    } else if (key == 'p' || key == 'P') {
      // Change pattern
      app.currentPattern.nextPattern();
    } else if (keyCode == UP) {
      // Increase selected parameter
      values[selectedParameter] += stepSizes[selectedParameter];
      values[selectedParameter] = constrain(values[selectedParameter], 
                                  minValues[selectedParameter], 
                                  maxValues[selectedParameter]);
      params.setFromArray(values);
    } else if (keyCode == DOWN) {
      // Decrease selected parameter
      values[selectedParameter] -= stepSizes[selectedParameter];
      values[selectedParameter] = constrain(values[selectedParameter], 
                                  minValues[selectedParameter], 
                                  maxValues[selectedParameter]);
      params.setFromArray(values);
    } else if (keyCode == RIGHT) {
      // Large increase
      values[selectedParameter] += stepSizes[selectedParameter] * 5;
      values[selectedParameter] = constrain(values[selectedParameter], 
                                  minValues[selectedParameter], 
                                  maxValues[selectedParameter]);
      params.setFromArray(values);
    } else if (keyCode == LEFT) {
      // Large decrease
      values[selectedParameter] -= stepSizes[selectedParameter] * 5;
      values[selectedParameter] = constrain(values[selectedParameter], 
                                  minValues[selectedParameter], 
                                  maxValues[selectedParameter]);
      params.setFromArray(values);
    }
  }
  
  void handleAutoCalibrationKeys() {
    GalvoCalibration app = (GalvoCalibration)parent;
    
    if (key == 'a' || key == 'A') {
      // Toggle auto-calibration
      if (app.calibrator != null) {
        app.calibrator.toggleCalibration();
      }
    }
  }
  
  void handleLiveTestingKeys() {
    GalvoCalibration app = (GalvoCalibration)parent;
    
    if (key == 'p' || key == 'P') {
      // Change pattern
      app.currentPattern.nextPattern();
    } else if (key == ' ') {
      // Toggle testing
      app.isSimulationRunning = !app.isSimulationRunning;
    }
  }
  
  void mousePressed() {
    // FIXED: Ensure we're using screen coordinates
    int mx = mouseX;
    int my = mouseY;
    
    // Check if in help mode and clicked close button
    if (showHelp && mx > width - 40 && mx < width - 20 && 
                    my > 20 && my < 40) {
      showHelp = false;
      return;
    }
    
    // If help is showing, only respond to close button
    if (showHelp) return;
    
    // Check for button clicks
    for (int i = 0; i < modeButtons.length; i++) {
      if (modeButtons[i].contains(mx, my)) {
        // Change mode
        ((GalvoCalibration)parent).currentMode = AppMode.values()[i];
        return;
      }
    }
    
    // Check for slider interaction
    if (paramSliders != null) {
      for (int i = 0; i < paramSliders.length; i++) {
        if (paramSliders[i].contains(mx, my)) {
          selectedParameter = i;
          paramSliders[i].setValueFromMouse(mx);
          draggingSlider = true;
          updateParameterFromSlider(i);
          return;
        }
      }
    }
    
    // Camera object handles its own mouse events
    GalvoCalibration app = (GalvoCalibration)parent;
    if (app.camera != null && app.currentMode == AppMode.CAMERA_SETUP) {
      app.camera.mousePressed();
    }
  }
  
  void mouseDragged() {
    // If dragging a slider
    if (draggingSlider && paramSliders != null && selectedParameter < paramSliders.length) {
      paramSliders[selectedParameter].setValueFromMouse(mouseX);
      updateParameterFromSlider(selectedParameter);
    }
  }
  
  void mouseReleased() {
    draggingSlider = false;
  }
  
  void updateParameterFromSlider(int index) {
    if (paramSliders == null || index >= paramSliders.length) return;
    
    // Get the value from the slider
    float value = paramSliders[index].value;
    
    // Update the parameter
    GalvoParameters params = ((GalvoCalibration)parent).params;
    float[] values = params.toArray();
    values[index] = value;
    params.setFromArray(values);
  }
}

// Simple button class
class Button {
  int x, y, w, h;
  String label;
  boolean selected = false;
  
  Button(int x, int y, int w, int h, String label) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
  }
  
  void draw() {
    // Draw background
    noStroke();
    if (selected) {
      fill(0, 150, 255);
    } else if (contains(mouseX, mouseY)) {
      fill(100);
    } else {
      fill(50);
    }
    rect(x, y, w, h, 5);
    
    // Draw label
    fill(255);
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x + w/2, y + h/2);
  }
  
  boolean contains(int px, int py) {
    return px >= x && px <= x + w && py >= y && py <= y + h;
  }
}

// Simple slider class
class Slider {
  int x, y, w, h;
  String label;
  float value, minValue, maxValue;
  
  Slider(int x, int y, int w, int h, String label, float value, float minValue, float maxValue) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.value = value;
    this.minValue = minValue;
    this.maxValue = maxValue;
  }
  
  void draw() {
    // Save previous text alignment
    int prevAlignX = g.textAlign;
    int prevAlignY = g.textAlignY;
    
    // Draw label
    fill(255);
    textAlign(LEFT, CENTER);
    textSize(12);
    text(label, x, y - 5);
    
    // Draw value
    textAlign(RIGHT, CENTER);
    text(nf(value, 0, 2), x + w, y - 5);
    
    // Draw track
    stroke(100);
    strokeWeight(1);
    line(x, y + h/2, x + w, y + h/2);
    
    // Draw handle
    float handleX = map(value, minValue, maxValue, x, x + w);
    noStroke();
    fill(0, 150, 255);
    rect(handleX - 5, y, 10, h, 5);
    
    // Restore text alignment
    textAlign(prevAlignX, prevAlignY);
  }
  
  boolean contains(int px, int py) {
    // Check if point is near the slider handle
    float handleX = map(value, minValue, maxValue, x, x + w);
    return px >= handleX - 10 && px <= handleX + 10 && py >= y && py <= y + h;
  }
  
  void setValueFromMouse(int px) {
    // Map mouse x to value range
    value = map(constrain(px, x, x + w), x, x + w, minValue, maxValue);
  }
}
