/**
 * Etherdream Laser Controller - 3D Spinning Cube
 * Creates a 3D cube with different patterns on each face
 * Optimized for stable buffer performance at 15000 points per second
 */

Etherdream laser;
float angleX = 0;
float angleY = 0;
float angleZ = 0;
int frameCounter = 0;

// Buffer management
boolean preloadBuffer = true;
int preloadFrameCount = 5;

// 3D cube parameters
float cubeSize = 0.7;
int pointsPerFace = 40;  // How many points to use for each face pattern

void setup() {
  size(640, 360, P3D);
  frameRate(30);  // Lower framerate for more stability
  
  // Initialize the Etherdream DAC
  // Make sure these values are set in the Etherdream library:
  // private float maxBufferUtilization = 0.85f;  // Increased from 0.65
  // private int maxPointRate = 15000;           // Reduced to 15000
  
  laser = new Etherdream(this);
  
  // Configure for improved stability - account for blanking points
  laser.configure(252, true);  // 240 pattern points + 12 blanking points
  
  println("3D Spinning Cube with Blanking - Initializing...");
  println("This version includes blanking (laser off) transitions for smoother galvo movement");
  
  // Pre-buffer approach - queue up several frames immediately
  if (preloadBuffer) {
    println("Pre-buffering frames...");
    for (int i = 0; i < preloadFrameCount; i++) {
      DACPoint[] points = generateCubePoints(i * 0.05f, i * 0.03f, i * 0.02f);
      laser.queueFrame(points);
    }
  }
}

void draw() {
  // Update the visualization in the Processing window
  background(0);
  
  // Draw a representation of what's being sent to the laser
  stroke(40);
  strokeWeight(1);
  noFill();
  
  // Draw a circle representing the laser boundary
  ellipse(width/2, height/2, 300, 300);
  
  // Draw the 3D cube preview
  pushMatrix();
  translate(width/2, height/2);
  scale(100);
  stroke(0, 255, 0);
  strokeWeight(0.02);
  drawCubePreview();
  popMatrix();
  
  // Update the rotation angles (different speeds for each axis)
  angleX += 0.005;
  angleY += 0.007;
  angleZ += 0.003;
  
  // Count frames for debugging
  frameCounter++;
  if (frameCounter % 60 == 0) {
    // Print stats every 60 frames
    println("Stats: " + laser.getStats());
  }
}

// Required callback method for the Etherdream library
DACPoint[] getDACPoints() {
  return generateCubePoints(angleX, angleY, angleZ);
}

// Generate points for a 3D cube with different patterns on each face
// Now with blanking jumps between faces for more stable galvo movement
DACPoint[] generateCubePoints(float rotX, float rotY, float rotZ) {
  // Include "blanking" points for transitions between faces
  // We need 6 faces with points + 5 transition blanking jumps (1 blank point at start, 1 at end of each face except last)
  int totalPoints = 6 * pointsPerFace + 12;  // 12 blanking points (2 per face transition)
  DACPoint[] points = new DACPoint[totalPoints];
  
  // Define the 8 vertices of a cube
  PVector[] vertices = new PVector[8];
  vertices[0] = new PVector(-cubeSize, -cubeSize, -cubeSize);  // Front bottom left
  vertices[1] = new PVector( cubeSize, -cubeSize, -cubeSize);  // Front bottom right
  vertices[2] = new PVector( cubeSize,  cubeSize, -cubeSize);  // Front top right
  vertices[3] = new PVector(-cubeSize,  cubeSize, -cubeSize);  // Front top left
  vertices[4] = new PVector(-cubeSize, -cubeSize,  cubeSize);  // Back bottom left
  vertices[5] = new PVector( cubeSize, -cubeSize,  cubeSize);  // Back bottom right
  vertices[6] = new PVector( cubeSize,  cubeSize,  cubeSize);  // Back top right
  vertices[7] = new PVector(-cubeSize,  cubeSize,  cubeSize);  // Back top left
  
  // Define the 6 faces of the cube (indices into vertices array)
  int[][] faces = {
    {0, 1, 2, 3},  // Front face
    {5, 4, 7, 6},  // Back face
    {4, 0, 3, 7},  // Left face
    {1, 5, 6, 2},  // Right face
    {3, 2, 6, 7},  // Top face
    {4, 5, 1, 0}   // Bottom face
  };
  
  // Colors for each face (R, G, B)
  int[][] faceColors = {
    {65535, 0, 0},       // Front - Red
    {0, 65535, 0},       // Back - Green
    {0, 0, 65535},       // Left - Blue
    {65535, 65535, 0},   // Right - Yellow
    {65535, 0, 65535},   // Top - Magenta
    {0, 65535, 65535}    // Bottom - Cyan
  };
  
  // Rotation matrices
  float sinX = sin(rotX);
  float cosX = cos(rotX);
  float sinY = sin(rotY);
  float cosY = cos(rotY);
  float sinZ = sin(rotZ);
  float cosZ = cos(rotZ);
  
  // Calculate points for each face with blanking transitions
  int pointIndex = 0;
  PVector lastPoint = null;  // To track the last point for transitions
  
  for (int face = 0; face < 6; face++) {
    // Get the starting point for this face pattern
    PVector firstPoint = createFacePattern(face, 0, faces[face], vertices);
    
    // If we're not on the first face, add a blanking jump from the last face
    if (face > 0 && lastPoint != null) {
      // Add a blank point at the last position (laser off)
      PVector blankStart = lastPoint;
      
      // Apply 3D rotations and projections to blank starting point
      PVector projectedBlankStart = projectPoint(blankStart, sinX, cosX, sinY, cosY, sinZ, cosZ);
      
      points[pointIndex++] = new DACPoint(
        (int)projectedBlankStart.x,
        (int)projectedBlankStart.y,
        0, 0, 0  // Laser off (black)
      );
      
      // Add a blank point at the new position (laser still off)
      PVector blankEnd = firstPoint;
      PVector projectedBlankEnd = projectPoint(blankEnd, sinX, cosX, sinY, cosY, sinZ, cosZ);
      
      points[pointIndex++] = new DACPoint(
        (int)projectedBlankEnd.x,
        (int)projectedBlankEnd.y,
        0, 0, 0  // Laser off (black)
      );
    }
    
    // Draw the actual face pattern
    for (int i = 0; i < pointsPerFace; i++) {
      // Choose a pattern for this face
      PVector point = createFacePattern(face, i, faces[face], vertices);
      lastPoint = point;  // Remember this point for blanking transitions
      
      // Apply 3D rotations and projection
      PVector projectedPoint = projectPoint(point, sinX, cosX, sinY, cosY, sinZ, cosZ);
      
      // Create the point with face color
      points[pointIndex++] = new DACPoint(
        (int)projectedPoint.x,
        (int)projectedPoint.y,
        faceColors[face][0], 
        faceColors[face][1], 
        faceColors[face][2]
      );
    }
  }
  
  return points;
}

// Helper to apply 3D projection consistently
PVector projectPoint(PVector point, float sinX, float cosX, float sinY, float cosY, float sinZ, float cosZ) {
  // Apply 3D rotations - rotateX
  float tempY = point.y;
  float tempZ = point.z;
  float newY = tempY * cosX - tempZ * sinX;
  float newZ = tempY * sinX + tempZ * cosX;
  
  // rotateY
  float tempX = point.x;
  tempZ = newZ;
  float newX = tempX * cosY + tempZ * sinY;
  newZ = -tempX * sinY + tempZ * cosY;
  
  // rotateZ
  tempX = newX;
  tempY = newY;
  newX = tempX * cosZ - tempY * sinZ;
  newY = tempX * sinZ + tempY * cosZ;
  
  // Project 3D to 2D with simple perspective division
  float z = newZ + 3;  // Offset to prevent division by zero
  float scale = 1.5 / z;  // Perspective factor
  float projX = newX * scale;
  float projY = newY * scale;
  
  // Scale to stay within laser bounds
  int dacX = (int)(projX * 18000);
  int dacY = (int)(projY * 18000);
  
  // Clamp values to safe limits
  dacX = constrain(dacX, -32000, 32000);
  dacY = constrain(dacY, -32000, 32000);
  
  // We return the integer values as floats in the PVector for consistent function signature
  return new PVector(dacX, dacY, 0); 
}

// Create a unique pattern for each face with smoothed transitions for galvo stability
PVector createFacePattern(int faceIndex, int pointIndex, int[] faceVertices, PVector[] vertices) {
  float progress = (float)pointIndex / pointsPerFace;
  
  // Get the four corners of this face
  PVector v0 = vertices[faceVertices[0]];
  PVector v1 = vertices[faceVertices[1]];
  PVector v2 = vertices[faceVertices[2]];
  PVector v3 = vertices[faceVertices[3]];
  
  // Calculate center of face for all patterns to use
  float centerX = (v0.x + v1.x + v2.x + v3.x) / 4;
  float centerY = (v0.y + v1.y + v2.y + v3.y) / 4;
  float centerZ = (v0.z + v1.z + v2.z + v3.z) / 4;
  
  // Different patterns for each face - optimized for galvo movement
  switch (faceIndex) {
    case 0:  // Front - Smoother spiral pattern (continuous motion)
      float angle = progress * TWO_PI * 2;
      // Use smoother radius transition with easing
      float radius = 0.7 * (1 - progress * progress);  // Quadratic easing
      return new PVector(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
        centerZ
      );
      
    case 1:  // Back - Smoother starburst pattern
      float angle = progress * TWO_PI;
      // Smoothed starburst - less abrupt transitions
      float frequency = 3; // Reduced from 5 for smoother motion
      float radius = 0.6 * (0.3 + 0.7 * abs(sin(angle * frequency)));
      return new PVector(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
        centerZ
      );
      
    case 2:  // Left - Smoother horizontal lines pattern
      // Instead of jumping between lines, create continuous zigzag
      float zigzagY = centerY + 0.6 * sin(progress * 5 * PI);
      float interpZ = lerp(v0.z, v3.z, progress);
      return new PVector(
        v0.x + 0.1 * sin(progress * TWO_PI), // Slight wobble for interest
        zigzagY,
        interpZ
      );
      
    case 3:  // Right - Smooth zigzag pattern
      // Create smooth zigzag instead of jumping between vertical lines
      float zigzagZ = centerZ + 0.6 * sin(progress * 5 * PI);
      float interpY = lerp(v1.y, v2.y, progress);
      return new PVector(
        v1.x - 0.1 * sin(progress * TWO_PI), // Slight wobble for interest
        interpY,
        zigzagZ
      );
      
    case 4:  // Top - Smoother diamond/flower pattern
      angle = progress * TWO_PI;
      // Smoother petal shape
      radius = 0.6 * (0.3 + 0.3 * cos(angle * 3));
      return new PVector(
        centerX + radius * cos(angle),
        centerY + 0.05 * sin(angle * 2), // Slight undulation
        centerZ + radius * sin(angle)
      );
      
    case 5:  // Bottom - Simple circular pattern (very stable for galvos)
      angle = progress * TWO_PI;
      // Perfect circle - very smooth for galvos
      float circleRadius = 0.5;
      return new PVector(
        centerX + circleRadius * cos(angle),
        centerY + 0.05 * sin(angle * 2), // Slight undulation
        centerZ + circleRadius * sin(angle)
      );
      
    default:
      // Default pattern - smooth outline that follows face perimeter
      // Uses continuous parametric equations rather than abrupt segments
      // This produces smoother motion for the galvos
      float theta = progress * TWO_PI;
      
      // Smooth rounded square approximation
      float power = 4; // Controls "squareness" - higher = more square corners
      float px = 0.8f * Math.signum(cos(theta)) * pow(abs(cos(theta)), 2/power);
      float py = 0.8f * Math.signum(sin(theta)) * pow(abs(sin(theta)), 2/power);
      
      return new PVector(
        centerX + px,
        centerY + py,
        centerZ
      );
  }
}

// Math.signum implementation for the pattern generation
float signum(float val) {
  return (val > 0) ? 1 : (val < 0) ? -1 : 0;
}

// Helper method to visualize the cube in the Processing window
void drawCubePreview() {
  pushMatrix();
  rotateX(angleX);
  rotateY(angleY);
  rotateZ(angleZ);
  
  // Define the cube vertices
  PVector[] vertices = new PVector[8];
  vertices[0] = new PVector(-cubeSize, -cubeSize, -cubeSize);  // Front bottom left
  vertices[1] = new PVector( cubeSize, -cubeSize, -cubeSize);  // Front bottom right
  vertices[2] = new PVector( cubeSize,  cubeSize, -cubeSize);  // Front top right
  vertices[3] = new PVector(-cubeSize,  cubeSize, -cubeSize);  // Front top left
  vertices[4] = new PVector(-cubeSize, -cubeSize,  cubeSize);  // Back bottom left
  vertices[5] = new PVector( cubeSize, -cubeSize,  cubeSize);  // Back bottom right
  vertices[6] = new PVector( cubeSize,  cubeSize,  cubeSize);  // Back top right
  vertices[7] = new PVector(-cubeSize,  cubeSize,  cubeSize);  // Back top left
  
  // Define the 6 faces of the cube
  int[][] faces = {
    {0, 1, 2, 3},  // Front face
    {5, 4, 7, 6},  // Back face
    {4, 0, 3, 7},  // Left face
    {1, 5, 6, 2},  // Right face
    {3, 2, 6, 7},  // Top face
    {4, 5, 1, 0}   // Bottom face
  };
  
  // Colors for faces
  color[] faceColors = {
    color(255, 0, 0),     // Front - Red
    color(0, 255, 0),     // Back - Green
    color(0, 0, 255),     // Left - Blue
    color(255, 255, 0),   // Right - Yellow
    color(255, 0, 255),   // Top - Magenta
    color(0, 255, 255)    // Bottom - Cyan
  };
  
  // Draw each face with its pattern
  for (int f = 0; f < 6; f++) {
    stroke(faceColors[f]);
    
    // Draw pattern for this face
    for (int i = 0; i < pointsPerFace; i++) {
      PVector point = createFacePattern(f, i, faces[f], vertices);
      point(point.x, point.y, point.z);
    }
    
    // Draw face outline
    beginShape();
    for (int v = 0; v < 4; v++) {
      vertex(vertices[faces[f][v]].x, vertices[faces[f][v]].y, vertices[faces[f][v]].z);
    }
    endShape(CLOSE);
  }
  
  popMatrix();
}

// Handle laser shutdown when the sketch is closed
void stop() {
  println("Shutting down laser...");
  super.stop();
}
