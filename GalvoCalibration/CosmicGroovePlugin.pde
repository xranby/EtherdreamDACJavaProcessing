/**
 * CosmicGroovePlugin.pde
 * 
 * Plugin implementation of the CosmicGroove MIDI-reactive laser display
 * Adapted to work within the galvanometer calibration framework
 */

import themidibus.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.List;
import java.util.Collections;

/**
 * CosmicGroove - Sound-Reactive MIDI Laser Display
 * Adapted as a plugin for the galvanometer calibration system
 */
class CosmicGroovePlugin implements LaserPlugin {
  // Parent sketch reference
  PApplet parent;
  
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
  
  // Particle system
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
  
  // Store laser points updated by draw()
  ArrayList<DACPoint> currentPoints = new ArrayList<DACPoint>();
  
  // Laser callback
  LaserCallback laserCallback;
  
  // UI elements
  int uiX = 10;
  int uiY = 60;
  int uiWidth = 300;
  int uiHeight = 250;
  
  // Debug flags
  boolean showUI = true;
  boolean debugMode = false;
  
  /**
   * Constructor with parent sketch
   */
  CosmicGroovePlugin(PApplet parent) {
    this.parent = parent;
  }
  
  /**
   * Initialize plugin
   */
  public void setup() {
    // Initialize MIDI if possible
    try {
      MidiBus.list();
      //myBus = new MidiBus(parent, 0, 1); // Input device 1, output device 2
      println("MIDI initialized");
    } catch (Exception e) {
      println("MIDI initialization failed: " + e.getMessage());
    }
    
    // Initialize audio processing
    minim = new Minim(parent);
    try {
      audioInput = minim.getLineIn(Minim.STEREO);
      fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
      
      // Initialize pitch detection
      PD = new PitchDetectorAutocorrelation();
      PD.SetSampleRate(audioInput.sampleRate());
      
      println("Audio input initialized");
    } catch (Exception e) {
      println("Audio initialization failed: " + e.getMessage());
    }
    
    // Initialize spectrum analysis arrays
    spectrum = new float[bands*25];
    sum = new float[bands*25];
    
    // Create particles
    particles = new Particle[numParticles];
    for (int i = 0; i < numParticles; i++) {
      particles[i] = new Particle();
    }
    
    // Start with a blank line
    currentPoints.add(new DACPoint(mi, mx, 0, 0, 0));
    
    // Register MIDI callbacks
    //parent.registerMethod("noteOn", this);
    //parent.registerMethod("noteOff", this);
    //parent.registerMethod("controllerChange", this);
  }
  
  /**
   * Update and render plugin
   */
  public void draw() {
    background(0);
    frameCounter++;
    
    // Process MIDI data - fade down velocities for visual effect
    List<Integer> activeKeys = Collections.list(pitchVelocityMap.keys());
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
    
    // Audio analysis
    if (audioInput != null) {
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
    }
    
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
    
    // Convert to DAC points and send to laser
    convertToDACPoints(p);
    
    // Display UI
    if (showUI) {
      drawUI();
    }
  }
  
  /**
   * Convert Points to DACPoints and update current points list
   */
  void convertToDACPoints(ArrayList<Point> points) {
    // Clear current points
    currentPoints.clear();
    
    // Convert each point to DAC format
    for (Point p : points) {
      currentPoints.add(new DACPoint(p.x, p.y, p.r, p.g, p.b));
    }
    
    // Send to laser via callback
    if (laserCallback != null) {
      laserCallback.sendPoints(currentPoints);
    }
  }
  
  /**
   * Draw UI panel with controls and status
   */
  void drawUI() {
    // Background panel
    fill(0, 0, 0, 200);
    noStroke();
    rect(uiX, uiY, uiWidth, uiHeight);
    
    // Title
    fill(255);
    textAlign(LEFT);
    textSize(16);
    text("CosmicGroove", uiX + 10, uiY + 25);
    
    // Mode indicator
    String[] modeNames = {"Mandala", "Particles", "Waveform"};
    textSize(12);
    text("Mode: " + modeNames[animationMode], uiX + 10, uiY + 50);
    
    // MIDI status
    int activeCount = pitchVelocityMap.size();
    text("Active MIDI Notes: " + activeCount, uiX + 10, uiY + 75);
    
    // Audio level
    float audioLevel = (audioInput != null) ? audioInput.mix.level() * 100 : 0;
    text("Audio Level: " + nf(audioLevel, 0, 1) + "%", uiX + 10, uiY + 100);
    
    // Draw audio level meter
    fill(50);
    rect(uiX + 10, uiY + 110, 150, 10);
    fill(0, 255, 0);
    rect(uiX + 10, uiY + 110, 150 * constrain(audioLevel/100, 0, 1), 10);
    
    // Controls help
    textSize(10);
    text("Controls:", uiX + 10, uiY + 140);
    text("1-3: Change Mode", uiX + 20, uiY + 160);
    text("↑/↓: Adjust Speed", uiX + 20, uiY + 175);
    text("←/→: Adjust Size", uiX + 20, uiY + 190);
    text("SPACE: Toggle UI", uiX + 20, uiY + 205);
    text("D: Debug Mode", uiX + 20, uiY + 220);
  }
  
  /**
   * Draw mandala pattern
   */
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
  
  /**
   * Draw particle pattern
   */
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
  
  /**
   * Draw audio waveform pattern
   */
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
   * Process keypress events
   */
  public void keyPressed() {
    if (key >= '1' && key <= '3') {
      // Switch animation mode
      animationMode = key - '1';
    } else if (key == ' ') {
      // Toggle UI
      showUI = !showUI;
    } else if (key == 'd' || key == 'D') {
      // Toggle debug mode
      debugMode = !debugMode;
    } else if (keyCode == UP) {
      // Increase speed
      pulseSpeed *= 1.1;
      rotationSpeed *= 1.1;
    } else if (keyCode == DOWN) {
      // Decrease speed
      pulseSpeed /= 1.1;
      rotationSpeed /= 1.1;
    } else if (keyCode == LEFT) {
      // Decrease size
      radius *= 0.9;
      innerRadius *= 0.9;
    } else if (keyCode == RIGHT) {
      // Increase size
      radius *= 1.1;
      innerRadius *= 1.1;
    }
  }
  
  /**
   * Handle key release events
   */
  public void keyReleased() {
    // Nothing special on key release
  }
  
  /**
   * Handle mouse press events
   */
  public void mousePressed() {
    // Nothing special on mouse press
  }
  
  /**
   * Handle mouse drag events
   */
  public void mouseDragged() {
    // Nothing special on mouse drag
  }
  
  /**
   * Handle mouse release events
   */
  public void mouseReleased() {
    // Nothing special on mouse release
  }
  
  /**
   * Cleanup before plugin is deactivated
   */
  public void cleanup() {
    // Release MIDI resources
    if (myBus != null) {
      myBus.close();
    }
    
    // Release audio resources
    if (minim != null) {
      if (audioInput != null) {
        audioInput.close();
      }
      minim.stop();
    }
    
    // Unregister MIDI callbacks
    //parent.unregisterMethod("noteOn", this);
    //parent.unregisterMethod("noteOff", this);
    //parent.unregisterMethod("controllerChange", this);
  }
  
  /**
   * Return current laser points
   */
  public ArrayList<DACPoint> getPoints() {
    return currentPoints;
  }
  
  /**
   * Set laser callback
   */
  public void setLaserCallback(LaserCallback callback) {
    this.laserCallback = callback;
  }
  
  /**
   * Get plugin name
   */
  public String getName() {
    return "CosmicGroove";
  }
  
  /**
   * Get plugin description
   */
  public String getDescription() {
    return "Sound-reactive MIDI laser display";
  }
  
  /**
   * MIDI event handlers
   */
  void noteOn(int channel, int pitch, int velocity) {
    pitchVelocityMap.put(Integer.valueOf(pitch), Integer.valueOf(velocity));
    pitchFadeMap.put(Integer.valueOf(pitch), Float.valueOf((float)velocity));
    midiTrigger = true;
  }
  
  void noteOff(int channel, int pitch, int velocity) {
    pitchVelocityMap.put(Integer.valueOf(pitch), Integer.valueOf(0));
  }
  
  void controllerChange(int channel, int number, int value) {
    // Use MIDI controllers to adjust parameters if needed
    if (number == 1) { // Mod wheel
      pulseAmount = map(value, 0, 127, 0.1, 0.4);
    } else if (number == 2) { // Breath controller or another CC
      hueShiftSpeed = map(value, 0, 127, 0.001, 0.01);
    } else if (number == 7) { // Volume
      audioInfluence = map(value, 0, 127, 0.1, 1.0);
    }
  }
  
  // Particle class for dynamic element
  class Particle {
    PVector pos;
    PVector vel;
    float angle;
    float angleSpeed;
    float size;
    float lifespan;
    float maxLife;
    
    Particle() {
      reset();
    }
    
    void reset() {
      angle = random(TWO_PI);
      angleSpeed = random(0.01, 0.05) * (random(1) > 0.5 ? 1 : -1);
      size = random(2000, 5000);
      maxLife = random(100, 200);
      lifespan = maxLife;
      
      // Start from center
      pos = new PVector(0, 0);
      
      // Random velocity direction
      float a = random(TWO_PI);
      vel = new PVector(cos(a), sin(a));
      vel.mult(random(200, 500));
    }
    
    void update() {
      // Update position and angle
      pos.add(vel);
      angle += angleSpeed;
      lifespan -= 1;
      
      // Reset if out of bounds or lifespan ended
      if (lifespan <= 0 || abs(pos.x) > mx || abs(pos.y) > mx) {
        reset();
      }
    }
    
    void draw(ArrayList<Point> p) {
      // Calculate alpha based on lifespan
      float alpha = lifespan / maxLife;
      
      // Draw a spiral or star shape for each particle
      int segments = 4;  // Keep segment count low for performance
      
      // Move to first point without drawing
      int startX = (int)(pos.x + cos(angle) * size);
      int startY = (int)(pos.y + sin(angle) * size);
      p.add(new Point(startX, startY, 0, 0, 0));
      
      for (int i = 1; i <= segments; i++) {
        float a = angle + map(i, 0, segments, 0, TWO_PI);
        float r = (i % 2 == 0) ? size : size * 0.5;
        
        int x = (int)(pos.x + cos(a) * r);
        int y = (int)(pos.y + sin(a) * r);
        
        // Unique color for each particle
        int red = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.5)));
        int green = (int)(on * alpha * (0.5 + 0.5 * cos(hueShift * TWO_PI + i * 0.7)));
        int blue = (int)(on * alpha * (0.5 + 0.5 * sin(hueShift * TWO_PI + i * 0.9)));
        
        p.add(new Point(x, y, red, green, blue));
      }
      
      // Connect back to first point
      p.add(new Point(startX, startY, 0, 0, 0));
    }
  }
}

// Helper class for Point representation
class Point {
  public final int x, y, r, g, b;
  
  Point(int x, int y, int r, int g, int b) {
     this.x=x;this.y=y;this.r=r;this.g=g;this.b=b;           
  }
}

// Helper class for pitch detection (minimal implementation)
class PitchDetectorAutocorrelation {
  float sampleRate = 44100;
  
  void SetSampleRate(float rate) {
    sampleRate = rate;
  }
  
  float GetFrequency() {
    // Simple implementation that returns audio level
    return 440; // Default pitch
  }
}
