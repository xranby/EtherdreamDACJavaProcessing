

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
PitchDetectorAutocorrelation PD; // Pitch detection

final int laserMax = 65535;

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
float audioInfluence = 0.5;

// Color cycling variables
float hueShift = 0;
float hueShiftSpeed = 0.005;

// Animation counters
int frameCounter = 0;
int animationMode = 0;
boolean midiTrigger = false;


// Optional recording component
SimulationRecorder recorder;
/**
   * Get a copy of the current DAC points
   * This method can be called from any thread
   * @return An array of the current DAC points
   */
  public DACPoint[] getDACPoints() {
    return visualizer.latestFrame;
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

/**
 * TailBlazer.pde
 * 
 * A laser-compatible arcade game where you navigate through obstacles
 * with both screen visualization and laser output support
 * Based on the Cosmic Groove system
 */

import themidibus.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.ArrayList;

// System components
MidiBus myBus;                  // MIDI interface
Minim minim;                    // Audio processing
AudioInput audioInput;          // Microphone input
FFT fft;                        // Fast Fourier Transform for sound analysis

// Laser boundary constants
final int mi = -32767;
final int mx = 32767;

// Laser light constants
final int on = 65535;
final int off = 0;

// Game variables
Player player;
ArrayList<Obstacle> obstacles;
ArrayList<PowerUp> powerUps;
ArrayList<Particle> explosionParticles;
int score = 0;
int lives = 3;
boolean gameOver = false;
boolean gameStarted = false;
int difficulty = 1;
int framesSinceLastObstacle = 0;
int nextObstacleFrame = 60;

// Audio reactivity
float[] spectrum;
int bands = 7;
float[] sum;
float smoothing = 0.4;
float audioReactivity = 0.0;

// Store uncoverted laser points updated by draw()
volatile ArrayList<Point> laserpoint;

// Visualizer component
EtherdreamVisualizer visualizer;

void setup() {
  size(800, 600);
  background(0);
  
  // Initialize audio processing
  minim = new Minim(this);
  try {
    audioInput = minim.getLineIn(Minim.STEREO);
    fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
    
    // Initialize spectrum analysis arrays
    spectrum = new float[bands];
    sum = new float[bands];
  } catch (Exception e) {
    println("Could not initialize audio. Running without audio reactivity.");
    println("Error: " + e.getMessage());
  }
  
  // Try to initialize MIDI
  try {
    println("Available MIDI Devices:");
    MidiBus.list();
    
    if (MidiBus.availableInputs().length > 0) {
      myBus = new MidiBus(this, 0, -1); // Input only
      println("MIDI initialized with input: " + MidiBus.availableInputs()[0]);
    } else {
      println("No MIDI devices available. Running without MIDI support.");
      myBus = null;
    }
  } catch (Exception e) {
    println("Could not initialize MIDI. Using keyboard controls only.");
    println("Error: " + e.getMessage());
    myBus = null;
  }
  
  // Initialize game objects
  player = new Player();
  obstacles = new ArrayList<Obstacle>();
  powerUps = new ArrayList<PowerUp>();
  explosionParticles = new ArrayList<Particle>();
  
  // Initialize laser points list
  ArrayList<Point> p = new ArrayList<Point>();
  p.add(new Point(mi, mx, 0, 0, 0));  // Start with blank line
  laserpoint = p;
  
  // Initialize visualizer
  visualizer = new EtherdreamVisualizer(this);
  
  // Set font for UI text
  textFont(createFont("Arial", 16, true));
}

void draw() {
  background(0);
  
  // Process audio if available
  if (audioInput != null) {
    fft.forward(audioInput.mix);
    audioReactivity = audioInput.mix.level() * 5;
    
    // Update spectrum data
    for (int i = 0; i < bands; i++) {
      float bandEnergy = fft.getBand(i * 4);
      sum[i] += (bandEnergy - sum[i]) * smoothing;
    }
  }
  
  // Create points for laser display
  ArrayList<Point> p = new ArrayList<Point>();
  
  // Game state handling
  if (!gameStarted) {
    drawTitleScreen(p);
  } else if (gameOver) {
    drawGameOverScreen(p);
  } else {
    updateGame();
    drawGame(p);
  }
  
  // Update the laserpoint reference
  laserpoint = p;
  
  // Convert points to DAC format for the visualizer
  DACPoint[] dacPoints = getDACPointsAdjusted(laserpoint.toArray(new Point[0]));
  
  // Update the visualizer with the current points
  visualizer.setLatestFrame(dacPoints);
  
  // Draw the visualizer
  visualizer.draw();
  
  // Draw game UI elements directly to the screen (not to laser)
  if (gameStarted && !gameOver) {
    fill(255);
    textAlign(LEFT, TOP);
    text("Score: " + score, 20, 20);
    text("Lives: " + lives, 20, 50);
    text("Level: " + difficulty, 20, 80);
  }
}

void drawTitleScreen(ArrayList<Point> p) {
  // Draw title in center - both screen and laser
  String title = "TAILBLAZER";
  textAlign(CENTER, CENTER);
  fill(255);
  textSize(48);
  text(title, width/2, height/3);
  text("Press SPACE to start", width/2, height/2);
  text("ARROW KEYS to move", width/2, height/2 + 50);
  
  // Draw title for laser - simplified geometry
  int titleX = 0;
  int titleY = 5000;
  int letterSpacing = 5000;
  
  // T
  addLaserLine(p, titleX - 15000, titleY, titleX - 5000, titleY, 0, on, 0);
  addLaserLine(p, titleX - 10000, titleY, titleX - 10000, titleY - 10000, 0, on, 0);
  
  // Draw pulsing border
  float pulseAmount = 0.2 + (sin(frameCount * 0.05) * 0.1);
  float radius = 25000 * pulseAmount;
  int numPoints = 8;
  
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI);
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0)); // Move without drawing
    } else {
      // Rainbow color effect
      int r = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5)));
      int g = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5 + PI/2)));
      int b = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5 + PI)));
      p.add(new Point(x, y, r, g, b));
    }
  }
}

void drawGameOverScreen(ArrayList<Point> p) {
  // Draw game over screen
  textAlign(CENTER, CENTER);
  fill(255, 0, 0);
  textSize(48);
  text("GAME OVER", width/2, height/3);
  fill(255);
  textSize(24);
  text("Final Score: " + score, width/2, height/2);
  text("Press SPACE to restart", width/2, height/2 + 50);
  
  // Draw laser game over visualization
  int centerX = 0;
  int centerY = 0;
  
  // Draw X shape
  addLaserLine(p, centerX - 15000, centerY - 15000, centerX + 15000, centerY + 15000, on, 0, 0);
  addLaserLine(p, centerX + 15000, centerY - 15000, centerX - 15000, centerY + 15000, on, 0, 0);
  
  // Draw score visualization - stack of bars
  int barWidth = 20000;
  int barHeight = 2000;
  int scoreHeight = min(score / 100, 10);
  
  for (int i = 0; i < scoreHeight; i++) {
    int barY = centerY + 15000 - (i * 3000);
    addLaserLine(p, centerX - barWidth/2, barY, centerX + barWidth/2, barY, 0, on, on);
  }
}

void updateGame() {
  // Update player
  player.update();
  
  // Generate obstacles
  framesSinceLastObstacle++;
  if (framesSinceLastObstacle > nextObstacleFrame) {
    obstacles.add(new Obstacle());
    framesSinceLastObstacle = 0;
    nextObstacleFrame = 60 - (difficulty * 5);
    nextObstacleFrame = max(nextObstacleFrame, 20); // Don't go below 20 frames
    
    // Occasionally add power-ups
    if (random(1) < 0.2) {
      powerUps.add(new PowerUp());
    }
  }
  
  // Update obstacles
  for (int i = obstacles.size() - 1; i >= 0; i--) {
    Obstacle obstacle = obstacles.get(i);
    obstacle.update();
    
    // Check collision with player
    if (obstacle.checkCollision(player) && !player.isInvulnerable()) {
      // Add explosion particles
      for (int j = 0; j < 10; j++) {
        explosionParticles.add(new Particle(player.x, player.y));
      }
      
      obstacles.remove(i);
      lives--;
      player.setInvulnerable(120); // 2 seconds of invulnerability
      
      if (lives <= 0) {
        gameOver = true;
      }
    }
    
    // Remove if off screen
    if (obstacle.y > height + 50) {
      obstacles.remove(i);
      score += 10 * difficulty;
    }
  }
  
  // Update power-ups
  for (int i = powerUps.size() - 1; i >= 0; i--) {
    PowerUp powerUp = powerUps.get(i);
    powerUp.update();
    
    // Check collision with player
    if (powerUp.checkCollision(player)) {
      applyPowerUp(powerUp.type);
      powerUps.remove(i);
    }
    
    // Remove if off screen
    if (powerUp.y > height + 50) {
      powerUps.remove(i);
    }
  }
  
  // Update explosion particles
  for (int i = explosionParticles.size() - 1; i >= 0; i--) {
    Particle particle = explosionParticles.get(i);
    particle.update();
    if (particle.lifespan <= 0) {
      explosionParticles.remove(i);
    }
  }
  
  // Increase difficulty every 1000 points
  if (score > difficulty * 1000) {
    difficulty++;
  }
}

void applyPowerUp(int type) {
  switch (type) {
    case 0: // Extra life
      lives++;
      break;
    case 1: // Score boost
      score += 100 * difficulty;
      break;
    case 2: // Invulnerability
      player.setInvulnerable(300); // 5 seconds
      break;
  }
}

void drawGame(ArrayList<Point> p) {
  // Limit to about 50 laser lines total for performance
  int remainingLines = 50;
  
  // Draw player - higher priority
  int playerLines = player.draw(p);
  remainingLines -= playerLines;
  
  // Draw explosion particles - medium priority
  int particleLines = 0;
  for (Particle particle : explosionParticles) {
    if (remainingLines > 5) { // Reserve some lines for obstacles
      particleLines += particle.draw(p);
      remainingLines -= particleLines;
    }
  }
  
  // Draw power-ups - medium priority
  int powerUpLines = 0;
  for (PowerUp powerUp : powerUps) {
    if (remainingLines > 5) { // Reserve some lines for obstacles
      powerUpLines += powerUp.draw(p);
      remainingLines--;
    }
  }
  
  // Draw obstacles - lower priority but always show some
  int obstacleLines = 0;
  int obstaclesDrawn = 0;
  for (Obstacle obstacle : obstacles) {
    if (remainingLines > 0 || obstaclesDrawn < 3) { // Always draw at least 3 obstacles
      obstacleLines += obstacle.draw(p);
      remainingLines--;
      obstaclesDrawn++;
    } else {
      // Draw on screen only
      obstacle.drawOnScreen();
    }
  }
  
  // Draw on-screen elements that aren't sent to laser
  player.drawOnScreen();
  for (Particle particle : explosionParticles) {
    particle.drawOnScreen();
  }
  for (PowerUp powerUp : powerUps) {
    powerUp.drawOnScreen();
  }
}

void addLaserLine(ArrayList<Point> p, int x1, int y1, int x2, int y2, int r, int g, int b) {
  p.add(new Point(x1, y1, 0, 0, 0)); // Move without drawing
  p.add(new Point(x2, y2, r, g, b)); // Draw colored line
}

void keyPressed() {
  // Game controls
  if (key == ' ') {
    if (!gameStarted) {
      gameStarted = true;
    } else if (gameOver) {
      // Reset game
      player = new Player();
      obstacles.clear();
      powerUps.clear();
      explosionParticles.clear();
      score = 0;
      lives = 3;
      difficulty = 1;
      gameOver = false;
    }
  }
  
  // Player movement
  if (keyCode == LEFT) {
    player.setMoving(-1, 0);
  } else if (keyCode == RIGHT) {
    player.setMoving(1, 0);
  } else if (keyCode == UP) {
    player.setMoving(0, -1);
  } else if (keyCode == DOWN) {
    player.setMoving(0, 1);
  }
  
  // Pass to visualizer
  visualizer.keyPressed();
}

void keyReleased() {
  // Stop player movement when key is released
  if (keyCode == LEFT || keyCode == RIGHT) {
    player.setMoving(0, player.moveY);
  } else if (keyCode == UP || keyCode == DOWN) {
    player.setMoving(player.moveX, 0);
  }
}

// MIDI control - use MIDI notes for movement
void noteOn(int channel, int pitch, int velocity) {
  if (myBus != null && velocity > 0) {
    // Map MIDI notes to controls
    switch (pitch % 12) {
      case 0: // C - left
        player.setMoving(-1, player.moveY);
        break;
      case 2: // D - right
        player.setMoving(1, player.moveY);
        break;
      case 4: // E - up
        player.setMoving(player.moveX, -1);
        break;
      case 5: // F - down
        player.setMoving(player.moveX, 1);
        break;
      case 7: // G - start/restart
        if (!gameStarted) {
          gameStarted = true;
        } else if (gameOver) {
          // Reset game
          player = new Player();
          obstacles.clear();
          powerUps.clear();
          explosionParticles.clear();
          score = 0;
          lives = 3;
          difficulty = 1;
          gameOver = false;
        }
        break;
    }
  }
}

void noteOff(int channel, int pitch, int velocity) {
  if (myBus != null) {
    // Stop movement when key is released
    switch (pitch % 12) {
      case 0: // C - left
      case 2: // D - right
        player.setMoving(0, player.moveY);
        break;
      case 4: // E - up
      case 5: // F - down
        player.setMoving(player.moveX, 0);
        break;
    }
  }
}

// Game classes
class Player {
  float x, y;
  float size;
  int moveX, moveY;
  float speed;
  int invulnerableFrames;
  
  Player() {
    x = width / 2;
    y = height - 100;
    size = 20;
    moveX = 0;
    moveY = 0;
    speed = 5;
    invulnerableFrames = 0;
  }
  
  void update() {
    // Movement
    x += moveX * speed;
    y += moveY * speed;
    
    // Screen boundaries
    x = constrain(x, size, width - size);
    y = constrain(y, size, height - size);
    
    // Update invulnerability
    if (invulnerableFrames > 0) {
      invulnerableFrames--;
    }
  }
  
  int draw(ArrayList<Point> p) {
    // Don't draw to laser if invulnerable (blinking effect)
    if (invulnerableFrames > 0 && frameCount % 10 < 5) {
      return 0;
    }
    
    // Convert screen coordinates to laser coordinates
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserSize = (int)map(size, 0, width, 0, mx-mi) / 2;
    
    // Draw triangle for player ship
    int tipX = laserX;
    int tipY = laserY - laserSize;
    int leftX = laserX - laserSize;
    int leftY = laserY + laserSize;
    int rightX = laserX + laserSize;
    int rightY = laserY + laserSize;
    
    // Draw the three lines of the triangle
    addLaserLine(p, tipX, tipY, leftX, leftY, 0, on, on);
    addLaserLine(p, leftX, leftY, rightX, rightY, 0, on, on);
    addLaserLine(p, rightX, rightY, tipX, tipY, 0, on, on);
    
    // Draw player trail if moving
    if (moveX != 0 || moveY != 0) {
      int trailX = laserX - (moveX * laserSize * 2);
      int trailY = laserY - (moveY * laserSize * 2);
      addLaserLine(p, laserX, laserY, trailX, trailY, on, 0, on);
    }
    
    return 4; // 4 lines drawn
  }
  
  void drawOnScreen() {
    // Draw on screen with fancy effects
    if (invulnerableFrames > 0 && frameCount % 10 < 5) {
      fill(255, 100, 100, 150);
    } else {
      fill(0, 255, 255);
    }
    
    // Draw player ship
    noStroke();
    beginShape();
    vertex(x, y - size);
    vertex(x - size, y + size);
    vertex(x + size, y + size);
    endShape(CLOSE);
    
    // Draw engine flame
    if (moveY != 0 || moveX != 0) {
      fill(255, 150, 0);
      beginShape();
      vertex(x - size/2, y + size);
      vertex(x, y + size * 1.5);
      vertex(x + size/2, y + size);
      endShape(CLOSE);
    }
  }
  
  void setMoving(int x, int y) {
    moveX = x;
    moveY = y;
  }
  
  boolean isInvulnerable() {
    return invulnerableFrames > 0;
  }
  
  void setInvulnerable(int frames) {
    invulnerableFrames = frames;
  }
}

class Obstacle {
  float x, y;
  float w, h;
  float speed;
  int type;
  
  Obstacle() {
    x = random(width * 0.1, width * 0.9);
    y = -50;
    w = random(30, 100);
    h = random(20, 50);
    speed = random(2, 5) + (difficulty * 0.5);
    type = int(random(3)); // Different obstacle types
  }
  
  void update() {
    y += speed;
  }
  
  boolean checkCollision(Player player) {
    // Simple rectangular collision
    return (abs(x - player.x) < (w/2 + player.size/2) &&
            abs(y - player.y) < (h/2 + player.size/2));
  }
  
  int draw(ArrayList<Point> p) {
    // Convert screen coordinates to laser coordinates
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserW = (int)map(w, 0, width, 0, mx-mi);
    int laserH = (int)map(h, 0, height, 0, mx-mi);
    
    // Red color for obstacles
    int r = on;
    int g = 0;
    int b = 0;
    
    if (type == 0) {
      // Rectangle obstacle
      int leftX = laserX - laserW/2;
      int rightX = laserX + laserW/2;
      int topY = laserY - laserH/2;
      int bottomY = laserY + laserH/2;
      
      addLaserLine(p, leftX, topY, rightX, topY, r, g, b);
      addLaserLine(p, rightX, topY, rightX, bottomY, r, g, b);
      addLaserLine(p, rightX, bottomY, leftX, bottomY, r, g, b);
      addLaserLine(p, leftX, bottomY, leftX, topY, r, g, b);
      
      return 4;
    } else if (type == 1) {
      // X obstacle
      int size = laserW/2;
      addLaserLine(p, laserX - size, laserY - size, laserX + size, laserY + size, r, g, b);
      addLaserLine(p, laserX - size, laserY + size, laserX + size, laserY - size, r, g, b);
      
      return 2;
    } else {
      // Triangle obstacle
      int topX = laserX;
      int topY = laserY - laserH/2;
      int leftX = laserX - laserW/2;
      int rightX = laserX + laserW/2;
      int bottomY = laserY + laserH/2;
      
      addLaserLine(p, topX, topY, rightX, bottomY, r, g, b);
      addLaserLine(p, rightX, bottomY, leftX, bottomY, r, g, b);
      addLaserLine(p, leftX, bottomY, topX, topY, r, g, b);
      
      return 3;
    }
  }
  
  void drawOnScreen() {
    // Draw with screen effects
    fill(255, 0, 0);
    noStroke();
    
    if (type == 0) {
      // Rectangle
      rectMode(CENTER);
      rect(x, y, w, h);
    } else if (type == 1) {
      // X shape
      stroke(255, 0, 0);
      strokeWeight(3);
      line(x - w/2, y - h/2, x + w/2, y + h/2);
      line(x - w/2, y + h/2, x + w/2, y - h/2);
      noStroke();
    } else {
      // Triangle
      triangle(x, y - h/2, x + w/2, y + h/2, x - w/2, y + h/2);
    }
  }
}

class PowerUp {
  float x, y;
  float size;
  float speed;
  int type; // 0: extra life, 1: score boost, 2: invulnerability
  float rotation;
  
  PowerUp() {
    x = random(width * 0.1, width * 0.9);
    y = -30;
    size = 15;
    speed = random(2, 4);
    type = int(random(3));
    rotation = 0;
  }
  
  void update() {
    y += speed;
    rotation += 0.05;
  }
  
  boolean checkCollision(Player player) {
    // Simple distance-based collision
    return (dist(x, y, player.x, player.y) < (size + player.size/2));
  }
  
  int draw(ArrayList<Point> p) {
    // Convert screen coordinates to laser coordinates
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserSize = (int)map(size, 0, width, 0, mx-mi);
    
    // Color based on power-up type
    int r = (type == 0) ? on : 0;
    int g = (type == 1) ? on : 0;
    int b = (type == 2) ? on : 0;
    
    // Draw circle for power-up
    int numPoints = 8;
    int prevX = 0;
    int prevY = 0;
    
    for (int i = 0; i <= numPoints; i++) {
      float angle = map(i, 0, numPoints, 0, TWO_PI) + rotation;
      int pointX = laserX + (int)(cos(angle) * laserSize);
      int pointY = laserY + (int)(sin(angle) * laserSize);
      
      if (i == 0) {
        prevX = pointX;
        prevY = pointY;
        p.add(new Point(pointX, pointY, 0, 0, 0)); // Move without drawing
      } else {
        p.add(new Point(pointX, pointY, r, g, b));
        prevX = pointX;
        prevY = pointY;
      }
    }
    
    return numPoints;
  }
  
  void drawOnScreen() {
    // Draw with screen effects
    if (type == 0) fill(255, 50, 50);      // Life - red
    else if (type == 1) fill(50, 255, 50); // Score - green
    else fill(50, 50, 255);                // Invulnerability - blue
    
    noStroke();
    ellipse(x, y, size * 2, size * 2);
    
    // Draw inner symbol
    fill(255);
    if (type == 0) text("+", x, y);        // Life
    else if (type == 1) text("$", x, y);   // Score
    else text("*", x, y);                  // Invulnerability
  }
}
/*

*/
