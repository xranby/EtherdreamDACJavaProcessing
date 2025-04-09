// Add global variables to track changes and original image
PImage lastProcessedImage = null;
PImage originalImage = null;  // Store the original unmodified image
int lastLowThreshold = -1;
int lastHighThreshold = -1;
int lastBlurAmount = -1;
int lastQualityLevel = -1;
boolean imageChanged = true;
boolean settingsChanged = false;

boolean frameNeedsProcessing() {
  boolean processingNeeded = false;
  
  // For webcam and video, we always process new frames
  if (currentMode == MODE_WEBCAM || currentMode == MODE_VIDEO) {
    processingNeeded = true;
  } 
  // For image mode, only process when image changes or parameters change
  else if (currentMode == MODE_IMAGE) {
    if (imageChanged || 
        lowThreshold != lastLowThreshold || 
        highThreshold != lastHighThreshold ||
        blurAmount != lastBlurAmount ||
        qualityLevel != lastQualityLevel) {
      
      processingNeeded = true;
      
      // Check if settings changed (not just the image content)
      if (lowThreshold != lastLowThreshold || 
          highThreshold != lastHighThreshold ||
          blurAmount != lastBlurAmount ||
          qualityLevel != lastQualityLevel) {
        settingsChanged = true;
      }
      
      // Update our tracking variables
      lastLowThreshold = lowThreshold;
      lastHighThreshold = highThreshold;
      lastBlurAmount = blurAmount;
      lastQualityLevel = qualityLevel;
      imageChanged = false;
    }
  }
  
  return processingNeeded;
}void enforcePointLimit(int limit) {
  // Count current total points
  totalPoints = countTotalPoints();
  
  if (totalPoints <= limit) {
    return; // Already under the limit
  }
  
  // First try: increase simplification level
  int tempQualityLevel = qualityLevel;
  while (totalPoints > limit && tempQualityLevel < 20) {
    tempQualityLevel++;
    
    // Apply higher quality level temporarily
    int savedQualityLevel = qualityLevel;
    qualityLevel = tempQualityLevel;
    simplifyAllContours();
    qualityLevel = savedQualityLevel;
    
    // Recount points
    totalPoints = countTotalPoints();
  }
  
  // If still over limit, start removing smaller contours
  if (totalPoints > limit) {
    // Sort contours by size (smallest first)
    // Use manual bubble sort instead of Collections.sort to avoid generics issues
    for (int i = 0; i < optimizedContours.size() - 1; i++) {
      for (int j = 0; j < optimizedContours.size() - i - 1; j++) {
        if (optimizedContours.get(j).size() > optimizedContours.get(j + 1).size()) {
          // Swap
          ArrayList<PVector> temp = optimizedContours.get(j);
          optimizedContours.set(j, optimizedContours.get(j + 1));
          optimizedContours.set(j + 1, temp);
        }
      }
    }
    
    // Remove smallest contours until under limit
    while (totalPoints > limit && optimizedContours.size() > 0) {
      totalPoints -= optimizedContours.get(0).size();
      optimizedContours.remove(0);
    }
    
    // Resort for optimal drawing
    optimizeRenderingOrder();
  }
  
  // If still over limit as a last resort, apply uniform subsampling
  if (totalPoints > limit) {
    float reductionFactor = (float)limit / totalPoints;
    
    for (int i = 0; i < optimizedContours.size(); i++) {
      ArrayList<PVector> contour = optimizedContours.get(i);
      
      if (contour.size() <= 3) continue;
      
      // Calculate how many points to keep
      int targetSize = max(3, (int)(contour.size() * reductionFactor));
      
      if (targetSize >= contour.size()) continue;
      
      // Create new subsampled contour
      ArrayList<PVector> subsampled = new ArrayList<PVector>();
      subsampled.add(contour.get(0)); // Always include first point
      
      // Add evenly spaced points
      if (targetSize > 2) {
        float step = (contour.size() - 2) / (float)(targetSize - 2);
        for (int j = 1; j < targetSize - 1; j++) {
          int index = 1 + (int)(j * step);
          index = constrain(index, 1, contour.size() - 2);
          subsampled.add(contour.get(index));
        }
      }
      
      subsampled.add(contour.get(contour.size() - 1)); // Always include last point
      
      optimizedContours.set(i, subsampled);
    }
    
    // Final count
    totalPoints = countTotalPoints();
  }
}import themidibus.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.ArrayList;
import gab.opencv.*;
import processing.video.*;
import java.awt.Rectangle;

// System components
MidiBus myBus;
Minim minim;
AudioInput audioInput;
FFT fft;

// Laser boundary constants
final int mi = -32767;
final int mx = 32767;
final int on = 65535;
final int off = 0;

// OpenCV components
OpenCV opencv;
Capture cam;
PImage sourceImage;
PImage edgeImage;
Movie movie;
ArrayList<Contour> contours;
ArrayList<ArrayList<PVector>> optimizedContours;

// Settings for edge detection
int lowThreshold = 100;
int highThreshold = 300;
int blurAmount = 3;
int qualityLevel = 2;
int dynamicQuality = 1;
int maxPoints = 3000;
int totalPoints = 0;

// Interaction controls
int mouseX_prev = -1;
int mouseY_prev = -1;
boolean mouseDown = false;
boolean rightMouseDown = false;

// Display modes
final int MODE_IMAGE = 0;
final int MODE_VIDEO = 1;
final int MODE_WEBCAM = 2;
int currentMode = MODE_WEBCAM;

// Input source paths
String imagePath = "default.jpg";
String videoPath = "default.mp4";
int webcamIndex = 0;

// Laser visualization
volatile ArrayList<Point> laserpoint;
EtherdreamVisualizer visualizer;

// Images for gallery mode
PImage[] galleryImages;
int galleryIndex = 0;
int gallerySize = 0;
int galleryChangeTime = 10000; // in milliseconds
int lastGalleryChange = 0;
boolean galleryMode = false;

// Performance tracking
int frameRate = 0;
int framesProcessed = 0;
long lastFpsUpdate = 0;

void setup() {
  size(800, 600);
  background(0);
  
  // Initialize audio processing
  minim = new Minim(this);
  try {
    audioInput = minim.getLineIn(Minim.STEREO);
    fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
  } catch (Exception e) {
    println("Could not initialize audio. Error: " + e.getMessage());
  }
  
  // Try to initialize MIDI
  try {
    println("Available MIDI Devices:");
    MidiBus.list();
    if (MidiBus.availableInputs().length > 0) {
      myBus = new MidiBus(this, 0, -1);
    }
  } catch (Exception e) {
    println("Could not initialize MIDI. Error: " + e.getMessage());
    myBus = null;
  }
  
  // Initialize data structures
  optimizedContours = new ArrayList<ArrayList<PVector>>();
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  laserpoint = p;
  
  // Initialize visualizer
  visualizer = new EtherdreamVisualizer(this);
  
  // Initialize input source based on mode
  initializeInputSource();
  
  // Set up the UI
  createInterface();
  
  lastFpsUpdate = millis();
}

void initializeInputSource() {
  switch (currentMode) {
    case MODE_IMAGE:
      try {
        sourceImage = loadImage(imagePath);
        if (sourceImage != null) {
          sourceImage.resize(width, height);
          // Store the original image for reloading when settings change
          originalImage = sourceImage.get();
          opencv = new OpenCV(this, sourceImage);
          println("Image loaded successfully: " + imagePath);
          imageChanged = true;
        } else {
          println("Failed to load image: " + imagePath);
        }
      } catch (Exception e) {
        println("Error loading image: " + e.getMessage());
      }
      break;
      
    case MODE_VIDEO:
      try {
        movie = new Movie(this, videoPath);
        movie.loop();
        println("Video loaded successfully: " + videoPath);
      } catch (Exception e) {
        println("Error loading video: " + e.getMessage());
      }
      break;
      
    case MODE_WEBCAM:
      try {
        String[] cameras = Capture.list();
        if (cameras.length > 0) {
          if (webcamIndex >= cameras.length) {
            webcamIndex = 0;
          }
          cam = new Capture(this, cameras[webcamIndex]);
          cam.start();
          println("Webcam started: " + cameras[webcamIndex]);
        } else {
          println("No cameras available. Falling back to image mode.");
          currentMode = MODE_IMAGE;
          initializeInputSource();
        }
      } catch (Exception e) {
        println("Error starting webcam: " + e.getMessage());
        currentMode = MODE_IMAGE;
        initializeInputSource();
      }
      break;
  }
}

void createInterface() {
  // Set font for UI text
  textFont(createFont("Arial", 16, true));
}

void draw() {
  background(0);
  
  // Update input source
  updateInputSource();
  
  // Process the current frame - but only for new/changed frames
  if (opencv != null && frameNeedsProcessing()) {
    // If settings have changed and we're in image mode, reload original image
    if (settingsChanged && currentMode == MODE_IMAGE && originalImage != null) {
      sourceImage = originalImage.get();
      opencv.loadImage(sourceImage);
      settingsChanged = false;
    }
    
    processCurrentFrame();
  }
  
  // Create points for laser display
  ArrayList<Point> p = new ArrayList<Point>();
  
  // Draw contours to laser
  drawContoursToLaser(p);
  
  // Update the laserpoint reference
  laserpoint = p;
  
  // Convert points to DAC format for the visualizer
  DACPoint[] dacPoints = getDACPointsAdjusted(laserpoint.toArray(new Point[0]));
  
  // Update the visualizer with the current points
  visualizer.setLatestFrame(dacPoints);
  
  // Draw the visualizer
  visualizer.draw();
  
  // Draw UI elements directly to the screen (not to laser)
  drawUI();
  
  // Update FPS counter
  framesProcessed++;
  if (millis() - lastFpsUpdate > 1000) {
    frameRate = framesProcessed;
    framesProcessed = 0;
    lastFpsUpdate = millis();
  }
  
  // Handle gallery mode timing
  if (galleryMode && millis() - lastGalleryChange > galleryChangeTime) {
    nextGalleryImage();
    lastGalleryChange = millis();
  }
}

void updateInputSource() {
  switch (currentMode) {
    case MODE_IMAGE:
      // Nothing to update for static image
      break;
      
    case MODE_VIDEO:
      if (movie != null && movie.available()) {
        movie.read();
        sourceImage = movie;
        if (opencv != null) {
          opencv.loadImage(sourceImage);
        } else {
          opencv = new OpenCV(this, sourceImage);
        }
      }
      break;
      
    case MODE_WEBCAM:
      if (cam != null && cam.available()) {
        cam.read();
        sourceImage = cam;
        if (opencv != null) {
          opencv.loadImage(sourceImage);
        } else {
          opencv = new OpenCV(this, sourceImage);
        }
      }
      break;
  }
  
  if (galleryMode && millis() - lastGalleryChange > galleryChangeTime) {
    nextGalleryImage();
    lastGalleryChange = millis();
    imageChanged = true;
  }
}

void processCurrentFrame() {
  // Apply blur to reduce noise
  opencv.blur(blurAmount);
  
  // Find edges using Canny algorithm
  opencv.findCannyEdges(lowThreshold, highThreshold);
  
  // Get the edge image for display
  edgeImage = opencv.getSnapshot();
  
  // Find contours in the edge image
  contours = opencv.findContours();
  
  // Optimize contours for laser display
  optimizeContours();
  
  // Enforce point count limit
  enforcePointLimit(maxPoints);
}

void optimizeContours() {
  optimizedContours.clear();
  
  if (contours == null || contours.size() == 0) {
    return;
  }
  
  // First pass: convert to our format and apply initial filtering
  for (Contour contour : contours) {
    ArrayList<PVector> points = contour.getPoints();
    
    // Skip contours that are too small
    if (points.size() < 3) {
      continue;
    }
    
    // Skip very small contours (likely noise)
    if (contour.area() < 10) {
      continue;
    }
    
    ArrayList<PVector> optimized = new ArrayList<PVector>();
    for (PVector p : points) {
      optimized.add(p);
    }
    
    optimizedContours.add(optimized);
  }
  
  // If we have too many contours, keep only the largest ones
  if (optimizedContours.size() > 100) {
    // Sort contours by area (largest first) using bubble sort
    for (int i = 0; i < optimizedContours.size() - 1; i++) {
      for (int j = 0; j < optimizedContours.size() - i - 1; j++) {
        if (optimizedContours.get(j).size() < optimizedContours.get(j + 1).size()) {
          // Swap
          ArrayList<PVector> temp = optimizedContours.get(j);
          optimizedContours.set(j, optimizedContours.get(j + 1));
          optimizedContours.set(j + 1, temp);
        }
      }
    }
    
    // Keep only the largest contours
    while (optimizedContours.size() > 100) {
      optimizedContours.remove(optimizedContours.size() - 1);
    }
  }
  
  // Apply simplification
  simplifyAllContours();
  
  // Sort contours for optimal drawing order
  optimizeRenderingOrder();
}

void simplifyAllContours() {
  // Apply Douglas-Peucker simplification algorithm
  float epsilon = qualityLevel * 0.5; // Simplification threshold based on quality level
  
  for (int i = 0; i < optimizedContours.size(); i++) {
    ArrayList<PVector> contour = optimizedContours.get(i);
    
    if (contour.size() <= 3) {
      continue;
    }
    
    // Use a more intelligent simplification approach
    ArrayList<PVector> simplified = douglasPeuckerSimplify(contour, epsilon);
    
    // Ensure we have at least start and end points
    if (simplified.size() < 2) {
      simplified.clear();
      simplified.add(contour.get(0));
      simplified.add(contour.get(contour.size() - 1));
    }
    
    optimizedContours.set(i, simplified);
  }
}

ArrayList<PVector> douglasPeuckerSimplify(ArrayList<PVector> points, float epsilon) {
  if (points.size() < 3) {
    return new ArrayList<PVector>(points);
  }
  
  // Find the point with the maximum distance
  float dmax = 0;
  int index = 0;
  
  for (int i = 1; i < points.size() - 1; i++) {
    float d = perpendicularDistance(points.get(i), points.get(0), points.get(points.size() - 1));
    if (d > dmax) {
      index = i;
      dmax = d;
    }
  }
  
  // If max distance is greater than epsilon, recursively simplify
  ArrayList<PVector> resultList = new ArrayList<PVector>();
  if (dmax > epsilon) {
    // Recursive call
    ArrayList<PVector> recResults1 = douglasPeuckerSimplify(new ArrayList<PVector>(points.subList(0, index + 1)), epsilon);
    ArrayList<PVector> recResults2 = douglasPeuckerSimplify(new ArrayList<PVector>(points.subList(index, points.size())), epsilon);
    
    // Build the result list
    resultList.addAll(recResults1.subList(0, recResults1.size() - 1));
    resultList.addAll(recResults2);
  } else {
    // Just return first and last points
    resultList.add(points.get(0));
    resultList.add(points.get(points.size() - 1));
  }
  
  return resultList;
}

float perpendicularDistance(PVector pt, PVector lineStart, PVector lineEnd) {
  float dx = lineEnd.x - lineStart.x;
  float dy = lineEnd.y - lineStart.y;
  
  // Normalize
  float mag = sqrt(dx * dx + dy * dy);
  if (mag > 0.0) {
    dx /= mag;
    dy /= mag;
  }
  
  // Translate the point and get the dot product
  float pvx = pt.x - lineStart.x;
  float pvy = pt.y - lineStart.y;
  float pvdot = dx * pvx + dy * pvy;
  
  // Scale line direction vector
  float dsx = pvdot * dx;
  float dsy = pvdot * dy;
  
  // Subtract this from the point vector
  float ax = pvx - dsx;
  float ay = pvy - dsy;
  
  return sqrt(ax * ax + ay * ay);
}

int countTotalPoints() {
  int total = 0;
  for (ArrayList<PVector> contour : optimizedContours) {
    total += contour.size();
  }
  return total;
}

void optimizeRenderingOrder() {
  if (optimizedContours.size() <= 1) {
    return;
  }
  
  // Sort contours to minimize "pen-up" travel distance
  ArrayList<ArrayList<PVector>> sortedContours = new ArrayList<ArrayList<PVector>>();
  ArrayList<Boolean> used = new ArrayList<Boolean>();
  
  // Initialize used array
  for (int i = 0; i < optimizedContours.size(); i++) {
    used.add(false);
  }
  
  // Start with first contour
  sortedContours.add(optimizedContours.get(0));
  used.set(0, true);
  
  PVector lastPoint = optimizedContours.get(0).get(optimizedContours.get(0).size() - 1);
  
  // Find nearest contour each time
  while (sortedContours.size() < optimizedContours.size()) {
    int bestIndex = -1;
    float bestDistance = Float.MAX_VALUE;
    
    for (int i = 0; i < optimizedContours.size(); i++) {
      if (!used.get(i)) {
        PVector firstPoint = optimizedContours.get(i).get(0);
        float distance = PVector.dist(lastPoint, firstPoint);
        
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }
    }
    
    if (bestIndex >= 0) {
      sortedContours.add(optimizedContours.get(bestIndex));
      used.set(bestIndex, true);
      lastPoint = optimizedContours.get(bestIndex).get(optimizedContours.get(bestIndex).size() - 1);
    } else {
      break; // Shouldn't happen, but just in case
    }
  }
  
  optimizedContours = sortedContours;
}

void drawContoursToLaser(ArrayList<Point> p) {
  if (optimizedContours.size() == 0) {
    // Add a circle if no contours found
    addLaserCircle(p, 0, 0, 10000, 0, on, 0);
    return;
  }
  
  // Track points used so far
  int pointsUsed = 0;
  int pointLimit = min(maxPoints, 3000); // Hard limit of 3000
  
  // First calculate total available points with overhead for jumps
  int totalAvailablePoints = pointLimit - optimizedContours.size(); // One extra point per contour for jumps
  
  // Calculate points per contour fairly
  float pointsPerContour = totalAvailablePoints / (float)optimizedContours.size();
  
  for (ArrayList<PVector> contour : optimizedContours) {
    if (contour.size() < 2) continue;
    
    // Check if we have enough points left
    if (pointsUsed >= pointLimit - 1) {
      break; // Stop if we're at the limit
    }
    
    // How many points to use for this contour
    int pointsToUse = min((int)pointsPerContour, contour.size());
    
    // If very few points left, just draw minimal contours
    if (pointLimit - pointsUsed < 10) {
      pointsToUse = min(3, contour.size());
    }
    
    // Always use at least 2 points if possible
    pointsToUse = max(2, pointsToUse);
    
    // Calculate step size for even distribution
    float step = (contour.size() - 1) / (float)(pointsToUse - 1);
    
    // Move to first point without drawing
    PVector firstPoint = contour.get(0);
    int laserX = (int)map(firstPoint.x, 0, width, mi, mx);
    int laserY = (int)map(firstPoint.y, 0, height, mx, mi);
    p.add(new Point(laserX, laserY, 0, 0, 0));
    pointsUsed++;
    
    // Draw remaining points
    for (int i = 1; i < pointsToUse; i++) {
      int index = min((int)(i * step), contour.size() - 1);
      PVector point = contour.get(index);
      laserX = (int)map(point.x, 0, width, mi, mx);
      laserY = (int)map(point.y, 0, height, mx, mi);
      
      // Color based on position for visual interest
      int r = (int)(on * (0.5 + 0.5 * sin(point.x * 0.01)));
      int g = (int)(on * (0.5 + 0.5 * cos(point.y * 0.01)));
      int b = (int)(on * (0.3 + 0.7 * sin((point.x + point.y) * 0.005)));
      
      p.add(new Point(laserX, laserY, r, g, b));
      pointsUsed++;
      
      // Emergency exit if we're getting too close to the limit
      if (pointsUsed >= pointLimit - 1) {
        break;
      }
    }
  }
  
  // Update the actual point count for display
  totalPoints = pointsUsed;
}

void addLaserCircle(ArrayList<Point> p, int centerX, int centerY, int radius, int r, int g, int b) {
  int numPoints = 16;
  
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI);
    int x = centerX + (int)(cos(angle) * radius);
    int y = centerY + (int)(sin(angle) * radius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0)); // Move without drawing
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
}

void addLaserLine(ArrayList<Point> p, int x1, int y1, int x2, int y2, int r, int g, int b) {
  p.add(new Point(x1, y1, 0, 0, 0)); // Move without drawing
  p.add(new Point(x2, y2, r, g, b)); // Draw colored line
}

void drawUI() {
  // Draw input source on screen
  if (sourceImage != null) {
    image(sourceImage, 0, 0, width/2, height/2);
  }
  
  // Draw edge detection result
  if (edgeImage != null) {
    image(edgeImage, width/2, 0, width/2, height/2);
  }
  
  // Draw status information
  fill(255);
  textAlign(LEFT, TOP);
  
  // Display current mode
  String modeText = "Mode: ";
  switch (currentMode) {
    case MODE_IMAGE: modeText += "Image"; break;
    case MODE_VIDEO: modeText += "Video"; break;
    case MODE_WEBCAM: modeText += "Webcam"; break;
  }
  
  text(modeText, 10, height - 120);
  text("FPS: " + frameRate, 10, height - 100);
  text("Contours: " + optimizedContours.size(), 10, height - 80);
  text("Points: " + totalPoints + " / " + maxPoints, 10, height - 60);
  
  // Display point limiting status
  String limitStatus = "Point Limiting: ";
  if (totalPoints > maxPoints) {
    limitStatus += "OVER LIMIT!";
    fill(255, 0, 0);
  } else if (totalPoints > maxPoints * 0.9) {
    limitStatus += "Near limit";
    fill(255, 255, 0);
  } else {
    limitStatus += "Good";
    fill(0, 255, 0);
  }
  text(limitStatus, 10, height - 40);
  
  // Display settings reload status
  fill(255);
  text("Settings reload: " + (settingsChanged ? "Pending" : "None"), 10, height - 20);
  
  // Display help text
  fill(255, 200);
  textAlign(RIGHT, TOP);
  text("1/2/3: Change mode | +/- : Adjust threshold | Q/A : Blur | W/S : Quality", width - 10, height - 120);
  text("Left click: Draw black | Right click: Draw white | M: Clear | R: Reload", width - 10, height - 100);
  text("Low threshold: " + lowThreshold + " | High threshold: " + highThreshold, width - 10, height - 80);
  text("Quality: " + qualityLevel + " | Blur: " + blurAmount, width - 10, height - 60);
  text("D: Toggle dynamic quality (" + (dynamicQuality==1 ? "ON" : "OFF") + ")", width - 10, height - 40);
  text("Settings changed: " + (settingsChanged ? "YES" : "NO"), width - 10, height - 20);
}

void nextGalleryImage() {
  if (gallerySize <= 0) return;
  
  galleryIndex = (galleryIndex + 1) % gallerySize;
  sourceImage = galleryImages[galleryIndex];
  
  // Store the new image as the original for this gallery item
  originalImage = sourceImage.get();
  
  if (opencv != null) {
    opencv.loadImage(sourceImage);
  } else {
    opencv = new OpenCV(this, sourceImage);
  }
  
  imageChanged = true;
}

void mousePressed() {
  visualizer.mousePressed();
  
  if (mouseButton == LEFT) {
    mouseDown = true;
    mouseX_prev = mouseX;
    mouseY_prev = mouseY;
  } else if (mouseButton == RIGHT) {
    rightMouseDown = true;
    mouseX_prev = mouseX;
    mouseY_prev = mouseY;
  }
}

  void mouseDragged() {
  visualizer.mouseDragged();
  
  if ((mouseDown || rightMouseDown) && sourceImage != null && 
      mouseX_prev != -1 && mouseY_prev != -1 &&
      (mouseX_prev != mouseX || mouseY_prev != mouseY)) {
    
    // Only draw if in image edit area
    if (mouseX < width/2 && mouseY < height/2) {
      // Create PGraphics buffer at the same size as sourceImage
      PGraphics buffer = createGraphics(sourceImage.width, sourceImage.height);
      
      // Draw line with proper scaling
      float scaleX = (float)sourceImage.width / (width/2);
      float scaleY = (float)sourceImage.height / (height/2);
      
      // Map to source image coordinates
      int x1 = (int)(mouseX_prev * scaleX);
      int y1 = (int)(mouseY_prev * scaleY);
      int x2 = (int)(mouseX * scaleX);
      int y2 = (int)(mouseY * scaleY);
      
      // Draw line on buffer
      color lineColor = mouseDown ? color(0) : color(255);
      int brushSize = 5;
      
      buffer.beginDraw();
      buffer.image(sourceImage, 0, 0); // Copy existing image to buffer
      buffer.stroke(lineColor);
      buffer.strokeWeight(brushSize);
      buffer.line(x1, y1, x2, y2);
      buffer.endDraw();
      
      // Replace sourceImage with modified buffer
      sourceImage = buffer.get();
      
      // Update the original image as well, since this is a user edit, not a setting change
      originalImage = sourceImage.get();
      
      // Mark image as changed to trigger reprocessing
      imageChanged = true;
      
      if (opencv != null) {
        opencv.loadImage(sourceImage);
      }
    }
    
    mouseX_prev = mouseX;
    mouseY_prev = mouseY;
  }
}

void mouseReleased() {
  visualizer.mouseReleased();
  
  if (mouseButton == LEFT) {
    mouseDown = false;
  } else if (mouseButton == RIGHT) {
    rightMouseDown = false;
  }
  
  mouseX_prev = -1;
  mouseY_prev = -1;
}

  void keyPressed() {
  // Handle mode switching
  if (key == '1') {
    currentMode = MODE_IMAGE;
    initializeInputSource();
  } else if (key == '2') {
    currentMode = MODE_VIDEO;
    initializeInputSource();
  } else if (key == '3') {
    currentMode = MODE_WEBCAM;
    initializeInputSource();
  } else if (key == 'g' || key == 'G') {
    galleryMode = !galleryMode;
    if (galleryMode && galleryImages == null) {
      loadGalleryImages();
    }
  } else if (key == 'm' || key == 'M') {
    // Clear/reset current image
    if (sourceImage != null) {
      // Create a blank PGraphics buffer
      PGraphics buffer = createGraphics(sourceImage.width, sourceImage.height);
      buffer.beginDraw();
      buffer.background(255);
      buffer.endDraw();
      
      // Replace sourceImage with blank buffer
      sourceImage = buffer.get();
      
      // Update the original image as well
      originalImage = sourceImage.get();
      
      // Mark image as changed to trigger reprocessing
      imageChanged = true;
      
      if (opencv != null) {
        opencv.loadImage(sourceImage);
      }
    }
  } else if (key == 'r' || key == 'R') {
    // Reload original image (useful for undoing drawing)
    if (currentMode == MODE_IMAGE && originalImage != null) {
      sourceImage = originalImage.get();
      imageChanged = true;
      
      if (opencv != null) {
        opencv.loadImage(sourceImage);
      }
    }
  }
  
  // Adjust thresholds
  if (key == '+' || key == '=') {
    lowThreshold = constrain(lowThreshold + 5, 0, 255);
    settingsChanged = true;
  } else if (key == '-' || key == '_') {
    lowThreshold = constrain(lowThreshold - 5, 0, 255);
    settingsChanged = true;
  } else if (key == ']') {
    highThreshold = constrain(highThreshold + 10, 0, 255);
    settingsChanged = true;
  } else if (key == '[') {
    highThreshold = constrain(highThreshold - 10, 0, 255);
    settingsChanged = true;
  }
  
  // Adjust blur
  if (key == 'q' || key == 'Q') {
    blurAmount = constrain(blurAmount + 2, 1, 15);
    settingsChanged = true;
  } else if (key == 'a' || key == 'A') {
    blurAmount = constrain(blurAmount - 2, 1, 15);
    settingsChanged = true;
  }
  
  // Adjust quality
  if (key == 'w' || key == 'W') {
    qualityLevel = constrain(qualityLevel + 1, 1, 10);
    settingsChanged = true;
  } else if (key == 's' || key == 'S') {
    qualityLevel = constrain(qualityLevel - 1, 1, 10);
    settingsChanged = true;
  }
  
  // Toggle dynamic quality
  if (key == 'd' || key == 'D') {
    dynamicQuality = 1 - dynamicQuality;
    settingsChanged = true;
  }
  
  // Pass to visualizer
  visualizer.keyPressed();
}

void loadGalleryImages() {
  // In a real implementation, this would load images from a directory
  // For simplicity, we'll just create placeholder images
  gallerySize = 5;
  galleryImages = new PImage[gallerySize];
  
  for (int i = 0; i < gallerySize; i++) {
    galleryImages[i] = createImage(width, height, RGB);
    galleryImages[i].loadPixels();
    
    // Create a unique pattern for each gallery image
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        float noise = noise(x * 0.01 + i * 10, y * 0.01);
        if (noise > 0.5) {
          galleryImages[i].pixels[y * width + x] = color(255);
        } else {
          galleryImages[i].pixels[y * width + x] = color(0);
        }
      }
    }
    
    galleryImages[i].updatePixels();
  }
}

// For video handling
void movieEvent(Movie m) {
  m.read();
}
