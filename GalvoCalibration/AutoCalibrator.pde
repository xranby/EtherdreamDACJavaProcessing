/**
 * AutoCalibrator.pde
 * 
 * Performs automatic calibration of galvanometer parameters.
 * Uses optimization algorithms to find optimal parameters
 * based on feedback from camera.
 */
 
 // Calibration phases
  enum CalibrationPhase {
    PREPARATION,
    COARSE_SEARCH,
    FINE_TUNING,
    VERIFICATION,
    COMPLETED
  }

class AutoCalibrator {
  GalvoParameters params;
  GalvoParameters bestParams;
  PhysicsSimulator physics;
  CameraCapture camera;
  LaserController laser;
  
  // Calibration sequence state
  boolean isCalibrating = false;
  int currentStep = 0;
  int currentIteration = 0;
  int totalIterations = 0;
  
  // Calibration patterns sequence
  PatternType[] calibrationSequence = {
    PatternType.STEP_RESPONSE,
    PatternType.SQUARE,
    PatternType.CIRCLE,
    PatternType.STAR
  };
  
  // Current test pattern
  TestPattern testPattern;
  
  // Parameter optimization
  float[] paramRanges;
  float[] stepSizes;
  float[] bestScores;
  
  // Overall performance score
  float currentScore = 0;
  float bestScore = 0;
  
  // Optimization algorithm
  OptimizationAlgorithm optimizer;
  
  CalibrationPhase currentPhase = CalibrationPhase.PREPARATION;
  
  // Constants
  final int SAMPLES_PER_PATTERN = 300;
  final int MAX_ITERATIONS = 50;
  final int STABILITY_THRESHOLD = 5;
  
  AutoCalibrator(GalvoParameters params, PhysicsSimulator physics, CameraCapture camera, LaserController laser) {
    this.params = params;
    this.physics = physics;
    this.camera = camera;
    this.laser = laser;
    
    // Create a copy for best parameters
    bestParams = new GalvoParameters();
    bestParams.copyFrom(params);
    
    // Create test pattern
    testPattern = new TestPattern(params);
    testPattern.setPattern(PatternType.STEP_RESPONSE);
    
    // Setup parameter ranges
    setupParameterRanges();
    
    // Initialize optimization algorithm
    optimizer = new HillClimbingOptimizer(params.toArray(), paramRanges, stepSizes);
    
    // Initialize scores
    bestScores = new float[calibrationSequence.length];
    for (int i = 0; i < bestScores.length; i++) {
      bestScores[i] = 0;
    }
  }
  
  void setupParameterRanges() {
    // Define parameter ranges and step sizes for optimization
    // This determines the search space for each parameter
    float[] minValues = params.getParamMin();
    float[] maxValues = params.getParamMax();
    float[] defaultSteps = params.getParamStep();
    
    paramRanges = new float[6]; // Only optimize the first 6 parameters
    stepSizes = new float[6];
    
    for (int i = 0; i < 6; i++) {
      paramRanges[i] = maxValues[i] - minValues[i];
      stepSizes[i] = defaultSteps[i];
    }
  }
  
  void startCalibration() {
    if (!camera.isCalibrated()) {
      println("Camera must be calibrated before automatic galvo calibration!");
      return;
    }
    
    isCalibrating = true;
    currentStep = 0;
    currentIteration = 0;
    totalIterations = 0;
    currentPhase = CalibrationPhase.PREPARATION;
    
    // Reset the physics simulator
    physics.reset();
    
    // Set initial test pattern
    testPattern.setPattern(calibrationSequence[0]);
    
    // Save initial parameters as best so far
    bestParams.copyFrom(params);
    bestScore = 0;
    
    println("Starting automatic calibration...");
  }
  
  void update() {
    if (!isCalibrating) return;
    
    switch (currentPhase) {
      case PREPARATION:
        // Setup test environment
        prepareCalibration();
        break;
        
      case COARSE_SEARCH:
        // Broad parameter search
        performCoarseSearch();
        break;
        
      case FINE_TUNING:
        // Refine best parameters
        performFineTuning();
        break;
        
      case VERIFICATION:
        // Validate results
        verifyResults();
        break;
        
      case COMPLETED:
        // Calibration complete
        finalizeCalibration();
        break;
    }
  }
  
  void prepareCalibration() {
    println("Preparing calibration environment...");
    
    // Check if camera and laser are ready
    if (!camera.isCalibrated() || !laser.isReady()) {
      println("Camera or laser not ready!");
      isCalibrating = false;
      return;
    }
    
    // Reset optimization algorithm with current parameters
    optimizer = new HillClimbingOptimizer(params.toArray(), paramRanges, stepSizes);
    
    // Move to next phase
    currentPhase = CalibrationPhase.COARSE_SEARCH;
    println("Starting coarse parameter search...");
  }
  
  void performCoarseSearch() {
    // Use larger step sizes for coarse search
    for (int i = 0; i < stepSizes.length; i++) {
      stepSizes[i] = paramRanges[i] / 10.0;
    }
    
    // Get current test pattern
    testPattern.setPattern(calibrationSequence[currentStep]);
    
    // Run test pattern and evaluate
    runPatternAndEvaluate();
    
    // Check if we should move to next pattern
    currentIteration++;
    if (currentIteration >= SAMPLES_PER_PATTERN) {
      currentIteration = 0;
      currentStep++;
      
      // If we've gone through all patterns, move to fine tuning
      if (currentStep >= calibrationSequence.length) {
        currentStep = 0;
        currentPhase = CalibrationPhase.FINE_TUNING;
        
        // Use best parameters found so far
        params.copyFrom(bestParams);
        
        // Reset optimizer with smaller step sizes
        for (int i = 0; i < stepSizes.length; i++) {
          stepSizes[i] = paramRanges[i] / 40.0;
        }
        optimizer = new HillClimbingOptimizer(params.toArray(), paramRanges, stepSizes);
        
        println("Coarse search complete. Starting fine tuning...");
      }
    }
    
    // Check if we've done too many iterations
    totalIterations++;
    if (totalIterations > MAX_ITERATIONS) {
      currentPhase = CalibrationPhase.VERIFICATION;
      println("Maximum iterations reached. Starting verification...");
    }
  }
  
  void performFineTuning() {
    // Use smaller step sizes for fine tuning
    testPattern.setPattern(calibrationSequence[currentStep]);
    
    // Run test pattern and evaluate
    runPatternAndEvaluate();
    
    // Check if we should move to next pattern
    currentIteration++;
    if (currentIteration >= SAMPLES_PER_PATTERN * 2) { // More samples for fine tuning
      currentIteration = 0;
      currentStep++;
      
      // If we've gone through all patterns, move to verification
      if (currentStep >= calibrationSequence.length) {
        currentStep = 0;
        currentPhase = CalibrationPhase.VERIFICATION;
        
        // Use best parameters found so far
        params.copyFrom(bestParams);
        
        println("Fine tuning complete. Starting verification...");
      }
    }
    
    // Check if we've done too many iterations
    totalIterations++;
    if (totalIterations > MAX_ITERATIONS * 2) {
      currentPhase = CalibrationPhase.VERIFICATION;
      println("Maximum iterations reached. Starting verification...");
    }
  }
  
  void verifyResults() {
    // Run through all patterns with best parameters
    // and verify the results meet performance criteria
    testPattern.setPattern(calibrationSequence[currentStep]);
    
    // Use best parameters
    params.copyFrom(bestParams);
    
    // Run pattern and measure performance
    runPatternAndEvaluate();
    
    // Move to next pattern
    currentIteration++;
    if (currentIteration >= SAMPLES_PER_PATTERN) {
      currentIteration = 0;
      currentStep++;
      
      // If we've gone through all patterns, we're done
      if (currentStep >= calibrationSequence.length) {
        currentPhase = CalibrationPhase.COMPLETED;
        println("Verification complete. Calibration successful!");
      }
    }
  }
  
  void finalizeCalibration() {
    // Apply best parameters
    params.copyFrom(bestParams);
    physics.reset();
    
    // Return to manual mode
    isCalibrating = false;
    
    println("Calibration completed successfully!");
    println("Final parameters:");
    printParameters(params);
  }
  
  void runPatternAndEvaluate() {
    // Update test pattern
    testPattern.update(frameCount);
    
    // Get target points
    ArrayList<PVector> targetPoints = testPattern.getPoints();
    
    // Process with physics simulation
    ArrayList<PVector> galvoPoints = physics.processPoints(targetPoints);
    
    // Send to laser
    laser.sendPoints(galvoPoints);
    
    // Get camera feedback
    if (camera.isLaserDetected()) {
      // Set current projection center for camera reference
      if (targetPoints.size() > 0) {
        camera.setProjectionCenter(targetPoints.get(0));
      }
      
      // Calculate error between expected and actual position
      PVector error = camera.getActualExpectedError();
      
      // Calculate score (lower is better)
      float errorMagnitude = error.mag();
      float patternScore = calculatePatternScore(errorMagnitude);
      
      // Update current score
      currentScore = patternScore;
      
      // Update best score for this pattern
      if (patternScore > bestScores[currentStep] || bestScores[currentStep] == 0) {
        bestScores[currentStep] = patternScore;
      }
      
      // Calculate overall score as average of pattern scores
      float overallScore = 0;
      int validScores = 0;
      for (float score : bestScores) {
        if (score > 0) {
          overallScore += score;
          validScores++;
        }
      }
      if (validScores > 0) {
        overallScore /= validScores;
      }
      
      // Check if this is the best set of parameters so far
      if (overallScore > bestScore) {
        bestScore = overallScore;
        bestParams.copyFrom(params);
        println("New best parameters found! Score: " + bestScore);
      }
      
      // Let optimizer suggest new parameters
      float[] currentParams = params.toArray();
      float[] newParams = optimizer.suggestNextParameters(currentParams, patternScore);
      
      // Apply new parameters
      applyNewParameters(newParams);
    }
  }
  
  float calculatePatternScore(float errorMagnitude) {
    // Convert error to a score between 0 and 1 (higher is better)
    // We want to minimize error, so we invert the scale
    
    // Normalize error based on screen size
    float maxError = sqrt(width*width + height*height) * 0.5;
    float normalizedError = constrain(errorMagnitude / maxError, 0, 1);
    
    // Invert and scale to create score
    float score = 1.0 - normalizedError;
    
    // Apply exponential scaling to favor very small errors
    score = pow(score, 2);
    
    return score;
  }
  
  void applyNewParameters(float[] newParams) {
    // Only apply the first 6 parameters (physics parameters)
    for (int i = 0; i < 6 && i < newParams.length; i++) {
      float[] minValues = params.getParamMin();
      float[] maxValues = params.getParamMax();
      
      // Constrain to valid ranges
      newParams[i] = constrain(newParams[i], minValues[i], maxValues[i]);
    }
    
    // Update parameter object
    params.setFromArray(newParams);
    
    // Update derived parameters
    params.updateDerivedParams();
  }
  
  void draw() {
    // Draw calibration status
    int statusX = 10;
    int statusY = 60;
    int statusWidth = 300;
    int statusHeight = 400;
    
    // Draw background panel
    fill(0, 0, 0, 200);
    noStroke();
    rect(statusX, statusY, statusWidth, statusHeight);
    
    // Draw title
    fill(255);
    textSize(16);
    textAlign(LEFT);
    text("Automatic Calibration", statusX + 10, statusY + 25);
    
    // Draw progress bar
    float progress = 0;
    String phaseText = "";
    
    switch (currentPhase) {
      case PREPARATION:
        progress = 0.05;
        phaseText = "Preparation";
        break;
      case COARSE_SEARCH:
        progress = 0.1 + 0.3 * ((float)currentStep / calibrationSequence.length + 
                   (float)currentIteration / SAMPLES_PER_PATTERN / calibrationSequence.length);
        phaseText = "Coarse Search";
        break;
      case FINE_TUNING:
        progress = 0.4 + 0.4 * ((float)currentStep / calibrationSequence.length + 
                   (float)currentIteration / (SAMPLES_PER_PATTERN * 2) / calibrationSequence.length);
        phaseText = "Fine Tuning";
        break;
      case VERIFICATION:
        progress = 0.8 + 0.15 * ((float)currentStep / calibrationSequence.length + 
                    (float)currentIteration / SAMPLES_PER_PATTERN / calibrationSequence.length);
        phaseText = "Verification";
        break;
      case COMPLETED:
        progress = 1.0;
        phaseText = "Completed";
        break;
    }
    
    // Draw phase text
    fill(255);
    textSize(12);
    text("Phase: " + phaseText, statusX + 10, statusY + 50);
    
    // Draw progress bar
    fill(50);
    rect(statusX + 10, statusY + 60, statusWidth - 20, 20);
    fill(0, 255, 0);
    rect(statusX + 10, statusY + 60, (statusWidth - 20) * progress, 20);
    
    // Draw progress percentage
    fill(255);
    textAlign(CENTER);
    text(nf(progress * 100, 0, 1) + "%", statusX + statusWidth/2, statusY + 75);
    
    // Draw current pattern
    textAlign(LEFT);
    text("Current Pattern: " + testPattern.getCurrentPatternName(), statusX + 10, statusY + 100);
    
    // Draw best score
    text("Best Score: " + nf(bestScore, 0, 3), statusX + 10, statusY + 120);
    text("Current Score: " + nf(currentScore, 0, 3), statusX + 10, statusY + 140);
    
    // Draw current parameters
    textSize(12);
    text("Current Parameters:", statusX + 10, statusY + 170);
    
    String[] paramLabels = params.getParamLabels();
    for (int i = 0; i < 6; i++) {
      text(paramLabels[i] + ": " + nf(params.toArray()[i], 0, 3), 
           statusX + 10, statusY + 195 + i * 20);
    }
    
    // Draw best parameters
    textSize(12);
    text("Best Parameters:", statusX + 10, statusY + 320);
    
    float[] bestValues = bestParams.toArray();
    for (int i = 0; i < 6; i++) {
      text(paramLabels[i] + ": " + nf(bestValues[i], 0, 3), 
           statusX + 10, statusY + 345 + i * 20);
    }
    
    // Draw test pattern
    testPattern.draw();
  }
  
  void printParameters(GalvoParameters p) {
    println("Spring Constant: " + p.springConstant);
    println("Damping Ratio: " + p.dampingRatio);
    println("Natural Frequency: " + p.naturalFrequency);
    println("Points Per Second: " + p.pointsPerSecond);
    println("Acceleration Limit: " + p.accelerationLimit);
    println("Corner Smoothing: " + p.cornerSmoothing);
  }
  
  boolean isActive() {
    return isCalibrating;
  }
  
  void toggleCalibration() {
    if (isCalibrating) {
      isCalibrating = false;
      println("Calibration stopped manually");
    } else {
      startCalibration();
    }
  }
}

// Base class for optimization algorithms
abstract class OptimizationAlgorithm {
  float[] initialParams;
  float[] paramRanges;
  float[] stepSizes;
  
  OptimizationAlgorithm(float[] initialParams, float[] paramRanges, float[] stepSizes) {
    this.initialParams = initialParams.clone();
    this.paramRanges = paramRanges.clone();
    this.stepSizes = stepSizes.clone();
  }
  
  abstract float[] suggestNextParameters(float[] currentParams, float currentScore);
}

// Hill Climbing optimization (Simplest algorithm)
class HillClimbingOptimizer extends OptimizationAlgorithm {
  float bestScore = 0;
  float[] bestParams;
  int currentParamIndex = 0;
  boolean tryingHigher = true;
  int stabilityCounter = 0;
  
  HillClimbingOptimizer(float[] initialParams, float[] paramRanges, float[] stepSizes) {
    super(initialParams, paramRanges, stepSizes);
    bestParams = initialParams.clone();
  }
  
  float[] suggestNextParameters(float[] currentParams, float currentScore) {
    // Check if current parameters are better than best known
    if (currentScore > bestScore) {
      bestScore = currentScore;
      bestParams = currentParams.clone();
      stabilityCounter = 0;
    } else {
      stabilityCounter++;
    }
    
    // Create a copy of current best parameters
    float[] newParams = bestParams.clone();
    
    // If we've been stable for a while, decrease step sizes
    if (stabilityCounter > 10) {
      for (int i = 0; i < stepSizes.length; i++) {
        stepSizes[i] *= 0.5;
      }
      stabilityCounter = 0;
    }
    
    // Modify one parameter at a time
    if (tryingHigher) {
      // Try increasing the current parameter
      newParams[currentParamIndex] += stepSizes[currentParamIndex];
    } else {
      // Try decreasing the current parameter
      newParams[currentParamIndex] -= stepSizes[currentParamIndex] * 2; // Go back and try lower
    }
    
    // Move to next parameter configuration
    tryingHigher = !tryingHigher;
    if (tryingHigher) {
      currentParamIndex = (currentParamIndex + 1) % newParams.length;
    }
    
    return newParams;
  }
}
