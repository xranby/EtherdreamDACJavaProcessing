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
float cubeSize = 1.8;
int pointsPerFace = 40;  // How many points to use for each face pattern

void setup() {
  size(640, 360, P3D);
  frameRate(30);  // Lower framerate for more stability
  
  // Initialize the Etherdream DAC
  // Make sure these values are set in the Etherdream library:
  // private float maxBufferUtilization = 0.85f;  // Increased from 0.65
  // private int maxPointRate = 15000;           // Reduced to 15000
  
  laser = new Etherdream(this);
  
  // Configure for improved stability
  laser.configure(240, true);  // 240 points per frame (6 faces x 40 points)
  
  println("3D Spinning Cube - Initializing...");
  
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
DACPoint[] generateCubePoints(float rotX, float rotY, float rotZ) {
  // Create an array to hold our laser points - 6 faces with pointsPerFace each
  int totalPoints = 6 * pointsPerFace;
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
  
  // Calculate points for each face with its unique pattern
  int pointIndex = 0;
  
  for (int face = 0; face < 6; face++) {
    for (int i = 0; i < pointsPerFace; i++) {
      // Choose a pattern for this face
      PVector point = createFacePattern(face, i, faces[face], vertices);
      
      // Apply 3D rotations - rotateX
      float tempY = point.y;
      float tempZ = point.z;
      point.y = tempY * cosX - tempZ * sinX;
      point.z = tempY * sinX + tempZ * cosX;
      
      // rotateY
      float tempX = point.x;
      tempZ = point.z;
      point.x = tempX * cosY + tempZ * sinY;
      point.z = -tempX * sinY + tempZ * cosY;
      
      // rotateZ
      tempX = point.x;
      tempY = point.y;
      point.x = tempX * cosZ - tempY * sinZ;
      point.y = tempX * sinZ + tempY * cosZ;
      
      // Project 3D to 2D with simple perspective division
      float z = point.z + 3;  // Offset to prevent division by zero
      float scale = 1.5 / z;  // Perspective factor
      float projX = point.x * scale;
      float projY = point.y * scale;
      
      // Scale to stay within laser bounds
      int dacX = (int)(projX * 18000);
      int dacY = (int)(projY * 18000);
      
      // Clamp values to safe limits
      dacX = constrain(dacX, -32000, 32000);
      dacY = constrain(dacY, -32000, 32000);
      
      // Create the point with face color
      points[pointIndex] = new DACPoint(
        dacX, 
        dacY, 
        faceColors[face][0], 
        faceColors[face][1], 
        faceColors[face][2]
      );
      
      pointIndex++;
    }
  }
  
  return points;
}

// Create a unique pattern for each face
PVector createFacePattern(int faceIndex, int pointIndex, int[] faceVertices, PVector[] vertices) {
  float progress = (float)pointIndex / pointsPerFace;
  
  // Get the four corners of this face
  PVector v0 = vertices[faceVertices[0]];
  PVector v1 = vertices[faceVertices[1]];
  PVector v2 = vertices[faceVertices[2]];
  PVector v3 = vertices[faceVertices[3]];
  
  // Different patterns for each face
  switch (faceIndex) {
    case 0:  // Front - Spiral pattern
      float angle = progress * TWO_PI * 2;
      float radius = 0.7 * (1 - progress);
      float centerX = (v0.x + v1.x + v2.x + v3.x) / 4;
      float centerY = (v0.y + v1.y + v2.y + v3.y) / 4;
      float centerZ = (v0.z + v1.z + v2.z + v3.z) / 4;
      return new PVector(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
        centerZ
      );
      
    case 1:  // Back - Starburst pattern
      angle = progress * TWO_PI;
      radius = 0.7 * abs(sin(angle * 5));
      centerX = (v0.x + v1.x + v2.x + v3.x) / 4;
      centerY = (v0.y + v1.y + v2.y + v3.y) / 4;
      centerZ = (v0.z + v1.z + v2.z + v3.z) / 4;
      return new PVector(
        centerX + radius * cos(angle),
        centerY + radius * sin(angle),
        centerZ
      );
      
    case 2:  // Left - Horizontal lines
      float segmentY = floor(progress * 5) / 4;  // 5 segments
      return new PVector(
        v0.x,
        lerp(v0.y, v3.y, segmentY),
        lerp(v0.z, v3.z, progress)
      );
      
    case 3:  // Right - Vertical lines
      float segmentZ = floor(progress * 5) / 4;  // 5 segments
      return new PVector(
        v1.x,
        lerp(v1.y, v2.y, progress),
        lerp(v1.z, v2.z, segmentZ)
      );
      
    case 4:  // Top - Diamond pattern
      angle = progress * TWO_PI;
      radius = 0.7 * abs(cos(angle * 2));
      centerX = (v0.x + v1.x + v2.x + v3.x) / 4;
      centerY = (v0.y + v1.y + v2.y + v3.y) / 4;
      centerZ = (v0.z + v1.z + v2.z + v3.z) / 4;
      return new PVector(
        centerX + radius * cos(angle),
        centerY,
        centerZ + radius * sin(angle)
      );
      
    case 5:  // Bottom - Circular pattern
      angle = progress * TWO_PI;
      centerX = (v0.x + v1.x + v2.x + v3.x) / 4;
      centerY = (v0.y + v1.y + v2.y + v3.y) / 4;
      centerZ = (v0.z + v1.z + v2.z + v3.z) / 4;
      return new PVector(
        centerX + 0.6 * cos(angle),
        centerY,
        centerZ + 0.6 * sin(angle)
      );
      
    default:
      // Default pattern - outline the face
      int sideIndex = (int)(progress * 4);
      float sideProgress = (progress * 4) - sideIndex;
      
      PVector start = vertices[faceVertices[sideIndex]];
      PVector end = vertices[faceVertices[(sideIndex + 1) % 4]];
      
      return new PVector(
        lerp(start.x, end.x, sideProgress),
        lerp(start.y, end.y, sideProgress),
        lerp(start.z, end.z, sideProgress)
      );
  }
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
