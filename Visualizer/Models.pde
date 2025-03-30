/**
 * Models.pde
 * 
 * Contains data structures and model classes for the laser visualizer.
 */

// Enum for render priorities
enum RenderPriority {
  CRITICAL, HIGH, MEDIUM, LOW, VERY_LOW
}

/**
 * Rectangle class for layout management
 */
class Rectangle {
  int x, y, width, height;
  
  Rectangle(int x, int y, int width, int height) {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }
}

/**
 * GalvoParameters - defines the physical parameters of a galvanometer scanner
 */
class GalvoParameters {
  // Physical parameters
  float springConstant = 0.8;      // Spring constant (higher = stiffer response)
  float dampingRatio = 0.7;        // Damping ratio (higher = less oscillation)
  float naturalFrequency = 100.0;  // Natural frequency in Hz
  float accelerationLimit = 0.5;   // Limit to acceleration (0.05-1.0)
  float pointsPerSecond = 30000;   // Points per second rate
  
  /**
   * Reset to optimized defaults
   */
  void resetToOptimizedDefaults() {
    springConstant = 0.8;
    dampingRatio = 0.7;
    naturalFrequency = 100.0;
    accelerationLimit = 0.5;
    pointsPerSecond = 30000;
  }
}

/**
 * DACPoint - represents a single point to send to the DAC
 */
class DACPoint {
  int x, y;        // Coordinates (-32767 to 32767)
  int r, g, b;     // Color (0 to 65535)
  
  DACPoint(int x, int y, int r, int g, int b) {
    this.x = x;
    this.y = y;
    this.r = r;
    this.g = g;
    this.b = b;
  }
}

/**
 * LaserCallback - interface for sending points to the laser
 */
interface LaserCallback {
  void sendPoints(ArrayList<DACPoint> points);
  boolean isLaserConnected();
  int getMaxPoints();
  int getPointRate();
  int getBufferFillPercentage();
  int getAvailablePointCapacity();
  int getActualPointRate();
  long getLastFrameRenderTime();
}

/**
 * EnhancedBangBangController - processes points for optimal rendering
 */
class EnhancedBangBangController {
  private GalvoParameters params;
  
  public EnhancedBangBangController(GalvoParameters params) {
    this.params = params;
  }
  
  // This would do the actual point processing in a real implementation
}

/**
 * SimulatedDAC - Physics simulation of a laser DAC
 */
class SimulatedDAC {
  // Galvanometer state
  private PVector position;          // Current position
  private PVector velocity;          // Current velocity
  private PVector acceleration;      // Current acceleration
  private PVector targetPosition;    // Target position
  
  // Physics parameters
  private GalvoParameters params;    // Reference to galvo parameters
  private float springConstant;      // Spring stiffness
  private float dampingRatio;        // Damping ratio
  private float naturalFrequency;    // Natural frequency in rad/s
  
  // Buffer simulation
  private int bufferFillPercentage;  // Simulated buffer fill
  private ConcurrentLinkedQueue<DACPoint> pointBuffer; // Point buffer
  private ArrayList<PVector> physicsTracePoints;  // Trace of physical movement
  
  // Timing variables
  private float lastUpdateTime;      // Last update time in milliseconds
  private float physicsTimeStep;     // Physics time step in seconds
  
  /**
   * Constructor
   */
  public SimulatedDAC(GalvoParameters params) {
    this.params = params;
    updatePhysicsParams();
    
    // Initialize state
    position = new PVector(0, 0);
    velocity = new PVector(0, 0);
    acceleration = new PVector(0, 0);
    targetPosition = new PVector(0, 0);
    
    // Initialize buffer
    bufferFillPercentage = 0;
    pointBuffer = new ConcurrentLinkedQueue<DACPoint>();
    physicsTracePoints = new ArrayList<PVector>();
    
    // Initialize timing
    lastUpdateTime = millis();
    physicsTimeStep = 1.0f / 1000.0f;  // 1ms physics step
  }
  
  /**
   * Update physics parameters from galvo parameters
   */
  private void updatePhysicsParams() {
    springConstant = params.springConstant;
    dampingRatio = params.dampingRatio;
    naturalFrequency = params.naturalFrequency * TWO_PI;  // Convert Hz to rad/s
  }
  
  /**
   * Reset the DAC state
   */
  public void reset() {
    position = new PVector(0, 0);
    velocity = new PVector(0, 0);
    acceleration = new PVector(0, 0);
    targetPosition = new PVector(0, 0);
    bufferFillPercentage = 0;
    pointBuffer.clear();
    physicsTracePoints.clear();
    lastUpdateTime = millis();
  }
  
  /**
   * Send points to the simulated DAC
   */
  public void sendPoints(ArrayList<DACPoint> points) {
    // Add points to buffer
    pointBuffer.addAll(points);
    
    // Update buffer fill percentage
    bufferFillPercentage = constrain(pointBuffer.size() / 10, 0, 100);
    
    // Update physics simulation
    updatePhysics();
  }
  
  /**
   * Update physics simulation
   */
  private void updatePhysics() {
    // Calculate time delta
    float currentTime = millis();
    float deltaTime = (currentTime - lastUpdateTime) / 1000.0f;  // Convert to seconds
    lastUpdateTime = currentTime;
    
    // If paused or too large time step, skip
    if (deltaTime > 0.1f) {
      deltaTime = 0.1f;
    }
    
    // Update physics parameters in case they've changed
    updatePhysicsParams();
    
    // Process as many physics steps as needed
    float remainingTime = deltaTime;
    while (remainingTime > 0) {
      float dt = min(physicsTimeStep, remainingTime);
      remainingTime -= dt;
      
      // Update target position from buffer if available
      if (!pointBuffer.isEmpty()) {
        DACPoint nextPoint = pointBuffer.poll();
        targetPosition = new PVector(nextPoint.x, nextPoint.y);
      }
      
      // Calculate forces based on spring-mass-damper model
      // F = -k(x - x_target) - c*v
      // where c = 2*zeta*sqrt(k*m)
      
      // Spring force
      PVector springForce = PVector.sub(targetPosition, position);
      springForce.mult(springConstant);
      
      // Damping force
      PVector dampingForce = velocity.copy();
      dampingForce.mult(2 * dampingRatio * sqrt(springConstant));
      
      // Net force
      PVector netForce = springForce.copy();
      netForce.sub(dampingForce);
      
      // Apply acceleration limit
      float maxAccel = map(params.accelerationLimit, 0.05, 1.0, 5000, 20000);
      if (netForce.mag() > maxAccel) {
        netForce.normalize();
        netForce.mult(maxAccel);
      }
      
      // Update acceleration
      acceleration = netForce.copy();
      
      // Update velocity: v = v + a*dt
      PVector deltaV = acceleration.copy();
      deltaV.mult(dt);
      velocity.add(deltaV);
      
      // Apply velocity limit
      float freqFactor = map(params.naturalFrequency, 10, 500, 0.1, 1.0);
      float springFactor = map(params.springConstant, 0.1, 2.0, 0.5, 1.5);
      float maxVel = 15000 * freqFactor * springFactor;
      
      if (velocity.mag() > maxVel) {
        velocity.normalize();
        velocity.mult(maxVel);
      }
      
      // Update position: x = x + v*dt
      PVector deltaX = velocity.copy();
      deltaX.mult(dt);
      position.add(deltaX);
      
      // Add to physics trace
      physicsTracePoints.add(position.copy());
      
      // Limit the trace length
      while (physicsTracePoints.size() > 1000) {
        physicsTracePoints.remove(0);
      }
    }
  }
  
  /**
   * Get current position
   */
  public PVector getPosition() {
    return position.copy();
  }
  
  /**
   * Get current velocity
   */
  public PVector getVelocity() {
    return velocity.copy();
  }
  
  /**
   * Get current acceleration
   */
  public PVector getAcceleration() {
    return acceleration.copy();
  }
  
  /**
   * Get target position
   */
  public PVector getTargetPosition() {
    return targetPosition.copy();
  }
  
  /**
   * Get buffer fill percentage
   */
  public int getBufferFillPercentage() {
    return bufferFillPercentage;
  }
  
  /**
   * Get physics trace points
   */
  public ArrayList<PVector> getPhysicsTracePoints() {
    return new ArrayList<PVector>(physicsTracePoints);
  }
}
