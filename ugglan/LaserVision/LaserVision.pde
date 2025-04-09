import themidibus.*;
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
          opencv = new OpenCV(this, sourceImage);
          println("Image loaded successfully: " + imagePath);
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
  
  // Process the current frame
  if (opencv != null) {
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
}

void optimizeContours() {
  optimizedContours.clear();
  
  if (contours == null || contours.size() == 0) {
    return;
  }
  
  // First pass: convert to our format
  for (Contour contour : contours) {
    ArrayList<PVector> points = contour.getPoints();
    
    // Skip contours that are too small
    if (points.size() < 3) {
      continue;
    }
    
    ArrayList<PVector> optimized = new ArrayList<PVector>();
    for (PVector p : points) {
      optimized.add(p);
    }
    
    optimizedContours.add(optimized);
  }
  
  // Second pass: simplify contours
  if (dynamicQuality == 1) {
    // Dynamic quality - reduce until we're under point count
    totalPoints = countTotalPoints();
    
    while (totalPoints > maxPoints && qualityLevel < 10) {
      qualityLevel++;
      simplifyAllContours();
      totalPoints = countTotalPoints();
    }
    
    while (totalPoints < maxPoints/2 && qualityLevel > 1) {
      qualityLevel--;
      simplifyAllContours();
      totalPoints = countTotalPoints();
    }
  } else {
    // Fixed quality level
    simplifyAllContours();
  }
  
  // Sort contours for optimal drawing order
  optimizeRenderingOrder();
}

void simplifyAllContours() {
  for (int i = 0; i < optimizedContours.size(); i++) {
    ArrayList<PVector> contour = optimizedContours.get(i);
    
    if (contour.size() <= 3) {
      continue;
    }
    
    ArrayList<PVector> simplified = new ArrayList<PVector>();
    simplified.add(contour.get(0)); // Always include the first point
    
    // Add every Nth point
    for (int j = 1; j < contour.size() - 1; j += qualityLevel) {
      simplified.add(contour.get(j));
    }
    
    simplified.add(contour.get(contour.size() - 1)); // Always include the last point
    
    optimizedContours.set(i, simplified);
  }
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
  
  for (ArrayList<PVector> contour : optimizedContours) {
    if (contour.size() < 2) continue;
    
    // Move to first point without drawing
    PVector firstPoint = contour.get(0);
    int laserX = (int)map(firstPoint.x, 0, width, mi, mx);
    int laserY = (int)map(firstPoint.y, 0, height, mx, mi); // Invert Y axis
    p.add(new Point(laserX, laserY, 0, 0, 0));
    
    // Draw the rest of the contour
    for (int i = 1; i < contour.size(); i++) {
      PVector point = contour.get(i);
      laserX = (int)map(point.x, 0, width, mi, mx);
      laserY = (int)map(point.y, 0, height, mx, mi); // Invert Y axis
      
      // Color based on position for visual interest
      int r = (int)(on * (0.5 + 0.5 * sin(point.x * 0.01)));
      int g = (int)(on * (0.5 + 0.5 * cos(point.y * 0.01)));
      int b = (int)(on * (0.3 + 0.7 * sin((point.x + point.y) * 0.005)));
      
      p.add(new Point(laserX, laserY, r, g, b));
    }
  }
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
  
  text(modeText, 10, height - 80);
  text("FPS: " + frameRate, 10, height - 60);
  text("Contours: " + optimizedContours.size(), 10, height - 40);
  text("Points: " + totalPoints + " / " + maxPoints, 10, height - 20);
  
  // Display help text
  fill(255, 200);
  textAlign(RIGHT, TOP);
  text("1/2/3: Change mode | +/- : Adjust threshold | Q/A : Blur | W/S : Quality", width - 10, height - 80);
  text("Left click: Draw black | Right click: Draw white | M: Clear", width - 10, height - 60);
  text("Low threshold: " + lowThreshold + " | High threshold: " + highThreshold, width - 10, height - 40);
  text("Quality: " + qualityLevel + " | Blur: " + blurAmount, width - 10, height - 20);
}

void nextGalleryImage() {
  if (gallerySize <= 0) return;
  
  galleryIndex = (galleryIndex + 1) % gallerySize;
  sourceImage = galleryImages[galleryIndex];
  
  if (opencv != null) {
    opencv.loadImage(sourceImage);
  } else {
    opencv = new OpenCV(this, sourceImage);
  }
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
      
      if (opencv != null) {
        opencv.loadImage(sourceImage);
      }
    }
  }
  
  // Adjust thresholds
  if (key == '+' || key == '=') {
    lowThreshold = constrain(lowThreshold + 5, 0, 255);
  } else if (key == '-' || key == '_') {
    lowThreshold = constrain(lowThreshold - 5, 0, 255);
  } else if (key == ']') {
    highThreshold = constrain(highThreshold + 10, 0, 255);
  } else if (key == '[') {
    highThreshold = constrain(highThreshold - 10, 0, 255);
  }
  
  // Adjust blur
  if (key == 'q' || key == 'Q') {
    blurAmount = constrain(blurAmount + 2, 1, 15);
  } else if (key == 'a' || key == 'A') {
    blurAmount = constrain(blurAmount - 2, 1, 15);
  }
  
  // Adjust quality
  if (key == 'w' || key == 'W') {
    qualityLevel = constrain(qualityLevel + 1, 1, 10);
  } else if (key == 's' || key == 'S') {
    qualityLevel = constrain(qualityLevel - 1, 1, 10);
  }
  
  // Toggle dynamic quality
  if (key == 'd' || key == 'D') {
    dynamicQuality = 1 - dynamicQuality;
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
