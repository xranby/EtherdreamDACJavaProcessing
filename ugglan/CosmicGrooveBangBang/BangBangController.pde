/**
 * OptimizedBangBangController.pde
 * 
 * Enhanced version of BangBangController specifically optimized for CosmicGroove
 * Implements time-optimal control for galvanometer positioning
 * using intentional overshoot and braking for efficient line drawing.
 */

class BangBangController {
  // System parameters
  private float maxAcceleration;   // Maximum acceleration
  private float maxVelocity;       // Maximum velocity
  private int pointsPerSecond;     // Points per second
  
  // Current state
  private PVector position;        // Current position
  private PVector velocity;        // Current velocity
  private PVector acceleration;    // Current acceleration
  
  // Visualization parameters (for debug)
  private boolean showDebug = false;
  private ArrayList<PVector> debugPoints = new ArrayList<PVector>();
  
  /**
   * Constructor with system parameters
   */
  public BangBangController(float maxAccel, float maxVel, int pps) {
    this.maxAcceleration = maxAccel;
    this.maxVelocity = maxVel;
    this.pointsPerSecond = pps;
    
    // Initialize state
    this.position = new PVector(0, 0);
    this.velocity = new PVector(0, 0);
    this.acceleration = new PVector(0, 0);
  }
  
  /**
   * Generate points for an optimal line from start to end
   * Using acceleration, overshoot, and braking
   */
  public ArrayList<PVector> generateOptimalLine(PVector start, PVector end, int maxPoints) {
    ArrayList<PVector> points = new ArrayList<PVector>();
    
    // Calculate distance and direction
    PVector distance = PVector.sub(end, start);
    float totalDistance = distance.mag();
    PVector direction = distance.copy().normalize();
    
    // Check if the distance is too small for this algorithm
    if (totalDistance < 5.0) {
      // For very short distances, just use direct points
      points.add(start);
      points.add(end);
      return points;
    }
    
    // Calculate time parameters
    // For bang-bang control, assuming constant max acceleration:
    // Time to accelerate to max velocity: t1 = maxVelocity / maxAcceleration
    // Distance covered during acceleration: d1 = 0.5 * maxAcceleration * t1^2
    // Distance covered during constant velocity: d2 = totalDistance - 2 * d1
    // Total time: totalTime = 2 * t1 + d2 / maxVelocity
    
    float t1 = maxVelocity / maxAcceleration;
    float d1 = 0.5 * maxAcceleration * t1 * t1;
    
    // Time structure depends on whether we can reach max velocity
    boolean reachesMaxVelocity = totalDistance > 2 * d1;
    
    float totalTime, switchTime1, switchTime2;
    
    if (reachesMaxVelocity) {
      // Case 1: Enough distance to reach max velocity
      float d2 = totalDistance - 2 * d1;
      float t2 = d2 / maxVelocity;
      
      totalTime = 2 * t1 + t2;
      switchTime1 = t1;                 // Time to switch from accel to constant
      switchTime2 = t1 + t2;            // Time to switch from constant to decel
    } else {
      // Case 2: Not enough distance to reach max velocity
      // We accelerate halfway, then decelerate
      t1 = sqrt(totalDistance / maxAcceleration);
      
      totalTime = 2 * t1;
      switchTime1 = t1;                 // Time to switch from accel to decel
      switchTime2 = t1;                 // Same as switchTime1 in this case
    }
    
    // Calculate number of actual points (based on time and point rate)
    float pointInterval = 1.0 / pointsPerSecond;
    int numPoints = (int)(totalTime / pointInterval);
    
    // Limit to maximum specified
    numPoints = min(numPoints, maxPoints);
    
    // Generate points along optimal trajectory
    for (int i = 0; i <= numPoints; i++) {
      float t = (i / (float)numPoints) * totalTime;
      
      // Calculate position at time t
      PVector pos = calculatePositionAtTime(start, direction, t, 
                                           totalDistance, switchTime1, 
                                           switchTime2, totalTime,
                                           reachesMaxVelocity);
      
      points.add(pos);
    }
    
    return points;
  }
  
  /**
   * Calculate position at a specific time along the optimal trajectory
   */
  private PVector calculatePositionAtTime(PVector start, PVector direction, 
                                        float t, float totalDistance,
                                        float switchTime1, float switchTime2,
                                        float totalTime, boolean reachesMaxVelocity) {
    float displacement = 0;
    
    if (reachesMaxVelocity) {
      // Three-phase trajectory: accelerate, constant velocity, decelerate
      if (t < switchTime1) {
        // Acceleration phase: d = 0.5 * a * t^2
        displacement = 0.5 * maxAcceleration * t * t;
      } else if (t < switchTime2) {
        // Constant velocity phase: d = d1 + v * (t - t1)
        float d1 = 0.5 * maxAcceleration * switchTime1 * switchTime1;
        displacement = d1 + maxVelocity * (t - switchTime1);
      } else {
        // Deceleration phase: d = d1 + d2 + v * (t - t2) - 0.5 * a * (t - t2)^2
        float d1 = 0.5 * maxAcceleration * switchTime1 * switchTime1;
        float d2 = maxVelocity * (switchTime2 - switchTime1);
        
        float decelTime = t - switchTime2;
        displacement = d1 + d2 + maxVelocity * decelTime - 
                      0.5 * maxAcceleration * decelTime * decelTime;
      }
    } else {
      // Two-phase trajectory: accelerate, decelerate
      if (t < switchTime1) {
        // Acceleration phase: d = 0.5 * a * t^2
        displacement = 0.5 * maxAcceleration * t * t;
      } else {
        // Deceleration phase
        // At t = switchTime, v = a * switchTime
        // d = d1 + v_switch * (t - t_switch) - 0.5 * a * (t - t_switch)^2
        float d1 = 0.5 * maxAcceleration * switchTime1 * switchTime1;
        float vSwitch = maxAcceleration * switchTime1;
        
        float decelTime = t - switchTime1;
        displacement = d1 + vSwitch * decelTime - 
                      0.5 * maxAcceleration * decelTime * decelTime;
      }
    }
    
    // Ensure we don't exceed total distance due to numerical errors
    displacement = min(displacement, totalDistance);
    
    // Calculate position along the direction vector
    PVector pos = new PVector(
      start.x + direction.x * displacement,
      start.y + direction.y * displacement
    );
    
    return pos;
  }
  
  /**
   * Generate a curved path using multiple optimal line segments
   */
  public ArrayList<PVector> generateOptimalCurve(ArrayList<PVector> controlPoints, int pointsPerSegment) {
    ArrayList<PVector> result = new ArrayList<PVector>();
    
    // Need at least 2 points to form a line
    if (controlPoints.size() < 2) return result;
    
    // Generate optimal lines between each control point
    for (int i = 0; i < controlPoints.size() - 1; i++) {
      PVector start = controlPoints.get(i);
      PVector end = controlPoints.get(i + 1);
      
      // Skip points that are too close to each other
      if (PVector.dist(start, end) < 2.0) {
        if (i == 0 || result.size() == 0) {
          result.add(start);
        }
        continue;
      }
      
      ArrayList<PVector> segment = generateOptimalLine(start, end, pointsPerSegment);
      
      // Add all points except the last one (to avoid duplicates)
      // except for the final segment
      if (i < controlPoints.size() - 2) {
        for (int j = 0; j < segment.size() - 1; j++) {
          result.add(segment.get(j));
        }
      } else {
        // Add all points for the final segment
        result.addAll(segment);
      }
    }
    
    return result;
  }
  
  /**
   * Generate optimal path with reordering for more efficient traversal
   * Uses nearest-neighbor algorithm to optimize point order
   */
  public ArrayList<PVector> generateOptimalPath(ArrayList<PVector> points, int pointsPerSegment, boolean closePath) {
    // Need at least 2 points to form a path
    if (points.size() < 2) return points;
    
    // Initialize result
    ArrayList<PVector> orderedPoints = new ArrayList<PVector>();
    ArrayList<PVector> remainingPoints = new ArrayList<PVector>(points);
    
    // Start from the first point
    PVector currentPoint = remainingPoints.get(0);
    orderedPoints.add(currentPoint);
    remainingPoints.remove(0);
    
    // Find the nearest point repeatedly
    while (!remainingPoints.isEmpty()) {
      int nearestIndex = 0;
      float nearestDistance = Float.MAX_VALUE;
      
      // Find nearest point
      for (int i = 0; i < remainingPoints.size(); i++) {
        float distance = PVector.dist(currentPoint, remainingPoints.get(i));
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestIndex = i;
        }
      }
      
      // Add the nearest point to the ordered list
      currentPoint = remainingPoints.get(nearestIndex);
      orderedPoints.add(currentPoint);
      remainingPoints.remove(nearestIndex);
    }
    
    // Close the path if requested
    if (closePath && orderedPoints.size() > 2) {
      orderedPoints.add(orderedPoints.get(0));
    }
    
    // Generate the optimized path using the ordered points
    return generateOptimalCurve(orderedPoints, pointsPerSegment);
  }
  
  /**
   * Convert screen points to DAC points
   */
  public ArrayList<DACPoint> convertToDACPoints(ArrayList<PVector> points) {
    ArrayList<DACPoint> dacPoints = new ArrayList<DACPoint>();
    
    for (PVector p : points) {
      // Keep the coordinates in DAC format (-32767 to 32767)
      // We don't need to map from screen coordinates since our points are already in DAC format
      int x = constrain((int)p.x, -32767, 32767);
      int y = constrain((int)p.y, -32767, 32767);
      
      // Add to DAC points list with default white color
      // The color will be set separately based on the original point attributes
      dacPoints.add(new DACPoint(x, y, 65535, 65535, 65535));
    }
    
    return dacPoints;
  }
  
  /**
   * Get system parameters as a String (for debugging)
   */
  public String getParametersString() {
    return "BangBang Controller Parameters:" +
           "\nMax Acceleration: " + nf(maxAcceleration, 0, 2) +
           "\nMax Velocity: " + nf(maxVelocity, 0, 2) +
           "\nPoints per second: " + pointsPerSecond;
  }
  
  /**
   * Enable/disable debug visualization
   */
  public void setDebug(boolean debug) {
    this.showDebug = debug;
  }
  
  /**
   * Draw debug visualization (velocity vectors, acceleration, etc.)
   */
  public void drawDebug(PGraphics canvas) {
    if (!showDebug || debugPoints.size() < 2) return;
    
    // Draw the optimized path
    canvas.stroke(0, 255, 0);
    canvas.strokeWeight(1);
    
    for (int i = 0; i < debugPoints.size() - 1; i++) {
      PVector p1 = debugPoints.get(i);
      PVector p2 = debugPoints.get(i + 1);
      
      // Map from DAC coordinates to screen coordinates
      float x1 = map(p1.x, -32767, 32767, 0, canvas.width);
      float y1 = map(p1.y, 32767, -32767, 0, canvas.height);
      float x2 = map(p2.x, -32767, 32767, 0, canvas.width);
      float y2 = map(p2.y, 32767, -32767, 0, canvas.height);
      
      canvas.line(x1, y1, x2, y2);
    }
    
    // Draw points with velocity indicators
    for (int i = 0; i < debugPoints.size(); i += 10) {
      PVector p = debugPoints.get(i);
      
      // Map from DAC coordinates to screen coordinates
      float x = map(p.x, -32767, 32767, 0, canvas.width);
      float y = map(p.y, 32767, -32767, 0, canvas.height);
      
      // Draw point
      canvas.fill(255, 0, 0);
      canvas.noStroke();
      canvas.ellipse(x, y, 4, 4);
    }
  }
  
  /**
   * Save debug points for visualization
   */
  public void setDebugPoints(ArrayList<PVector> points) {
    this.debugPoints = new ArrayList<PVector>(points);
  }
}
