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

void setup() {
  size(640, 360);
  background(0);
  
  // Initialize MIDI
  MidiBus.list();
  myBus = new MidiBus(this, 1, 2); // Input device 1, output device 2
  
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
  
  // Register Etherdream callback
  Etherdream laser = new Etherdream(this);
}

void draw() {
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

// MIDI event handlers
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

// Etherdream callback - reusing the function from the original code
DACPoint[] getDACPoints() {
    return pointsMinimum(getDACPointsAdjusted(laserpoint.toArray(new Point[0])), 600);
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

// Stub class for pitch detection
/*class PitchDetectorAutocorrelation {
  void SetSampleRate(float rate) {
    // Implementation would go here
  }
  
  long GetTime() {
    return millis();
  }
  
  float GetFrequency() {
    // Simple implementation - could be enhanced
    return audioInput.mix.level() * 1000;
  }
}*/
