/**
 * CosmicGrooveWithVisualizer.pde
 * 
 * Modified main sketch file with integrated visualizer support
 * Adds visualization capabilities for testing without laser hardware
 */

import themidibus.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Queue;
import java.util.List;
import java.util.Collections;

/**
 * Cosmic Groove - Sound-Reactive MIDI Laser Display
 * Fusion of Cosmic Dance and R-WDML systems
 * For Etherdream laser controller
 * Creates a responsive visual experience with music
 * 
 * Now with integrated visualizer for development without hardware
 */

// System components
MidiBus myBus;                  // MIDI interface
Minim minim;                    // Audio processing
AudioInput audioInput;          // Microphone input
FFT fft;                        // Fast Fourier Transform for sound analysis
PitchDetectorAutocorrelation PD; // Pitch detection

// Laser boundary constants
final int mi = -32767;
final int mx = 32767;
final int mx2 = mx/2;
final int mi2 = mi/2;
final int laserMax = 65535;

// Laser light constants
final int on = 65535;
final int off = 0;

// MIDI tracking variables
ConcurrentHashMap<Integer, Integer> pitchVelocityMap = new ConcurrentHashMap<Integer, Integer>();
ConcurrentHashMap<Integer, Float> pitchFadeMap = new ConcurrentHashMap<Integer, Float>();

// Particle system from Cosmic Dance
int numParticles = 8;
Particle[] particles;

// Geometric mandala variables
float rotation = 0;
float rotationSpeed = 0.005;
int numPoints = 5;  // Pentagon base
float radius = 15000;
float innerRadius = 7000;
float pulseAmount = 0.2;
float pulseSpeed = 0.02;
float pulse = 0;

// Audio reactivity
float[] spectrum;
int bands = 7;
float[] sum;
float smoothing = 0.4;
float audioInfluence = 0.5;

// Color cycling variables
float hueShift = 0;
float hueShiftSpeed = 0.005;

// Animation counters
int frameCounter = 0;
int animationMode = 0;
boolean midiTrigger = false;

// Store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

// Visualizer component
EtherdreamVisualizer visualizer;

// Optional recording component
SimulationRecorder recorder;

void setup() {
  size(800, 600);  // Increased window size for better visualization
  background(0);
  
  // Initialize MIDI with error handling
  try {
    println("Available MIDI Devices:");
    MidiBus.list(); // List all available MIDI devices
    
    // Only initialize MIDI if devices are available
    if (MidiBus.availableInputs().length > 0 && MidiBus.availableOutputs().length > 0) {
      myBus = new MidiBus(this, 0, 0); // Use first available devices
      println("MIDI initialized with input: " + MidiBus.availableInputs()[0] +
              ", output: " + MidiBus.availableOutputs()[0]);
    } else {
      println("No MIDI devices available. Running without MIDI support.");
      myBus = null;
    }
  } catch (Exception e) {
    // Handle the case where MIDI initialization fails
    println("Could not initialize MIDI. Running without MIDI support.");
    println("Error: " + e.getMessage());
    myBus = null;
  }
  
  // Initialize audio processing
  minim = new Minim(this);
  audioInput = minim.getLineIn(Minim.STEREO);
  fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
  
  // Initialize pitch detection
  PD = new PitchDetectorAutocorrelation();
  PD.SetSampleRate(audioInput.sampleRate());
  
  // Initialize spectrum analysis arrays
  spectrum = new float[bands*25];
  sum = new float[bands*25];
  
  // Create particles
  particles = new Particle[numParticles];
  for (int i = 0; i < numParticles; i++) {
    particles[i] = new Particle();
  }
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  
  laserpoint = p;
  
  // Initialize visualizer instead of standard Etherdream
  visualizer = new EtherdreamVisualizer(this);
  
  // Initialize recorder for saving simulations
  recorder = new SimulationRecorder();
  
  // Set font for UI text
  textFont(createFont("Arial", 12));
  
  // Display instructions
  println("Cosmic Groove Visualizer");
  println("------------------------");
  println("Keyboard Controls:");
  println("H - Toggle UI visibility");
  println("S - Toggle simulation mode");
  println("R - Start/stop recording");
  println("P - Save last recording");
}

void draw() {
  background(0);
  frameCounter++;
  
  // Process MIDI data - fade down velocities for visual effect
  List<Integer> activeKeys = new ArrayList<Integer>();
  if (pitchVelocityMap != null) {
    activeKeys = Collections.list(pitchVelocityMap.keys());
    for (Integer k : activeKeys) {
      Float value = pitchFadeMap.getOrDefault(k, Float.valueOf(0));
      Integer on = pitchVelocityMap.getOrDefault(k, Integer.valueOf(0));
      if (on > 0) {
        value = max(value - 0.001 * (k + 1), 0);
      } else {
        value = max(value - (1.2 + (k / 20.0)), 0);
      }
      pitchFadeMap.put(k, value);
    }
  }
  
  // Audio analysis
  fft.forward(audioInput.mix);
  float currentVolume = audioInput.mix.level();
  
  // Update spectrum data - combines MIDI and audio reactivity
  for (int i = 0; i < bands; i++) {
    // Get the audio energy for this band
    float bandEnergy = fft.getBand(i * 4);
    sum[i] += (bandEnergy * laserMax - sum[i]) * smoothing;
  }
  
  // Switch animation modes based on energy or MIDI events
  if (frameCounter % 300 == 0 || (midiTrigger && frameCounter % 60 == 0)) {
    animationMode = (animationMode + 1) % 3;
    midiTrigger = false;
  }
  
  // Adjust parameters based on audio
  float audioModulation = currentVolume * 5;
  pulseSpeed = 0.02 + (audioModulation * 0.03);
  rotationSpeed = 0.005 + (audioModulation * 0.01);
  
  // Update mandala variables
  pulse = sin(frameCounter * pulseSpeed) * pulseAmount;
  rotation += rotationSpeed;
  hueShift += hueShiftSpeed;
  if (hueShift > 1) hueShift -= 1;
  
  // Create points for laser display
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0)); // Start with blank line
  
  // Choose which pattern to display based on current mode
  switch (animationMode) {
    case 0:
      drawMandala(p, activeKeys);
      break;
    case 1:
      drawParticles(p, activeKeys);
      break;
    case 2:
      drawAudioWaveform(p, activeKeys);
      break;
  }
  
  p.add(new Point(mi, mx, 0, 0, 0)); // End with blank line
  
  // Update the laserpoint reference
  laserpoint = p;
  
  // Convert points to DAC format for the visualizer
  DACPoint[] dacPoints = getDACPointsAdjusted(laserpoint.toArray(new Point[0]));
  
  // Debug - verify points have colors (not all black)
  boolean hasVisiblePoints = false;
  for (DACPoint point : dacPoints) {
    if (point.r > 0 || point.g > 0 || point.b > 0) {
      hasVisiblePoints = true;
      break;
    }
  }
  
  // If no visible points, add a test point to ensure something is visible
  if (!hasVisiblePoints && dacPoints.length > 0) {
    println("Warning: No visible points detected, adding test points");
    DACPoint[] debugPoints = new DACPoint[dacPoints.length + 4];
    System.arraycopy(dacPoints, 0, debugPoints, 0, dacPoints.length);
    
    // Add some visible test points
    debugPoints[dacPoints.length] = new DACPoint(0, 0, 65535, 0, 0);  // Red at center
    debugPoints[dacPoints.length+1] = new DACPoint(mx/2, 0, 0, 65535, 0);  // Green at top right
    debugPoints[dacPoints.length+2] = new DACPoint(-mx/2, 0, 0, 0, 65535);  // Blue at top left
    debugPoints[dacPoints.length+3] = new DACPoint(0, mx/2, 65535, 65535, 0);  // Yellow at bottom
    
    dacPoints = debugPoints;
  }
  
  // Record frame if recording is active
  if (recorder.isRecording()) {
    recorder.recordFrame(dacPoints);
    
    // Display recording status
    fill(255, 0, 0);
    textAlign(LEFT, TOP);
    text("RECORDING: " + recorder.getFrameCount() + " frames", 20, height - 20);
  }
  
  // Update the visualizer with the current points
  visualizer.setLatestFrame(dacPoints);
  
  // Debug information - display point count
  fill(255);
  textAlign(LEFT, TOP);
  text("Generated Points: " + p.size(), 20, height - 40);
  text("DAC Points: " + dacPoints.length, 20, height - 60);
  
  // Draw the visualizer
  visualizer.draw();
}

void drawMandala(ArrayList<Point> p, List<Integer> activeKeys) {
  // Calculate audio-reactive pulsing radius
  float midiInfluence = 0;
  for (Integer k : activeKeys) {
    midiInfluence += pitchFadeMap.getOrDefault(k, Float.valueOf(0)) * 0.001;
  }
  
  float currentRadius = radius * (1 + pulse + midiInfluence);
  float currentInnerRadius = innerRadius * (1 - pulse - midiInfluence);
  
  // Draw outer shape
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    int x = (int)(cos(angle) * currentRadius);
    int y = (int)(sin(angle) * currentRadius);
    
    // Cycle colors - outer edges are more red/yellow
    int r = on;
    int g = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.5)));
    int b = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 0.8)));
    
    if (i == 0) {
      // Move without drawing for first point
      p.add(new Point(x, y, 0, 0, 0));
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // Draw inner shape (rotated slightly)
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    int x = (int)(cos(angle) * currentInnerRadius);
    int y = (int)(sin(angle) * currentInnerRadius);
    
    // Cycle colors - inner shape more blue/purple
    int r = (int)(on * (0.3 + 0.3 * sin(hueShift * TWO_PI + i * 0.8)));
    int g = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 0.5)));
    int b = on;
    
    if (i == 0) {
      // Move without drawing for first point
      p.add(new Point(x, y, 0, 0, 0));
    } else {
      p.add(new Point(x, y, r, g, b));
    }
  }
  
  // Draw connecting lines between inner and outer shapes
  for (int i = 0; i < numPoints; i++) {
    float outerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
    float innerAngle = map(i, 0, numPoints, 0, TWO_PI) + rotation + PI/numPoints;
    
    int outerX = (int)(cos(outerAngle) * currentRadius);
    int outerY = (int)(sin(outerAngle) * currentRadius);
    int innerX = (int)(cos(innerAngle) * currentInnerRadius);
    int innerY = (int)(sin(innerAngle) * currentInnerRadius);
    
    // Move without drawing
    p.add(new Point(outerX, outerY, 0, 0, 0));
    
    // Draw line with green/cyan color
    int r = (int)(on * (0.2 + 0.2 * sin(hueShift * TWO_PI + i * 1.2)));
    int g = on;
    int b = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.7)));
    
    p.add(new Point(innerX, innerY, r, g, b));
  }
  
  // Add MIDI-responsive elements
  for (Integer k : activeKeys) {
    Float faded = pitchFadeMap.getOrDefault(k, Float.valueOf(0));
    if (faded > 0.1) {
      float keyAngle = map(k % 12, 0, 12, 0, TWO_PI);
      float keyRadius = map(k / 12, 0, 8, innerRadius * 0.5, currentRadius * 0.9);
      int keyX = (int)(cos(keyAngle + rotation) * keyRadius);
      int keyY = (int)(sin(keyAngle + rotation) * keyRadius);
      
      // MIDI-triggered point with color based on pitch
      int octave = k / 12;
      int r = (int)(on * (octave % 3 == 0 ? 1 : 0.3));
      int g = (int)(on * (octave % 3 == 1 ? 1 : 0.3));
      int b = (int)(on * (octave % 3 == 2 ? 1 : 0.3));
      
      p.add(new Point(keyX, keyY, r, g, b));
    }
  }
}

void drawParticles(ArrayList<Point> p, List<Integer> activeKeys) {
  // Update and draw each particle
  for (int i = 0; i < particles.length; i++) {
    particles[i].update();
    particles[i].draw(p);
  }
  
  // Add MIDI-responsive elements - fireworks around active notes
  for (Integer k : activeKeys) {
    Float faded = pitchFadeMap.getOrDefault(k, Float.valueOf(0));
    if (faded > 0.1) {
      float baseAngle = map(k % 12, 0, 12, 0, TWO_PI);
      float distance = map(k / 12, 0, 8, 5000, 15000);
      
      // Draw a small firework pattern around the MIDI note
      int centerX = (int)(cos(baseAngle) * distance);
      int centerY = (int)(sin(baseAngle) * distance);
      
      // Move to center without drawing
      p.add(new Point(centerX, centerY, 0, 0, 0));
      
      // Draw rays based on note velocity
      int numRays = 6;
      float rayLength = faded * 50;
      
      for (int ray = 0; ray < numRays; ray++) {
        float rayAngle = map(ray, 0, numRays, 0, TWO_PI);
        int endX = centerX + (int)(cos(rayAngle) * rayLength);
        int endY = centerY + (int)(sin(rayAngle) * rayLength);
        
        // Color based on pitch class
        int note = k % 12;
        int r = (note < 4) ? on : (int)(on * 0.3);
        int g = (note >= 4 && note < 8) ? on : (int)(on * 0.3);
        int b = (note >= 8) ? on : (int)(on * 0.3);
        
        p.add(new Point(endX, endY, r, g, b));
        p.add(new Point(centerX, centerY, 0, 0, 0)); // Return to center
      }
    }
  }
}

void drawAudioWaveform(ArrayList<Point> p, List<Integer> activeKeys) {
  int numSegments = 25;
  int waveHeight = 20000;
  
  // Draw audio waveform
  int prevX = mi;
  int prevY = 0;
  
  p.add(new Point(prevX, prevY, 0, 0, 0)); // Start point
  
  for (int i = 0; i < numSegments; i++) {
    // Calculate x coordinate
    int x = (int)map(i, 0, numSegments - 1, mi, mx);
    
    // Get audio data and MIDI influence for this segment
    float audioLevel = 0;
    int bandIndex = (int)map(i, 0, numSegments - 1, 0, bands - 1);
    audioLevel = sum[bandIndex] / laserMax * waveHeight;
    
    // Add MIDI influence - check if any notes correspond to this segment
    float midiLevel = 0;
    for (Integer k : activeKeys) {
      if (k % numSegments == i) {
        midiLevel += pitchFadeMap.getOrDefault(k, Float.valueOf(0)) * 100;
      }
    }
    
    // Calculate y coordinate with combined audio and MIDI influence
    int y = (int)(sin(frameCounter * 0.02 + i * 0.5) * audioLevel + midiLevel);
    
    // Colors based on segment and frequency content
    int r = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.1)));
    int g = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.2 + PI/3)));
    int b = (int)(on * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.3 + 2*PI/3)));
    
    // Draw line to this point
    p.add(new Point(x, y, r, g, b));
    
    prevX = x;
    prevY = y;
  }
}

/**
 * Process mouse pressed events
 */
void mousePressed() {
  visualizer.mousePressed();
}

/**
 * Process mouse dragged events
 */
void mouseDragged() {
  visualizer.mouseDragged();
}

/**
 * Process mouse released events
 */
void mouseReleased() {
  visualizer.mouseReleased();
}

// Additional keyboard controls for the recorder
void keyPressed() {
  // Pass event to visualizer
  visualizer.keyPressed();
  
  // Recording controls
  if (key == 'r' || key == 'R') {
    if (recorder.isRecording()) {
      recorder.stopRecording();
    } else {
      recorder.startRecording();
    }
  }
  else if (key == 'p' || key == 'P') {
    recorder.saveRecording("laser_recording_" + year() + month() + day() + "_" + hour() + minute() + second());
  }
}

// MIDI event handlers
void noteOn(int channel, int pitch, int velocity) {
  if (myBus != null) {
    pitchVelocityMap.put(Integer.valueOf(pitch), Integer.valueOf(velocity));
    pitchFadeMap.put(Integer.valueOf(pitch), Float.valueOf((float)velocity));
    midiTrigger = true;
  }
}

void noteOff(int channel, int pitch, int velocity) {
  if (myBus != null) {
    pitchVelocityMap.put(Integer.valueOf(pitch), Integer.valueOf(0));
  }
}

void controllerChange(int channel, int number, int value) {
  if (myBus != null) {
    // Use MIDI controllers to adjust parameters if needed
    if (number == 1) { // Mod wheel
      pulseAmount = map(value, 0, 127, 0.1, 0.4);
    } else if (number == 2) { // Breath controller or another CC
      hueShiftSpeed = map(value, 0, 127, 0.001, 0.01);
    } else if (number == 7) { // Volume
      audioInfluence = map(value, 0, 127, 0.1, 1.0);
    }
  }
}

// Convert coordinates
int xToLaserX(int x) {
  return ((laserMax/width)*x)-mx;
}

int yToLaserY(int y) {
  return ((-laserMax/height)*y)+mx;
}

// Helper functions for the laser display
public class Point {
  public final int x, y, r, g, b;
  Point(int x, int y, int r, int g, int b) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;           
  }
}

DACPoint[] getDACPointsDelayAdjusted(Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    }
    return result;
}

DACPoint[] getDACPointsLinearAdjusted(Point a, Point p, int mult) {
    DACPoint[] result = new DACPoint[mult];
    for (int i = 0; i < mult; i++) {
      result[i] = new DACPoint(a.x+(i*((p.x-a.x)/mult)), a.y+(i*((p.y-a.y)/mult)),
            p.r,     p.g,     p.b);
    }
    return result;
}

DACPoint[] getDACPointsLerpAdjusted(Point a, Point p, int mult, float d) {
    DACPoint[] result = new DACPoint[mult];
    int x = a.x;
    int y = a.y;
    int ip=0;
    for (int i = 0; i < mult; i++) {
        x = (int)lerp(x,p.x,d);
        y = (int)lerp(y,p.y,d);
        result[ip] = new DACPoint(x, y,
            p.r,     p.g,     p.b);
        ip++;
    }
    return result;
}

DACPoint[] getDACPoints(Point p) {
    DACPoint[] result = new DACPoint[1];
    result[0] = new DACPoint(p.x, p.y,
            p.r,     p.g,     p.b);
    return result;
}

int distance(Point a, Point b) {
  return (int)sqrt(((a.x-a.y)*(a.x-a.y))+((b.x-b.y)*(b.x-b.y)));
}

DACPoint[] getDACPointsAdjusted(Point[] points) {
    DACPoint[] result = new DACPoint[0];
    Point last = points[points.length-1];
    for(Point p: points){
      int l = distance(last,p);
      
      //lerp adjusted - consistent approach for clean lines
      result = concatPoints(result,getDACPointsLerpAdjusted(last,p,25,0.14));
      
      last = p;
    }
    return result;
}

DACPoint[] concatPoints(DACPoint[]... arrays) {
        // Determine the length of the result array
        int totalLength = 0;
        for (int i = 0; i < arrays.length; i++) {
            totalLength += arrays[i].length;
        }

        // create the result array
        DACPoint[] result = new DACPoint[totalLength];

        // copy the source arrays into the result array
        int currentIndex = 0;
        for (int i = 0; i < arrays.length; i++) {
            System.arraycopy(arrays[i], 0, result, currentIndex, arrays[i].length);
            currentIndex += arrays[i].length;
        }

        return result;
}

DACPoint[] pointsMinimum(DACPoint[] p, int minimum) {
  
  if(p.length >= minimum){
      return p;
  }
  
  if(p.length <= (minimum/4)){
      return pointsMinimum(concatPoints(p,p,p,p), minimum);    
  }
  
  if(p.length <= (minimum/3)){
      return pointsMinimum(concatPoints(p,p,p), minimum);
  }
  
  return pointsMinimum(concatPoints(p,p), minimum);  
}
