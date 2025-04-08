/**
 * TailBlazer.pde
 * 
 * A laser-compatible arcade game (two-player) where you navigate through obstacles.
 * Controls: MIDI keyboard (low octaves controls Player 1; higher octaves controls Player 2)
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
Player player1, player2;        // Two players for two-player mode
ArrayList<Obstacle> obstacles;
ArrayList<PowerUp> powerUps;
ArrayList<Particle> explosionParticles;
int score = 0;
boolean gameOver = false;
boolean gameStarted = false;
int difficulty = 1;
int framesSinceLastObstacle = 0;
int nextObstacleFrame = 60;

float[] spectrum;
int bands = 16;
float[] sum;
float smoothing = 0.4;
float audioReactivity = 0.0;
float bassEnergy = 0.0;
float midEnergy = 0.0;
float highEnergy = 0.0;

EtherdreamVisualizer visualizer;

void setup() {
  size(800, 600);
  
  minim = new Minim(this);
  try {
    audioInput = minim.getLineIn(Minim.STEREO);
    fft = new FFT(audioInput.bufferSize(), audioInput.sampleRate());
    
    spectrum = new float[bands];
    sum = new float[bands];
  } catch (Exception e) {
    println("Could not initialize audio. Error: " + e.getMessage());
  }
  
  try {
    MidiBus.list();
    if (MidiBus.availableInputs().length > 0) {
      myBus = new MidiBus(this, 1, 0);
    }
  } catch (Exception e) {
    println("Could not initialize MIDI. Error: " + e.getMessage());
    myBus = null;
  }
  
  // Initialize two players, positioning them differently
  player1 = new Player(width/3, height - 100);
  player2 = new Player(2 * width/3, height - 100);
  
  obstacles = new ArrayList<Obstacle>();
  powerUps = new ArrayList<PowerUp>();
  explosionParticles = new ArrayList<Particle>();
  
  visualizer = new EtherdreamVisualizer(this);
}

void draw() {
  background(0);
  
  analyzeAudio();
  
  ArrayList<Point> p = new ArrayList<Point>();
  
  if (!gameStarted) {
    drawTitleScreen(p);
  } else if (gameOver) {
    drawGameOverScreen(p);
  } else {
    updateGame();
    drawGame(p);
  }
    
  DACPoint[] dacPoints = getDACPointsAdjusted(p.toArray(new Point[0]));
  visualizer.setLatestFrame(dacPoints);
  visualizer.draw();
}

void analyzeAudio() {
  if (audioInput != null) {
    fft.forward(audioInput.mix);
    audioReactivity = audioInput.mix.level() * 5;
    
    bassEnergy = 0;
    midEnergy = 0;
    highEnergy = 0;
    
    for (int i = 0; i < bands; i++) {
      float bandEnergy = fft.getBand(i * 4);
      sum[i] += (bandEnergy - sum[i]) * smoothing;
      
      if (i < bands/3) {
        bassEnergy += sum[i];
      } else if (i < 2*bands/3) {
        midEnergy += sum[i];
      } else {
        highEnergy += sum[i];
      }
    }
    
    bassEnergy /= (bands/3);
    midEnergy /= (bands/3);
    highEnergy /= (bands/3);
  }
}

void drawTitleScreen(ArrayList<Point> p) {
  int titleX = 0;
  int titleY = 5000;
  
  addLaserLine(p, titleX - 15000, titleY, titleX - 5000, titleY, 0, on, 0);
  addLaserLine(p, titleX - 10000, titleY, titleX - 10000, titleY - 10000, 0, on, 0);
  
  float pulseAmount = 0.2 + (sin(frameCount * 0.05) * 0.1) + (audioReactivity * 0.2);
  float radius = 25000 * pulseAmount;
  int numPoints = 8;
  
  for (int i = 0; i <= numPoints; i++) {
    float angle = map(i, 0, numPoints, 0, TWO_PI);
    int x = (int)(cos(angle) * radius);
    int y = (int)(sin(angle) * radius);
    
    if (i == 0) {
      p.add(new Point(x, y, 0, 0, 0));
    } else {
      int r = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5 + (bassEnergy * 5))));
      int g = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5 + PI/2 + (midEnergy * 5))));
      int b = (int)(on * (0.5 + 0.5 * sin(frameCount * 0.02 + i * 0.5 + PI + (highEnergy * 5))));
      p.add(new Point(x, y, r, g, b));
    }
  }
}

void drawGameOverScreen(ArrayList<Point> p) {
  int centerX = 0;
  int centerY = 0;
  
  addLaserLine(p, centerX - 15000, centerY - 15000, centerX + 15000, centerY + 15000, on, 0, 0);
  addLaserLine(p, centerX + 15000, centerY - 15000, centerX - 15000, centerY + 15000, on, 0, 0);
  
  int barWidth = 20000;
  int barHeight = 2000;
  int scoreHeight = min(score / 100, 10);
  
  for (int i = 0; i < scoreHeight; i++) {
    int barY = centerY + 15000 - (i * 3000);
    addLaserLine(p, centerX - barWidth/2, barY, centerX + barWidth/2, barY, 0, on, on);
  }
}

void updateGame() {
  // Update both players
  player1.update();
  player2.update();
  
  // Speed based on audio reactivity
  float baseObstacleSpeed = 2.0 + (audioReactivity * 3.0);
  float spawnRateMultiplier = 1.0 + (bassEnergy * 2.0);
  
  framesSinceLastObstacle++;
  if (framesSinceLastObstacle > nextObstacleFrame / spawnRateMultiplier) {
    obstacles.add(new Obstacle(baseObstacleSpeed));
    framesSinceLastObstacle = 0;
    nextObstacleFrame = (int)(60 - (difficulty * 5));
    nextObstacleFrame = max(nextObstacleFrame, 20);
    
    if (random(1) < 0.2 + (midEnergy * 0.3)) {
      powerUps.add(new PowerUp(baseObstacleSpeed * 0.8));
    }
  }
  
  // For each obstacle, check collisions with both players.
  for (int i = obstacles.size() - 1; i >= 0; i--) {
    Obstacle obstacle = obstacles.get(i);
    obstacle.speed = baseObstacleSpeed + (difficulty * 0.3);
    obstacle.update();
    
    boolean collided = false;
    // Check collision with player1
    if (player1.isAlive() && obstacle.checkCollision(player1) && !player1.isInvulnerable()) {
      for (int j = 0; j < 10; j++) {
        explosionParticles.add(new Particle(player1.x, player1.y));
      }
      player1.loseLife();
      player1.setInvulnerable(120);
      collided = true;
    }
    // Check collision with player2
    if (player2.isAlive() && obstacle.checkCollision(player2) && !player2.isInvulnerable()) {
      for (int j = 0; j < 10; j++) {
        explosionParticles.add(new Particle(player2.x, player2.y));
      }
      player2.loseLife();
      player2.setInvulnerable(120);
      collided = true;
    }
    
    if (collided) {
      obstacles.remove(i);
    }
    else if (obstacle.y > height + 50) {
      obstacles.remove(i);
      score += 10 * difficulty;
    }
  }
  
  // Power-up collision checks for each player.
  for (int i = powerUps.size() - 1; i >= 0; i--) {
    PowerUp powerUp = powerUps.get(i);
    powerUp.speed = baseObstacleSpeed * 0.8;
    powerUp.update();
    
    boolean pickedUp = false;
    if (player1.isAlive() && powerUp.checkCollision(player1)) {
      applyPowerUp(player1, powerUp.type);
      pickedUp = true;
    }
    if (player2.isAlive() && powerUp.checkCollision(player2)) {
      applyPowerUp(player2, powerUp.type);
      pickedUp = true;
    }
    
    if (pickedUp || powerUp.y > height + 50) {
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
  
  // Increase difficulty if score threshold reached
  if (score > difficulty * 1000) {
    difficulty++;
  }
  
  // Check for game over: if both players have lost all lives.
  if (!player1.isAlive() && !player2.isAlive()) {
    gameOver = true;
  }
}

// Overloaded function to apply power-ups to a given player
void applyPowerUp(Player player, int type) {
  switch (type) {
    case 0: // Extra life
      player.lives++;
      break;
    case 1: // Score boost
      score += 100 * difficulty;
      break;
    case 2: // Invulnerability
      player.setInvulnerable(300);
      break;
  }
}

void drawGame(ArrayList<Point> p) {
  int remainingLines = 50;
  
  // Draw player1 and subtract its laser lines
  int player1Lines = player1.draw(p);
  remainingLines -= player1Lines;
  
  // Draw player2 and subtract its laser lines
  int player2Lines = player2.draw(p);
  remainingLines -= player2Lines;
  
  int particleLines = 0;
  for (Particle particle : explosionParticles) {
    if (remainingLines > 5) {
      particleLines += particle.draw(p);
      remainingLines -= particleLines;
    }
  }
  
  int powerUpLines = 0;
  for (PowerUp powerUp : powerUps) {
    if (remainingLines > 5) {
      powerUpLines += powerUp.draw(p);
      remainingLines--;
    }
  }
  
  int obstacleLines = 0;
  int obstaclesDrawn = 0;
  for (Obstacle obstacle : obstacles) {
    if (remainingLines > 0 || obstaclesDrawn < 3) {
      obstacleLines += obstacle.draw(p);
      remainingLines--;
      obstaclesDrawn++;
    }
  }
}

void addLaserLine(ArrayList<Point> p, int x1, int y1, int x2, int y2, int r, int g, int b) {
  p.add(new Point(x1, y1, 0, 0, 0));
  p.add(new Point(x2, y2, r, g, b));
}

// --- Keyboard controls remain available for fallback ---
void keyPressed() {
  if (key == ' ') {
    if (!gameStarted) {
      gameStarted = true;
    } else if (gameOver) {
      // Reset the game, reinitialize players and game state
      player1 = new Player(width/3, height - 100);
      player2 = new Player(2 * width/3, height - 100);
      obstacles.clear();
      powerUps.clear();
      explosionParticles.clear();
      score = 0;
      difficulty = 1;
      gameOver = false;
    }
  }
  
  // Control player1 with arrow keys (as fallback)
  if (keyCode == LEFT) {
    player1.setMoving(-1, player1.moveY);
  } else if (keyCode == RIGHT) {
    player1.setMoving(1, player1.moveY);
  } else if (keyCode == UP) {
    player1.setMoving(player1.moveX, -1);
  } else if (keyCode == DOWN) {
    player1.setMoving(player1.moveX, 1);
  }
  
  if (keyCode == 'A') {
    player2.setMoving(-1, player2.moveY);
  } else if (keyCode == 'D') {
    player2.setMoving(1, player2.moveY);
  } else if (keyCode == 'W') {
    player2.setMoving(player2.moveX, -1);
  } else if (keyCode == 'S') {
    player2.setMoving(player2.moveX, 1);
  }
  
  visualizer.keyPressed();
}

void keyReleased() {
  if (keyCode == LEFT || keyCode == RIGHT) {
    player1.setMoving(0, player1.moveY);
  } else if (keyCode == UP || keyCode == DOWN) {
    player1.setMoving(player1.moveX, 0);
  }
  
  if (keyCode == 'A' || keyCode == 'D') {
    player2.setMoving(0, player2.moveY);
  } else if (keyCode == 'W' || keyCode == 'S') {
    player2.setMoving(player2.moveX, 0);
  }
}

// --- MIDI Callbacks ---
// Note: channel 0 controls player1 and channel 1 controls player2.
void noteOn(int channel, int pitch, int velocity) {
  if (myBus != null && velocity > 0) {
    Player target = null;
    //myBus.sendControllerChange(0,pitch,velocity);
    
    System.out.println(pitch);
    System.out.println((pitch / 12) >=5);
    
    if ((pitch / 12) >=5) {
      target = player1;
    } else {
      target = player2;
    }
    
    if (target != null) {
      switch (pitch % 12) {
        case 0: // C - left
          target.setMoving(-1, target.moveY);
          break;
        case 2: // D - right
          target.setMoving(1, target.moveY);
          break;
        case 4: // E - up
          target.setMoving(target.moveX, -1);
          break;
        case 5: // F - down
          target.setMoving(target.moveX, 1);
          break;
        case 7: // G - start/restart
          if (!gameStarted) {
            gameStarted = true;
          } else if (gameOver) {
            player1 = new Player(width/3, height - 100);
            player2 = new Player(2 * width/3, height - 100);
            obstacles.clear();
            powerUps.clear();
            explosionParticles.clear();
            score = 0;
            difficulty = 1;
            gameOver = false;
          }
          break;
      }
    }
  }
}

void noteOff(int channel, int pitch, int velocity) {
  if (myBus != null) {
    Player target = null;
    if (pitch / 12 >= 5) {
      target = player1;
    } else  {
      target = player2;
    }
    
    if (target != null) {
      switch (pitch % 12) {
        case 0: // C - left
        case 2: // D - right
          target.setMoving(0, target.moveY);
          break;
        case 4: // E - up
        case 5: // F - down
          target.setMoving(target.moveX, 0);
          break;
      }
    }
  }
}
  
// --- Modified Player class ---
class Player {
  float x, y;
  float size;
  int moveX, moveY;
  float speed;
  int invulnerableFrames;
  int lives; // Each player has separate lives
  
  // Default constructor not used; use the parameterized one instead.
  Player(float startX, float startY) {
    x = startX;
    y = startY;
    size = 20;
    moveX = 0;
    moveY = 0;
    speed = 5;
    invulnerableFrames = 0;
    lives = 3;
  }
  
  void update() {
    // Movement with audio-responsive speed
    float audioSpeedMod = 1.0 + (audioReactivity * 0.5);
    x += moveX * speed * audioSpeedMod;
    y += moveY * speed * audioSpeedMod;
    
    x = constrain(x, size, width - size);
    y = constrain(y, size, height - size);
    
    if (invulnerableFrames > 0) {
      invulnerableFrames--;
    }
  }
  
  int draw(ArrayList<Point> p) {
    // Blink the player if invulnerable
    if (invulnerableFrames > 0 && frameCount % 10 < 5) {
      return 0;
    }
    
    if (lives == 0) {
      return 0;
    }
    
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    
    // Size modulated by mid frequencies
    int laserSize = (int)map(size * (1.0 + midEnergy), 0, width, 0, mx - mi) / 2;
    
    int tipX = laserX;
    int tipY = laserY - laserSize;
    int leftX = laserX - laserSize;
    int leftY = laserY + laserSize;
    int rightX = laserX + laserSize;
    int rightY = laserY + laserSize;
    
    // Color modulated by audio energy
    int r = (int)(on * (0.5 + bassEnergy));
    int g = (int)(on * (0.5 + midEnergy));
    int b = (int)(on * (0.5 + highEnergy));
    
    addLaserLine(p, tipX, tipY, leftX, leftY, r, g, b);
    addLaserLine(p, leftX, leftY, rightX, rightY, r, g, b);
    addLaserLine(p, rightX, rightY, tipX, tipY, r, g, b);
    
    // Draw player trail modulated by audio energy
    if (moveX != 0 || moveY != 0) {
      int trailLength = (int)(laserSize * 2 * (1.0 + audioReactivity * 3));
      int trailX = laserX - (moveX * trailLength);
      int trailY = laserY + (moveY * trailLength);
      addLaserLine(p, laserX, laserY, trailX, trailY, r/2, g/2, b);
    }
    
    return 4;
  }
  
  void setMoving(int xDir, int yDir) {
    moveX = xDir;
    moveY = yDir;
  }
  
  boolean isInvulnerable() {
    return invulnerableFrames > 0;
  }
  
  void setInvulnerable(int frames) {
    invulnerableFrames = frames;
  }
  
  void loseLife() {
    lives--;
  }
  
  boolean isAlive() {
    return lives > 0;
  }
  
  // Fallback for on-screen visuals if needed
  void drawOnScreen() {
    // Removed screen visuals
  }
}

// --- Unmodified Obstacle, PowerUp, and Particle classes below ---
class Obstacle {
  float x, y;
  float w, h;
  float speed;
  int type;
  float rotation;
  
  Obstacle(float baseSpeed) {
    x = random(width * 0.1, width * 0.9);
    y = -50;
    w = random(30, 100);
    h = random(20, 50);
    speed = baseSpeed + random(0, 2) + (difficulty * 0.5);
    type = int(random(3));
    rotation = random(TWO_PI);
  }
  
  Obstacle() {
    this(3.0);
  }
  
  void update() {
    y += speed;
    rotation += bassEnergy * 0.1;
  }
  
  boolean checkCollision(Player player) {
    return (abs(x - player.x) < (w/2 + player.size/2) &&
            abs(y - player.y) < (h/2 + player.size/2));
  }
  
  int draw(ArrayList<Point> p) {
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserW = (int)map(w, 0, width, 0, mx-mi);
    int laserH = (int)map(h, 0, height, 0, mx-mi);
    
    int r = on;
    int g = (int)(bassEnergy * 10000);  // More bass = more green
    int b = (int)(highEnergy * 10000);  // More high freq = more blue
    
    if (type == 0) {
      int leftX = laserX - laserW/2;
      int rightX = laserX + laserW/2;
      int topY = laserY - laserH/2;
      int bottomY = laserY + laserH/2;
      
      // Apply rotation based on audio
      float rotSpeed = midEnergy * 0.5;
      float cosR = cos(rotation * rotSpeed);
      float sinR = sin(rotation * rotSpeed);
      
      // Calculate rotated points
      int[] rotX = new int[4];
      int[] rotY = new int[4];
      
      rotX[0] = (int)(cosR * (leftX - laserX) - sinR * (topY - laserY) + laserX);
      rotY[0] = (int)(sinR * (leftX - laserX) + cosR * (topY - laserY) + laserY);
      
      rotX[1] = (int)(cosR * (rightX - laserX) - sinR * (topY - laserY) + laserX);
      rotY[1] = (int)(sinR * (rightX - laserX) + cosR * (topY - laserY) + laserY);
      
      rotX[2] = (int)(cosR * (rightX - laserX) - sinR * (bottomY - laserY) + laserX);
      rotY[2] = (int)(sinR * (rightX - laserX) + cosR * (bottomY - laserY) + laserY);
      
      rotX[3] = (int)(cosR * (leftX - laserX) - sinR * (bottomY - laserY) + laserX);
      rotY[3] = (int)(sinR * (leftX - laserX) + cosR * (bottomY - laserY) + laserY);
      
      addLaserLine(p, rotX[0], rotY[0], rotX[1], rotY[1], r, g, b);
      addLaserLine(p, rotX[1], rotY[1], rotX[2], rotY[2], r, g, b);
      addLaserLine(p, rotX[2], rotY[2], rotX[3], rotY[3], r, g, b);
      addLaserLine(p, rotX[3], rotY[3], rotX[0], rotY[0], r, g, b);
      
      return 4;
    } else if (type == 1) {
      int size = (int)(laserW/2 * (1.0 + midEnergy));
      addLaserLine(p, laserX - size, laserY - size, laserX + size, laserY + size, r, g, b);
      addLaserLine(p, laserX - size, laserY + size, laserX + size, laserY - size, r, g, b);
      
      return 2;
    } else {
      int topX = laserX;
      int topY = laserY - (int)(laserH/2 * (1.0 + highEnergy));
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
    // Removed screen visuals
  }
}

class PowerUp {
  float x, y;
  float size;
  float speed;
  int type;
  float rotation;
  
  PowerUp(float baseSpeed) {
    x = random(width * 0.1, width * 0.9);
    y = -30;
    size = 15;
    speed = baseSpeed * 0.8;
    type = int(random(3));
    rotation = 0;
  }
  
  PowerUp() {
    this(3.0);
  }
  
  void update() {
    y += speed;
    rotation += 0.05 + (midEnergy * 0.5);
  }
  
  boolean checkCollision(Player player) {
    return (dist(x, y, player.x, player.y) < (size + player.size/2));
  }
  
  int draw(ArrayList<Point> p) {
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserSize = (int)map(size, 0, width, 0, mx-mi);
    
    // Size affected by high frequencies
    laserSize = (int)(laserSize * (1.0 + highEnergy));
    
    int r = (type == 0) ? on : 0;
    int g = (type == 1) ? on : 0;
    int b = (type == 2) ? on : 0;
    
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
        p.add(new Point(pointX, pointY, 0, 0, 0));
      } else {
        p.add(new Point(pointX, pointY, r, g, b));
        prevX = pointX;
        prevY = pointY;
      }
    }
    
    return numPoints;
  }
  
  void drawOnScreen() {
    // Removed screen visuals
  }
}

class Particle {
  float x, y;
  float vx, vy;
  int lifespan;
  int maxLife;
  float size;
  
  Particle(float startX, float startY) {
    x = startX;
    y = startY;
    vx = random(-3, 3) * (1.0 + audioReactivity);
    vy = random(-3, 3) * (1.0 + audioReactivity);
    maxLife = (int)random(30, 60);
    lifespan = maxLife;
    size = random(2, 8);
  }
  
  void update() {
    x += vx;
    y += vy;
    lifespan--;
  }
  
  int draw(ArrayList<Point> p) {
    int laserX = (int)map(x, 0, width, mi, mx);
    int laserY = (int)map(y, 0, height, mx, mi);
    int laserSize = (int)map(size * (float)lifespan / maxLife, 0, width, 0, mx-mi) / 4;
    
    // Size affected by audio
    laserSize = (int)(laserSize * (1.0 + bassEnergy * 2));
    
    // Particles color is modulated by frequency spectrum
    float lifeFactor = (float)lifespan / maxLife;
    int r = (int)(on * lifeFactor * (bassEnergy * 2));
    int g = (int)(on * lifeFactor * (midEnergy * 2));
    int b = (int)(on * lifeFactor * (highEnergy * 2));
    
    addLaserLine(p, laserX - laserSize, laserY, laserX + laserSize, laserY, r, g, b);
    addLaserLine(p, laserX, laserY - laserSize, laserX, laserY + laserSize, r, g, b);
    
    return 2;
  }
  
  void drawOnScreen() {
    // Removed screen visuals
  }
}
