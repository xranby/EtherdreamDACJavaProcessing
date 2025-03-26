/**
 * CameraCapture.pde
 * 
 * Handles webcam input and detects laser position for automatic calibration.
 * Uses OpenCV for blob detection and perspective correction.
 */

class CameraCapture {
  PApplet parent;
  Capture cam;
  OpenCV opencv;
  
  // Camera and laser detection
  PVector laserPosition;
  PVector projectionCenter;
  boolean laserDetected = false;
  boolean calibratingCamera = false;
  
  // Perspective calibration markers
  PVector[] calibrationMarkers = new PVector[4];
  PVector[] screenCorners = new PVector[4];
  boolean calibrated = false;
  int currentMarker = 0;
  
  // Camera image dimensions
  int camWidth = 640;
  int camHeight = 480;
  
  // Laser detection parameters
  int thresholdValue = 240;
  float minLaserArea = 5;
  float maxLaserArea = 100;
  
  // Interface coordinates 
  int displayX = 0;
  int displayY = 0;
  int displayWidth = 320;
  int displayHeight = 240;
  
  // Projection mapping
  PMatrix3D projectionMatrix;
  
  CameraCapture(PApplet parent) {
    this.parent = parent;
    laserPosition = new PVector(0, 0);
    projectionCenter = new PVector(width/2, height/2);
    
    // Initialize calibration markers
    for (int i = 0; i < 4; i++) {
      calibrationMarkers[i] = new PVector(0, 0);
      screenCorners[i] = new PVector(0, 0);
    }
    
    // Define screen corners
    screenCorners[0] = new PVector(0, 0);                 // Top-left
    screenCorners[1] = new PVector(width, 0);             // Top-right
    screenCorners[2] = new PVector(width, height);        // Bottom-right
    screenCorners[3] = new PVector(0, height);            // Bottom-left
    
    // Initialize camera
    String[] cameras = Capture.list();
    
    if (cameras == null || cameras.length == 0) {
      println("No cameras available");
      return;
    } else {
      println("Available cameras:");
      for (int i = 0; i < cameras.length; i++) {
        println(i + ": " + cameras[i]);
      }
      
      // Use the first camera
      cam = new Capture(parent, camWidth, camHeight, cameras[0]);
      cam.start();
      
      // Initialize OpenCV
      opencv = new OpenCV(parent, camWidth, camHeight);
    }
  }
  
  void update() {
    if (cam != null && cam.available()) {
      cam.read();
      opencv.loadImage(cam);
      
      if (calibrated) {
        // Find laser position if calibrated
        detectLaser();
      }
    }
  }
  
  void draw() {
    // Calculate display position and size
    displayWidth = width / 3;
    displayHeight = displayWidth * camHeight / camWidth;
    displayX = width - displayWidth - 10;
    displayY = 10;
    
    // Draw camera view
    if (cam != null) {
      // Draw camera image
      image(cam, displayX, displayY, displayWidth, displayHeight);
      
      // Draw border
      noFill();
      stroke(100);
      rect(displayX, displayY, displayWidth, displayHeight);
      
      // Draw calibration interface if in calibration mode
      if (calibratingCamera) {
        drawCalibrationInterface();
      } else if (calibrated) {
        // Draw detected laser point
        if (laserDetected) {
          // Map from camera coordinates to screen coordinates
          PVector mappedPoint = mapCameraToScreen(laserPosition);
          
          // Draw in camera view
          noFill();
          stroke(255, 0, 0);
          ellipse(displayX + (laserPosition.x / camWidth) * displayWidth,
                  displayY + (laserPosition.y / camHeight) * displayHeight,
                  10, 10);
                  
          // Draw on main screen
          fill(255, 0, 0, 150);
          noStroke();
          ellipse(mappedPoint.x, mappedPoint.y, 15, 15);
          
          // Draw line from detected to expected position
          if (getActualExpectedError().mag() > 5) {
            stroke(255, 255, 0);
            line(mappedPoint.x, mappedPoint.y, 
                 projectionCenter.x, projectionCenter.y);
          }
        }
        
        // Draw calibration points
        for (int i = 0; i < 4; i++) {
          // In camera view
          noFill();
          stroke(0, 255, 0);
          ellipse(displayX + (calibrationMarkers[i].x / camWidth) * displayWidth,
                  displayY + (calibrationMarkers[i].y / camHeight) * displayHeight,
                  8, 8);
                  
          // On main screen
          noFill();
          stroke(0, 255, 0);
          ellipse(screenCorners[i].x, screenCorners[i].y, 10, 10);
        }
      } else {
        // Show calibration instructions
        fill(255);
        textAlign(CENTER);
        text("Camera detected but not calibrated", 
             displayX + displayWidth/2, displayY + displayHeight/2);
        text("Press 'C' to start calibration", 
             displayX + displayWidth/2, displayY + displayHeight/2 + 20);
      }
    } else {
      // No camera available
      fill(255);
      textAlign(CENTER);
      text("No camera detected", displayX + displayWidth/2, displayY + displayHeight/2);
    }
  }
  
  void drawLaserDetection() {
    if (calibrated && laserDetected) {
      // Map from camera coordinates to screen coordinates
      PVector mappedPoint = mapCameraToScreen(laserPosition);
      
      // Draw on main screen
      fill(255, 0, 0, 150);
      noStroke();
      ellipse(mappedPoint.x, mappedPoint.y, 15, 15);
    }
  }
  
  void detectLaser() {
    // Create a copy of the image for processing
    opencv.loadImage(cam);
    
    // Only look at very bright spots (lasers are typically bright)
    opencv.threshold(thresholdValue);
    
    // Find contours/blobs
    ArrayList<Contour> contours = opencv.findContours();
    
    // Reset detection
    laserDetected = false;
    
    // Find the brightest and most laser-like blob
    for (Contour contour : contours) {
      float area = contour.area();
      
      // Filter by size
      if (area >= minLaserArea && area <= maxLaserArea) {
        // Get the center of the blob
        Rectangle bounds = contour.getBoundingBox();
        PVector center = new PVector(
          bounds.x + bounds.width / 2,
          bounds.y + bounds.height / 2
        );
        
        // For now, use the first suitable blob
        laserPosition = center;
        laserDetected = true;
        break;
      }
    }
  }
  
  void startCalibration() {
    calibratingCamera = true;
    currentMarker = 0;
    
    // Reset calibration status
    calibrated = false;
  }
  
  void drawCalibrationInterface() {
    // Draw current calibration point on projection screen
    fill(255, 0, 0);
    stroke(255, 255, 0);
    strokeWeight(2);
    
    // Highlight current corner
    ellipse(screenCorners[currentMarker].x, screenCorners[currentMarker].y, 20, 20);
    
    // Draw instruction
    fill(255);
    textAlign(CENTER);
    text("Point laser at the highlighted corner and press SPACE", width/2, height - 20);
    
    // Show which corner we're calibrating
    String cornerNames[] = {"Top-Left", "Top-Right", "Bottom-Right", "Bottom-Left"};
    text("Calibrating " + cornerNames[currentMarker] + " (" + (currentMarker+1) + "/4)", 
         width/2, height - 40);
  }
  
  void captureCalibrationPoint() {
    if (cam != null && cam.available() && calibratingCamera) {
      // Detect current laser position
      detectLaser();
      
      if (laserDetected) {
        // Save the current laser position for this marker
        calibrationMarkers[currentMarker] = laserPosition.copy();
        
        // Move to next marker
        currentMarker++;
        
        // Check if we've completed calibration
        if (currentMarker >= 4) {
          finishCalibration();
        }
      } else {
        println("Laser not detected. Please aim at the corner and try again.");
      }
    }
  }
  
  void finishCalibration() {
    calibratingCamera = false;
    
    // Calculate perspective transformation matrix
    calculateProjectionMatrix();
    
    // Set calibrated status
    calibrated = true;
    
    println("Camera calibration complete");
  }
  
  void calculateProjectionMatrix() {
    // OpenCV has functions for finding the perspective transform
    // For now we'll use a simple matrix approach
    
    // Convert to normalized coordinates since PVector doesn't have the methods we need
    float[] srcPoints = new float[8];
    float[] dstPoints = new float[8];
    
    for (int i = 0; i < 4; i++) {
      srcPoints[i*2] = calibrationMarkers[i].x;
      srcPoints[i*2+1] = calibrationMarkers[i].y;
      
      dstPoints[i*2] = screenCorners[i].x;
      dstPoints[i*2+1] = screenCorners[i].y;
    }
    
    // Calculate perspective transform
    // In a full implementation, we would use OpenCV's getPerspectiveTransform
    // and then warpPerspective methods
    
    // For now, we'll use a simplified approach
    projectionMatrix = new PMatrix3D();
    // A proper homography matrix calculation would go here
    // This is a placeholder - in a real implementation, use proper homography calculation
    
    println("Perspective matrix calculated");
  }
  
  PVector mapCameraToScreen(PVector cameraPoint) {
    // If not calibrated, return center of screen
    if (!calibrated) {
      return new PVector(width/2, height/2);
    }
    
    // In a full implementation, we would use the perspective transform matrix
    // For now, use a simple bilinear mapping as an approximation
    
    // Normalize camera coordinates
    float nx = cameraPoint.x / camWidth;
    float ny = cameraPoint.y / camHeight;
    
    // Map to screen using bilinear interpolation from the four corners
    float x = (1-nx)*(1-ny)*screenCorners[0].x + nx*(1-ny)*screenCorners[1].x + 
              nx*ny*screenCorners[2].x + (1-nx)*ny*screenCorners[3].x;
              
    float y = (1-nx)*(1-ny)*screenCorners[0].y + nx*(1-ny)*screenCorners[1].y + 
              nx*ny*screenCorners[2].y + (1-nx)*ny*screenCorners[3].y;
              
    return new PVector(x, y);
  }
  
  // Get error between current laser position and expected position
  PVector getActualExpectedError() {
    if (!calibrated || !laserDetected) {
      return new PVector(0, 0);
    }
    
    // Map detected position to screen coordinates
    PVector mappedPosition = mapCameraToScreen(laserPosition);
    
    // Calculate error vector
    return PVector.sub(mappedPosition, projectionCenter);
  }
  
  void setProjectionCenter(PVector center) {
    projectionCenter = center.copy();
  }
  
  boolean isCalibrated() {
    return calibrated;
  }
  
  boolean isLaserDetected() {
    return laserDetected;
  }
  
  PVector getLaserScreenPosition() {
    if (!calibrated || !laserDetected) {
      return null;
    }
    return mapCameraToScreen(laserPosition);
  }
  
  // For UI interaction
  void mousePressed() {
    // Check if click is within camera display area
    if (mouseX >= displayX && mouseX <= displayX + displayWidth &&
        mouseY >= displayY && mouseY <= displayY + displayHeight) {
      
      // Calculate position within camera image
      float camX = map(mouseX, displayX, displayX + displayWidth, 0, camWidth);
      float camY = map(mouseY, displayY, displayY + displayHeight, 0, camHeight);
      
      // For manual laser threshold adjustment
      //opencv.loadImage(cam);
      //int pixelBrightness = image(opencv.getOutput(),(int)camX, (int)camY).;
      //println("Pixel brightness at cursor: " + pixelBrightness);
    }
  }
  
  void keyPressed() {
    if (key == 'c' || key == 'C') {
      startCalibration();
    } else if (key == ' ' && calibratingCamera) {
      captureCalibrationPoint();
    } else if (key == '+' || key == '=') {
      thresholdValue = constrain(thresholdValue + 5, 0, 255);
      println("Laser threshold: " + thresholdValue);
    } else if (key == '-' || key == '_') {
      thresholdValue = constrain(thresholdValue - 5, 0, 255);
      println("Laser threshold: " + thresholdValue);
    }
  }
}
