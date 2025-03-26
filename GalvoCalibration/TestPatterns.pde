/**
 * TestPatterns.pde
 * 
 * Provides different test patterns to evaluate galvanometer performance.
 * Each pattern exercises different aspects of galvo capability.
 */

enum PatternType {
  STEP_RESPONSE,
  SQUARE, 
  CIRCLE,
  STAR,
  SPIRAL,
  GRID_SWEEP,
  RANDOM_JUMP,
  MOUSE_TRACKING,
  FREQUENCY_SWEEP
}

class TestPattern {
  PatternType type;
  GalvoParameters params;
  ArrayList<PVector> points;
  PVector currentPoint;
  
  // Pattern specific variables
  int lastJumpFrame = 0;
  float patternPhase = 0;
  int starPoints = 5;
  
  // Pattern names for UI
  String[] patternNames = {
    "Step Response",
    "Square",
    "Circle",
    "Star",
    "Spiral",
    "Grid Sweep",
    "Random Jump",
    "Mouse Tracking",
    "Frequency Sweep"
  };
  
  TestPattern(GalvoParameters params) {
    this.params = params;
    points = new ArrayList<PVector>();
    currentPoint = new PVector(width/2, height/2);
    type = PatternType.CIRCLE;
  }
  
  void setPattern(PatternType newType) {
    this.type = newType;
    
    // Reset pattern-specific variables
    lastJumpFrame = 0;
    patternPhase = 0;
    
    // Set specific parameters based on pattern type
    switch(newType) {
      case STAR:
        starPoints = 5 + int(params.patternComplexity * 5);
        break;
      case FREQUENCY_SWEEP:
        patternPhase = 0; // Start at lowest frequency
        break;
    }
  }
  
  void update(int frameCount) {
    points.clear();
    
    // Scale pattern to display size and apply pattern size
    float patternWidth = width * params.patternSize;
    float patternHeight = height * params.patternSize;
    float centerX = width / 2;
    float centerY = height / 2;
    
    // Time variables for animation
    float time = frameCount * 0.01 * params.patternSpeed;
    float slowTime = frameCount * 0.002 * params.patternSpeed;
    
    switch(type) {
      case STEP_RESPONSE:
        // Jump to a new position every few frames
        int jumpInterval = int(60 / params.patternSpeed);
        if (frameCount - lastJumpFrame > jumpInterval) {
          currentPoint.x = centerX + random(-1, 1) * patternWidth * 0.4;
          currentPoint.y = centerY + random(-1, 1) * patternHeight * 0.4;
          lastJumpFrame = frameCount;
        }
        points.add(currentPoint.copy());
        break;
        
      case SQUARE:
        float squareSize = patternWidth * 0.4;
        float squarePhase = (time % 4) / 4;
        
        if (squarePhase < 0.25) {
          // Top edge, moving right
          currentPoint.x = centerX - squareSize + squarePhase * 4 * 2 * squareSize;
          currentPoint.y = centerY - squareSize;
        } else if (squarePhase < 0.5) {
          // Right edge, moving down
          currentPoint.x = centerX + squareSize;
          currentPoint.y = centerY - squareSize + (squarePhase - 0.25) * 4 * 2 * squareSize;
        } else if (squarePhase < 0.75) {
          // Bottom edge, moving left
          currentPoint.x = centerX + squareSize - (squarePhase - 0.5) * 4 * 2 * squareSize;
          currentPoint.y = centerY + squareSize;
        } else {
          // Left edge, moving up
          currentPoint.x = centerX - squareSize;
          currentPoint.y = centerY + squareSize - (squarePhase - 0.75) * 4 * 2 * squareSize;
        }
        points.add(currentPoint.copy());
        break;
        
      case CIRCLE:
        float circleRadius = patternWidth * 0.4;
        currentPoint.x = centerX + cos(time) * circleRadius;
        currentPoint.y = centerY + sin(time) * circleRadius;
        points.add(currentPoint.copy());
        break;
        
      case STAR:
        // Calculate full star outline first
        ArrayList<PVector> starOutline = new ArrayList<PVector>();
        int numPoints = starPoints;
        float outerRadius = patternWidth * 0.4;
        float innerRadius = patternWidth * 0.2;
        
        for (int i = 0; i <= numPoints * 2; i++) {
          float angle = i * PI / numPoints + slowTime;
          float radius = (i % 2 == 0) ? outerRadius : innerRadius;
          
          PVector point = new PVector(
            centerX + cos(angle) * radius,
            centerY + sin(angle) * radius
          );
          starOutline.add(point);
        }
        
        // Find current point along star outline
        float starPhase = (time % 1);
        int starPointIndex = int(starPhase * starOutline.size());
        starPointIndex = constrain(starPointIndex, 0, starOutline.size() - 1);
        
        currentPoint = starOutline.get(starPointIndex).copy();
        points.add(currentPoint.copy());
        break;
        
      case SPIRAL:
        float spiralPhase = (time % 10) / 10;
        float spiralRadius = spiralPhase * patternWidth * 0.4;
        float spiralAngle = spiralPhase * 10 * TWO_PI;
        
        currentPoint.x = centerX + cos(spiralAngle) * spiralRadius;
        currentPoint.y = centerY + sin(spiralAngle) * spiralRadius;
        points.add(currentPoint.copy());
        break;
        
      case GRID_SWEEP:
        int gridSize = 5 + int(params.patternComplexity * 5);
        float gridTime = time % gridSize;
        int gridRow = int(gridTime);
        float gridFraction = gridTime - gridRow;
        
        // Alternating direction for each row
        float xDir = (gridRow % 2 == 0) ? gridFraction : (1 - gridFraction);
        
        float gridX = centerX - patternWidth * 0.4 + patternWidth * 0.8 * xDir;
        float gridY = centerY - patternHeight * 0.4 + patternHeight * 0.8 * gridRow / (gridSize - 1);
        
        currentPoint.x = gridX;
        currentPoint.y = gridY;
        points.add(currentPoint.copy());
        break;
        
      case RANDOM_JUMP:
        // Jump to a new position at random intervals
        int minInterval = 5;
        int maxInterval = 30 + int(30 / params.patternSpeed);
        if (frameCount - lastJumpFrame > minInterval && random(maxInterval) < 1) {
          currentPoint.x = centerX + random(-1, 1) * patternWidth * 0.4;
          currentPoint.y = centerY + random(-1, 1) * patternHeight * 0.4;
          lastJumpFrame = frameCount;
        }
        points.add(currentPoint.copy());
        break;
        
      case MOUSE_TRACKING:
        currentPoint.x = mouseX;
        currentPoint.y = mouseY;
        points.add(currentPoint.copy());
        break;
        
      case FREQUENCY_SWEEP:
        // Sweep through frequencies to find resonant peaks
        float minFreq = 0.5;
        float maxFreq = 30; // Hz, well above typical resonant peaks
        
        // Advance phase slowly through frequency range
        patternPhase += 0.0005 * params.patternSpeed;
        if (patternPhase > 1) patternPhase = 0;
        
        // Calculate current test frequency
        float testFreq = minFreq + patternPhase * (maxFreq - minFreq);
        
        // Create a circular path at the test frequency
        float testRadius = patternWidth * 0.3;
        float testAngle = frameCount * 0.001 * testFreq * TWO_PI;
        
        currentPoint.x = centerX + cos(testAngle) * testRadius;
        currentPoint.y = centerY + sin(testAngle) * testRadius;
        points.add(currentPoint.copy());
        break;
    }
  }
  
  void draw() {
    // Draw target path
    noFill();
    stroke(0, 255, 0, 150);
    strokeWeight(1);
    
    // Draw projection box
    float boxWidth = width * params.patternSize;
    float boxHeight = height * params.patternSize;
    rectMode(CENTER);
    rect(width/2, height/2, boxWidth, boxHeight);
    
    // Draw target point
    if (points.size() > 0) {
      PVector target = points.get(points.size() - 1);
      fill(0, 255, 0);
      noStroke();
      ellipse(target.x, target.y, 10, 10);
    }
    
    // Draw pattern type
    fill(255);
    textAlign(CENTER);
    text("Pattern: " + patternNames[type.ordinal()], width/2, 20);
    
    // Draw additional pattern-specific information
    switch(type) {
      case FREQUENCY_SWEEP:
        float currentFreq = 0.5 + patternPhase * 29.5;
        textAlign(LEFT);
        fill(255);
        text(String.format("Testing frequency: %.2f Hz", currentFreq), 20, height - 20);
        break;
    }
  }
  
  ArrayList<PVector> getPoints() {
    return points;
  }
  
  String getCurrentPatternName() {
    return patternNames[type.ordinal()];
  }
  
  void nextPattern() {
    int nextIndex = (type.ordinal() + 1) % PatternType.values().length;
    setPattern(PatternType.values()[nextIndex]);
  }
  
  void prevPattern() {
    int prevIndex = (type.ordinal() - 1 + PatternType.values().length) % PatternType.values().length;
    setPattern(PatternType.values()[prevIndex]);
  }
}
