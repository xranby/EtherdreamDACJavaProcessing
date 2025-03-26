/**
 * PhysicsSimulation.pde
 * 
 * Simulates galvanometer physics based on the spring-mass-damper model.
 * Applies physically accurate motion constraints to incoming points
 * and calculates performance metrics.
 */

class PhysicsSimulator {
  GalvoParameters params;
  
  // Point tracking
  ArrayList<PVector> targetPoints = new ArrayList<PVector>();
  ArrayList<PVector> actualPoints = new ArrayList<PVector>();
  PVector lastPoint;
  
  // History tracking for metrics calculation
  ArrayList<PVector> historyTargets = new ArrayList<PVector>();
  ArrayList<PVector> historyActuals = new ArrayList<PVector>();
  int historyLength = 200;
  
  // Performance metrics
  float maxError = 0;
  float avgError = 0;
  float cornerMetric = 0;
  float overshootMetric = 0;
  
  PhysicsSimulator(GalvoParameters params) {
    this.params = params;
    
    // Initialize with center position
    lastPoint = new PVector(width/2, height/2);
    
    // Initialize history
    for (int i = 0; i < historyLength; i++) {
      historyTargets.add(new PVector(width/2, height/2));
      historyActuals.add(new PVector(width/2, height/2));
    }
  }
  
  void update(ArrayList<PVector> newTargets) {
    this.targetPoints = newTargets;
    actualPoints.clear();
    
    // Process each target point through the physics simulation
    for (PVector target : targetPoints) {
      PVector actual = applyGalvoPhysics(target);
      actualPoints.add(actual);
      
      // Update history
      historyTargets.add(target.copy());
      historyActuals.add(actual.copy());
      
      // Trim history if needed
      if (historyTargets.size() > historyLength) {
        historyTargets.remove(0);
        historyActuals.remove(0);
      }
    }
  }
  
  void draw() {
    // Draw target track
    stroke(0, 255, 0, 100);
    strokeWeight(1);
    noFill();
    beginShape();
    for (PVector p : historyTargets) {
      vertex(p.x, p.y);
    }
    endShape();
    
    // Draw actual track
    stroke(255, 100, 100, 150);
    strokeWeight(2);
    noFill();
    beginShape();
    for (PVector p : historyActuals) {
      vertex(p.x, p.y);
    }
    endShape();
    
    // Draw current points if available
    if (targetPoints.size() > 0 && actualPoints.size() > 0) {
      PVector targetPoint = targetPoints.get(targetPoints.size() - 1);
      PVector actualPoint = actualPoints.get(actualPoints.size() - 1);
      
      // Draw target point
      fill(0, 255, 0);
      noStroke();
      ellipse(targetPoint.x, targetPoint.y, 10, 10);
      
      // Draw actual point
      fill(255, 100, 100);
      noStroke();
      ellipse(actualPoint.x, actualPoint.y, 8, 8);
      
      // Draw connection line
      stroke(255, 255, 0, 150);
      strokeWeight(1);
      line(targetPoint.x, targetPoint.y, actualPoint.x, actualPoint.y);
    }
  }
  
  // Apply galvo physics and return new position
  PVector applyGalvoPhysics(PVector targetPos) {
    // Time step (use a fixed time step for simulation consistency)
    float timeStep = 1.0 / frameRate;
    
    // Calculate distance to target
    float dx = targetPos.x - lastPoint.x;
    float dy = targetPos.y - lastPoint.y;
    
    // Apply spring physics
    float springFactor;
    
    if (params.dampingRatio < 1.0) {
      // Underdamped case (springy)
      float dampedFreq = params.angularFrequency * sqrt(1 - params.dampingRatio * params.dampingRatio);
      float decay = exp(-params.dampingRatio * params.angularFrequency * timeStep);
      
      springFactor = 1 - decay * (
        cos(dampedFreq * timeStep) +
        (params.dampingRatio * params.angularFrequency / dampedFreq) * sin(dampedFreq * timeStep)
      );
    } else {
      // Critically damped or overdamped
      float decay = exp(-params.angularFrequency * timeStep);
      springFactor = 1 - decay * (1 + params.angularFrequency * timeStep);
    }
    
    // Calculate new position based on spring factor
    PVector newPos = new PVector();
    newPos.x = lastPoint.x + dx * springFactor;
    newPos.y = lastPoint.y + dy * springFactor;
    
    // Apply acceleration limit
    float maxMove = params.accelerationLimit * timeStep * timeStep * width;
    float moveDist = dist(lastPoint.x, lastPoint.y, newPos.x, newPos.y);
    
    if (moveDist > maxMove) {
      float ratio = maxMove / moveDist;
      newPos.x = lastPoint.x + (newPos.x - lastPoint.x) * ratio;
      newPos.y = lastPoint.y + (newPos.y - lastPoint.y) * ratio;
    }
    
    // Check for corners if previous points available
    if (historyTargets.size() >= 3) {
      PVector prevTarget = historyTargets.get(historyTargets.size() - 1);
      PVector prevPrevTarget = historyTargets.get(historyTargets.size() - 2);
      
      // Calculate vectors
      PVector v1 = new PVector(prevTarget.x - prevPrevTarget.x, prevTarget.y - prevPrevTarget.y);
      PVector v2 = new PVector(targetPos.x - prevTarget.x, targetPos.y - prevTarget.y);
      
      // Normalize vectors
      float v1mag = v1.mag();
      float v2mag = v2.mag();
      
      if (v1mag > 0.001 && v2mag > 0.001) {
        v1.normalize();
        v2.normalize();
        
        // Calculate dot product
        float dot = v1.dot(v2);
        
        // If sharp corner detected, apply corner smoothing
        if (dot < 0.7) {  // Angle greater than ~45 degrees
          float cornerFactor = (1 - dot) * params.cornerSmoothing;
          float blendFactor = springFactor * (1 - cornerFactor);
          
          // Apply more aggressive corner smoothing
          newPos.x = lastPoint.x + dx * blendFactor;
          newPos.y = lastPoint.y + dy * blendFactor;
        }
      }
    }
    
    // Save this position for next calculation
    lastPoint = newPos.copy();
    
    return newPos;
  }
  
  // Process a list of points through physics model
  ArrayList<PVector> processPoints(ArrayList<PVector> points) {
    ArrayList<PVector> processed = new ArrayList<PVector>();
    
    for (PVector p : points) {
      processed.add(applyGalvoPhysics(p));
    }
    
    return processed;
  }
  
  // Calculate performance metrics
  void calculateMetrics() {
    // Calculate error metrics
    float totalError = 0;
    float newMaxError = 0;
    
    // Analyze last few points for current metrics
    int analysisPoints = min(20, historyActuals.size());
    
    for (int i = 0; i < analysisPoints; i++) {
      int index = historyActuals.size() - 1 - i;
      if (index >= 0 && index < historyActuals.size() && index < historyTargets.size()) {
        PVector actual = historyActuals.get(index);
        PVector target = historyTargets.get(index);
        
        float error = dist(actual.x, actual.y, target.x, target.y);
        totalError += error;
        
        if (error > newMaxError) {
          newMaxError = error;
        }
      }
    }
    
    avgError = totalError / analysisPoints;
    
    // Exponential moving average for max error
    maxError = maxError * 0.9 + newMaxError * 0.1;
    
    // Calculate overshoot metric
    float overshootSum = 0;
    int overshootCount = 0;
    
    // Look for pattern changes and measure overshoot
    for (int i = 10; i < historyTargets.size() - 5; i++) {
      PVector target1 = historyTargets.get(i-10);
      PVector target2 = historyTargets.get(i);
      
      // If a significant change in target occurred
      if (dist(target1.x, target1.y, target2.x, target2.y) > width * 0.05) {
        // Measure maximum deviation after the target change
        float maxDev = 0;
        for (int j = 0; j < 5; j++) {
          if (i+j < historyActuals.size() && i+j < historyTargets.size()) {
            PVector actualJ = historyActuals.get(i+j);
            PVector targetJ = historyTargets.get(i+j);
            float dev = dist(actualJ.x, actualJ.y, targetJ.x, targetJ.y);
            if (dev > maxDev) maxDev = dev;
          }
        }
        
        overshootSum += maxDev;
        overshootCount++;
      }
    }
    
    if (overshootCount > 0) {
      overshootMetric = overshootSum / overshootCount / width;
    }
    
    // Calculate corner metric
    // This is a measure of how well the system handles sharp corners
    float cornerSum = 0;
    int cornerCount = 0;
    
    for (int i = 10; i < historyTargets.size() - 10; i++) {
      PVector target1 = historyTargets.get(i-5);
      PVector target2 = historyTargets.get(i);
      PVector target3 = historyTargets.get(i+5);
      
      // Calculate vectors
      PVector v1 = new PVector(target2.x - target1.x, target2.y - target1.y);
      PVector v2 = new PVector(target3.x - target2.x, target3.y - target2.y);
      
      v1.normalize();
      v2.normalize();
      
      // Calculate dot product to detect corner
      float dot = v1.dot(v2);
      
      // If sharp corner detected
      if (dot < 0.7) {
        if (i < historyActuals.size()) {
          PVector actual = historyActuals.get(i);
          float cornerError = dist(actual.x, actual.y, target2.x, target2.y);
          cornerSum += cornerError;
          cornerCount++;
        }
      }
    }
    
    if (cornerCount > 0) {
      cornerMetric = cornerSum / cornerCount / width;
    }
    
    // Update parameters object with results
    params.avgError = avgError;
    params.maxError = maxError;
    params.overshootMetric = overshootMetric;
    params.cornerMetric = cornerMetric;
  }
  
  // Reset the simulation
  void reset() {
    lastPoint = new PVector(width/2, height/2);
    historyTargets.clear();
    historyActuals.clear();
    
    // Initialize history
    for (int i = 0; i < historyLength; i++) {
      historyTargets.add(new PVector(width/2, height/2));
      historyActuals.add(new PVector(width/2, height/2));
    }
  }
}
