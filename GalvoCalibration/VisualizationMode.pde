/**
 * VisualizationMode.pde
 * 
 * Visualizes the raw and physics-processed points from CosmicGroove
 * to demonstrate how galvanometer physics affects laser output.
 * Updated to use the DACPoint accessors for coordinate extraction.
 */

class VisualizationMode {
  // Reference to parent sketch
  PApplet parent;
  
  // Reference to plugin manager and physics simulator
  PluginManager pluginManager;
  PhysicsSimulator physics;
  
  // Visualization state
  boolean enabled = false;
  boolean showHelp = true;
  boolean showDifferences = true;
  
  // Points for visualization
  ArrayList<PVector> rawPoints = new ArrayList<PVector>();
  ArrayList<PVector> processedPoints = new ArrayList<PVector>();
  ArrayList<PVector> differenceVectors = new ArrayList<PVector>();
  
  // Visualization settings
  int maxHistoryPoints = 1000;
  int fadeOutStart = 600;  // Point at which to start fading older points
  float pointSize = 2.0;   // Size of points to draw
  float lineWeight = 1.5;  // Weight of connecting lines
  float differenceMagnification = 5.0; // Magnify difference vectors for visibility
  
  // UI elements
  int uiPanelX = 10;
  int uiPanelY = 60;
  int uiPanelWidth = 300;
  int uiPanelHeight = 170;
  
  // Physics parameter adjustment
  float springConstantStep = 0.05;
  float dampingRatioStep = 0.05;
  boolean adjustingPhysics = false;
  
  // Currently selected parameter for adjustment
  int selectedParam = 0;
  
  // Parameter labels and descriptions
  String[] paramLabels = {
    "Spring Constant",
    "Damping Ratio",
    "Natural Frequency",
    "Acceleration Limit"
  };
  
  VisualizationMode(PApplet parent, PluginManager pluginManager, PhysicsSimulator physics) {
    this.parent = parent;
    this.pluginManager = pluginManager;
    this.physics = physics;
  }
  
  /**
   * Toggle visualization on/off
   */
  void toggle() {
    enabled = !enabled;
    
    if (enabled) {
      // Clear points when enabling
      rawPoints.clear();
      processedPoints.clear();
      differenceVectors.clear();
      showHelp = false;
    }
  }
  
  /**
   * Main update method - capture plugin output and run physics
   */
  void update() {
    if (!enabled) return;
    
    // Get the active plugin
    LaserPlugin activePlugin = pluginManager.getActivePlugin();
    if (activePlugin == null) return;
    
    // Get the current points from the plugin (as DAC points)
    ArrayList<DACPoint> dacPoints = activePlugin.getPoints();
    if (dacPoints == null || dacPoints.isEmpty()) return;
    
    // Convert DAC points to PVectors using the accessor methods
    ArrayList<PVector> currentRawPoints = convertDACtoScreen(dacPoints);
    
    // Apply physics simulation
    ArrayList<PVector> currentProcessedPoints = physics.processPoints(currentRawPoints);
    
    // Store in history (limited to max points)
    for (int i = 0; i < currentRawPoints.size(); i++) {
      rawPoints.add(currentRawPoints.get(i));
      
      // Keep corresponding processed point
      if (i < currentProcessedPoints.size()) {
        PVector raw = currentRawPoints.get(i);
        PVector processed = currentProcessedPoints.get(i);
        processedPoints.add(processed);
        
        // Calculate difference vector
        PVector diff = PVector.sub(processed, raw);
        // Magnify difference for visibility
        diff.mult(differenceMagnification);
        differenceVectors.add(diff);
      }
    }
    
    // Trim history if needed
    while (rawPoints.size() > maxHistoryPoints) {
      rawPoints.remove(0);
    }
    while (processedPoints.size() > maxHistoryPoints) {
      processedPoints.remove(0);
    }
    while (differenceVectors.size() > maxHistoryPoints) {
      differenceVectors.remove(0);
    }
  }
  
  /**
   * Draw the visualization
   */
  void draw() {
    if (!enabled) return;
    
    // Save current coordinate system
    pushMatrix();
    resetMatrix();
    
    // Clear background
    background(0);
    
    // Draw raw points in green
    drawPointSet(rawPoints, color(0, 255, 0, 180), color(0, 180, 0, 100));
    
    // Draw processed points in red
    drawPointSet(processedPoints, color(255, 0, 0, 180), color(180, 0, 0, 100));
    
    // Draw difference vectors
    if (showDifferences) {
      drawDifferenceVectors();
    }
    
    // Draw UI panel
    drawUI();
    
    // Draw help overlay if needed
    if (showHelp) {
      drawHelpOverlay();
    }
    
    // Restore coordinate system
    popMatrix();
  }
  
  /**
   * Draw a set of points with connections
   */
  void drawPointSet(ArrayList<PVector> points, color pointColor, color lineColor) {
    if (points.size() < 2) return;
    
    // Draw connecting lines
    stroke(lineColor);
    strokeWeight(lineWeight);
    noFill();
    beginShape();
    for (int i = 0; i < points.size(); i++) {
      PVector p = points.get(i);
      
      // Calculate fade factor based on age
      float fade = 1.0;
      if (i < fadeOutStart) {
        fade = map(i, 0, fadeOutStart, 0.1, 1.0);
      }
      
      // Set alpha based on fade
      stroke(red(lineColor), green(lineColor), blue(lineColor), alpha(lineColor) * fade);
      
      // Add vertex
      vertex(p.x, p.y);
    }
    endShape();
    
    // Draw points
    noStroke();
    fill(pointColor);
    for (int i = 0; i < points.size(); i++) {
      PVector p = points.get(i);
      
      // Calculate fade factor based on age
      float fade = 1.0;
      if (i < fadeOutStart) {
        fade = map(i, 0, fadeOutStart, 0.1, 1.0);
      }
      
      // Set alpha based on fade
      fill(red(pointColor), green(pointColor), blue(pointColor), alpha(pointColor) * fade);
      
      // Draw point
      ellipse(p.x, p.y, pointSize, pointSize);
    }
  }
  
  /**
   * Draw difference vectors showing how points move due to physics
   */
  void drawDifferenceVectors() {
    for (int i = 0; i < rawPoints.size() && i < differenceVectors.size(); i++) {
      // Only draw every few vectors to avoid clutter
      if (i % 10 != 0) continue;
      
      PVector raw = rawPoints.get(i);
      PVector diff = differenceVectors.get(i);
      
      // Calculate fade factor based on age
      float fade = 1.0;
      if (i < fadeOutStart) {
        fade = map(i, 0, fadeOutStart, 0.1, 1.0);
      }
      
      // Draw vector from raw to processed point
      stroke(255, 255, 0, 150 * fade);
      strokeWeight(0.5);
      line(raw.x, raw.y, raw.x + diff.x, raw.y + diff.y);
      
      // Draw arrow at end
      fill(255, 255, 0, 150 * fade);
      noStroke();
      pushMatrix();
      translate(raw.x + diff.x, raw.y + diff.y);
      float angle = atan2(diff.y, diff.x);
      rotate(angle);
      triangle(0, 0, -5, -2, -5, 2);
      popMatrix();
    }
  }
  
  /**
   * Draw UI panel with controls and physics parameters
   */
  void drawUI() {
    // Draw background panel
    fill(0, 0, 0, 220);
    noStroke();
    rect(uiPanelX, uiPanelY, uiPanelWidth, uiPanelHeight);
    
    // Draw title
    fill(255);
    textAlign(LEFT);
    textSize(16);
    text("Physics Visualization", uiPanelX + 10, uiPanelY + 25);
    
    // Draw parameter info
    textSize(12);
    textAlign(LEFT);
    
    // Identify current parameters from physics
    float springConstant = physics.params.springConstant;
    float dampingRatio = physics.params.dampingRatio;
    float naturalFrequency = physics.params.naturalFrequency;
    float accelerationLimit = physics.params.accelerationLimit;
    
    // Display values
    float y = uiPanelY + 50;
    float lineHeight = 22;
    
    for (int i = 0; i < paramLabels.length; i++) {
      // Highlight selected parameter
      if (i == selectedParam && adjustingPhysics) {
        fill(255, 255, 0, 60);
        rect(uiPanelX + 5, y - 15, uiPanelWidth - 10, 20);
      }
      
      fill(255);
      text(paramLabels[i] + ":", uiPanelX + 10, y);
      
      // Parameter value
      switch (i) {
        case 0: text(nf(springConstant, 0, 3), uiPanelX + 180, y); break;
        case 1: text(nf(dampingRatio, 0, 3), uiPanelX + 180, y); break;
        case 2: text(nf(naturalFrequency, 0, 1) + " Hz", uiPanelX + 180, y); break;
        case 3: text(nf(accelerationLimit, 0, 3), uiPanelX + 180, y); break;
      }
      
      y += lineHeight;
    }
    
    // Draw help text
    textSize(11);
    textAlign(LEFT);
    text("H: Toggle Help  |  D: Toggle Differences", uiPanelX + 10, uiPanelY + uiPanelHeight - 30);
    text("A: Adjust Physics  |  Tab: Switch Parameter", uiPanelX + 10, uiPanelY + uiPanelHeight - 15);
    
    // Point counts
    textAlign(RIGHT);
    text("Points: " + rawPoints.size() + " / " + maxHistoryPoints, 
         uiPanelX + uiPanelWidth - 10, uiPanelY + 50);
  }
  
  /**
   * Draw help overlay with instructions
   */
  void drawHelpOverlay() {
    // Semi-transparent overlay
    fill(0, 0, 0, 200);
    noStroke();
    rect(0, 0, width, height);
    
    // Title
    fill(255);
    textSize(24);
    textAlign(CENTER);
    text("Physics Visualization Mode", width/2, 50);
    
    // Draw legend
    drawLegend(width/2 - 200, 90);
    
    // Instructions
    textSize(16);
    textAlign(CENTER);
    text("Controls", width/2, 180);
    
    textSize(14);
    textAlign(LEFT);
    int x = width/2 - 150;
    int y = 210;
    int lineSpace = 25;
    
    text("V: Toggle Visualization Mode", x, y);
    text("H: Toggle This Help Screen", x, y + lineSpace);
    text("D: Toggle Difference Vectors", x, y + lineSpace*2);
    text("A: Enter/Exit Parameter Adjustment Mode", x, y + lineSpace*3);
    text("Tab: Switch Selected Parameter", x, y + lineSpace*4);
    text("↑/↓: Adjust Selected Parameter", x, y + lineSpace*5);
    text("C: Clear Point History", x, y + lineSpace*6);
    
    // Explanation
    textSize(14);
    textAlign(CENTER);
    text("This visualization shows how galvanometer physics affects the laser output.", width/2, height - 100);
    text("Green points show the raw desired positions, red points show simulated galvo positions.", width/2, height - 80);
    text("Yellow arrows show the difference between desired and actual positions.", width/2, height - 60);
    
    // Close button
    fill(180, 0, 0);
    rect(width - 50, 30, 20, 20);
    fill(255);
    textAlign(CENTER, CENTER);
    text("X", width - 40, 40);
  }
  
  /**
   * Draw legend explaining the colors
   */
  void drawLegend(int x, int y) {
    int boxSize = 15;
    int textOffset = 25;
    int lineHeight = 30;
    
    textAlign(LEFT);
    textSize(14);
    
    // Raw points
    fill(0, 255, 0);
    rect(x, y, boxSize, boxSize);
    fill(255);
    text("Raw Points (Desired Position)", x + textOffset, y + boxSize);
    
    // Processed points
    fill(255, 0, 0);
    rect(x, y + lineHeight, boxSize, boxSize);
    fill(255);
    text("Processed Points (Simulated Galvo Position)", x + textOffset, y + lineHeight + boxSize);
    
    // Difference vectors
    fill(255, 255, 0);
    rect(x, y + lineHeight*2, boxSize, boxSize);
    fill(255);
    text("Difference Vectors (Position Error, Magnified 5x)", x + textOffset, y + lineHeight*2 + boxSize);
  }
  
  /**
   * Convert DAC points to screen coordinates using the accessor methods
   */
  ArrayList<PVector> convertDACtoScreen(ArrayList<DACPoint> dacPoints) {
    ArrayList<PVector> screenPoints = new ArrayList<PVector>();
    
    for (DACPoint dacPoint : dacPoints) {
      // Use the getX() and getY() accessor methods
      float x = map(dacPoint.getX(), -32767, 32767, 0, width);
      float y = map(dacPoint.getY(), 32767, -32767, 0, height);  // Y is inverted
      screenPoints.add(new PVector(x, y));
    }
    
    return screenPoints;
  }
  
  /**
   * Handle key press events
   */
  void keyPressed() {
    if (key == 'h' || key == 'H') {
      // Toggle help
      showHelp = !showHelp;
    } else if (key == 'd' || key == 'D') {
      // Toggle difference vectors
      showDifferences = !showDifferences;
    } else if (key == 'a' || key == 'A') {
      // Toggle parameter adjustment mode
      adjustingPhysics = !adjustingPhysics;
    } else if (key == 'c' || key == 'C') {
      // Clear point history
      rawPoints.clear();
      processedPoints.clear();
      differenceVectors.clear();
    } else if (key == TAB) {
      // Switch selected parameter
      selectedParam = (selectedParam + 1) % paramLabels.length;
    } else if (adjustingPhysics) {
      // Parameter adjustment
      if (keyCode == UP) {
        adjustParameterUp();
      } else if (keyCode == DOWN) {
        adjustParameterDown();
      }
    }
  }
  
  /**
   * Increase the currently selected parameter
   */
  void adjustParameterUp() {
    switch (selectedParam) {
      case 0: // Spring Constant
        physics.params.springConstant += springConstantStep;
        physics.params.updateDerivedParams();
        break;
      case 1: // Damping Ratio
        physics.params.dampingRatio += dampingRatioStep;
        physics.params.updateDerivedParams();
        break;
      case 2: // Natural Frequency
        physics.params.naturalFrequency += 1.0;
        physics.params.updateDerivedParams();
        break;
      case 3: // Acceleration Limit
        physics.params.accelerationLimit += 0.01;
        break;
    }
  }
  
  /**
   * Decrease the currently selected parameter
   */
  void adjustParameterDown() {
    switch (selectedParam) {
      case 0: // Spring Constant
        physics.params.springConstant = max(0.1, physics.params.springConstant - springConstantStep);
        physics.params.updateDerivedParams();
        break;
      case 1: // Damping Ratio
        physics.params.dampingRatio = max(0.1, physics.params.dampingRatio - dampingRatioStep);
        physics.params.updateDerivedParams();
        break;
      case 2: // Natural Frequency
        physics.params.naturalFrequency = max(1.0, physics.params.naturalFrequency - 1.0);
        physics.params.updateDerivedParams();
        break;
      case 3: // Acceleration Limit
        physics.params.accelerationLimit = max(0.01, physics.params.accelerationLimit - 0.01);
        break;
    }
  }
  
  /**
   * Detect mouse clicks
   */
  void mousePressed() {
    // Check if help screen close button was clicked
    if (showHelp && mouseX > width - 50 && mouseX < width - 30 && 
        mouseY > 30 && mouseY < 50) {
      showHelp = false;
    }
  }
}
