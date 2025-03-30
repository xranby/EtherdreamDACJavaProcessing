/**
 * SpelIde.pde
 * 
 * Example game plugin implementation - Simple platformer game
 * for laser projection systems. This is a simplified version
 * just to demonstrate the visualization capabilities.
 */

/**
 * SpelidePlugin for testing
 * This is a simplified version to demonstrate the visualization
 * You would replace this with your actual game logic
 */
class SpelidePlugin extends EnhancedLaserPlugin {
  // Current priority being used
  private RenderPriority currentPriority = RenderPriority.MEDIUM;
  
  // Game elements
  private float playerX, playerY;
  private ArrayList<PVector> platforms;
  private float worldSpeed = 50.0f;
  private int frameCounter = 0;
  
  // Player state
  private float playerVelocityY = 0;
  private boolean isJumping = false;
  private static final float GRAVITY = 9.8f;
  private static final float JUMP_FORCE = 200.0f;
  
  // Game state
  private int score = 0;
  private boolean gameOver = false;
  
  /**
   * Constructor - initialize game elements
   */
  public SpelidePlugin() {
    super("Spelide", "Spelide game with visualization enhancements");
    
    // Initialize some platforms for demonstration
    platforms = new ArrayList<PVector>();
    platforms.add(new PVector(-20000, -10000, 10000)); // x, y, width
    platforms.add(new PVector(-5000, 0, 15000));
    platforms.add(new PVector(10000, 5000, 12000));
    
    // Initial player position
    playerX = -15000;
    playerY = 5000;
    
    // Reset game state
    resetGame();
  }
  
  /**
   * Reset the game state
   */
  private void resetGame() {
    playerX = -15000;
    playerY = 5000;
    playerVelocityY = 0;
    isJumping = false;
    score = 0;
    gameOver = false;
    
    // Reset platform positions
    setupPlatforms();
  }
  
  /**
   * Set up initial platform configuration
   */
  private void setupPlatforms() {
    platforms.clear();
    
    // Add ground platform
    platforms.add(new PVector(-32767, 10000, 65534));
    
    // Add some floating platforms at different heights
    for (int i = 0; i < 10; i++) {
      float x = random(-20000, 20000);
      float y = random(-15000, 5000);
      float width = random(3000, 8000);
      platforms.add(new PVector(x, y, width));
    }
  }
  
  @Override
  protected void renderContent() {
    frameCounter++;
    
    if (!gameOver) {
      // Update game state
      updatePlayer();
      updatePlatforms();
      checkCollisions();
      
      // Increase score
      if (frameCounter % 10 == 0) {
        score++;
      }
    }
    
    // Draw game elements based on priority
    // Set priority to CRITICAL for player
    currentPriority = RenderPriority.CRITICAL;
    drawPlayer();
    
    // Set priority to HIGH for game elements
    currentPriority = RenderPriority.HIGH;
    drawPlatforms();
    
    // Set priority to MEDIUM for score
    currentPriority = RenderPriority.MEDIUM;
    drawScore();
    
    // Set priority to LOW for background
    currentPriority = RenderPriority.LOW;
    drawBackground();
  }
  
  /**
   * Update player position and state
   */
  private void updatePlayer() {
    // Apply gravity
    playerVelocityY += GRAVITY;
    
    // Update player position
    playerY += playerVelocityY;
    
    // Add some horizontal movement based on sine wave for demo
    playerX += sin(frameCounter * 0.05) * 100;
    
    // Check if player is out of bounds (fell off the bottom)
    if (playerY > 15000) {
      gameOver = true;
    }
  }
  
  /**
   * Update platform positions (scrolling effect)
   */
  private void updatePlatforms() {
    // Move platforms to the left (world scrolling)
    for (PVector platform : platforms) {
      platform.x -= worldSpeed;
      
      // If platform moves off screen, reset it to the right
      if (platform.x + platform.z < -32767) {
        platform.x = 32767;
        platform.y = random(-15000, 8000);
        platform.z = random(3000, 8000);
      }
    }
  }
  
  /**
   * Check for collisions between player and platforms
   */
  private void checkCollisions() {
    boolean onPlatform = false;
    
    // Check each platform
    for (PVector platform : platforms) {
      // Check if player is above the platform and within its width
      if (playerX >= platform.x && playerX <= platform.x + platform.z) {
        // Check if player is landing on the platform
        if (playerY + 1000 >= platform.y && playerY + 1000 <= platform.y + 200 && playerVelocityY > 0) {
          playerY = platform.y - 1000;
          playerVelocityY = 0;
          isJumping = false;
          onPlatform = true;
        }
      }
    }
    
    // Apply auto-jump for demo purposes (more interesting movement)
    if (onPlatform && frameCounter % 50 == 0) {
      playerVelocityY = -JUMP_FORCE;
      isJumping = true;
    }
  }
  
  @Override
  protected RenderPriority getCurrentPriority() {
    return currentPriority;
  }
  
  @Override
  public void keyPressed() {
    // Handle key input
    if (key == ' ' && !isJumping) {
      // Jump when space is pressed
      playerVelocityY = -JUMP_FORCE;
      isJumping = true;
    } else if (key == 'r' || key == 'R') {
      // Reset game when R is pressed
      resetGame();
    }
  }
  
  /**
   * Draw the player character
   */
  private void drawPlayer() {
    // Draw player at current position
    // Simple triangle for player
    addBlankingPoint((int)playerX - 1000, (int)playerY - 1000);
    addPoint((int)playerX, (int)playerY + 1000, 0, 65535, 65535);
    addPoint((int)playerX + 1000, (int)playerY - 1000, 0, 65535, 65535);
    addPoint((int)playerX - 1000, (int)playerY - 1000, 0, 65535, 65535);
    
    // Add eyes if not jumping (just for fun)
    if (!isJumping) {
      // Left eye
      addBlankingPoint((int)playerX - 400, (int)playerY - 300);
      addPoint((int)playerX - 200, (int)playerY - 300, 65535, 0, 0);
      
      // Right eye
      addBlankingPoint((int)playerX + 200, (int)playerY - 300);
      addPoint((int)playerX + 400, (int)playerY - 300, 65535, 0, 0);
    }
  }
  
  /**
   * Draw the platforms
   */
  private void drawPlatforms() {
    // Draw platforms
    for (PVector platform : platforms) {
      addBlankingPoint((int)platform.x, (int)platform.y);
      addPoint((int)(platform.x + platform.z), (int)platform.y, 65535, 32767, 0);
    }
  }
  
  /**
   * Draw the score display
   */
  private void drawScore() {
    // Position for score display
    int scoreX = -30000;
    int scoreY = -25000;
    
    // Draw score text - simple 7-segment style
    // Just showing a simplified version with the number
    addBlankingPoint(scoreX, scoreY);
    
    // Convert score to string and draw each digit
    String scoreText = String.valueOf(score);
    int digitWidth = 2000;
    
    for (int i = 0; i < scoreText.length(); i++) {
      int digit = Character.getNumericValue(scoreText.charAt(i));
      int digitX = scoreX + i * digitWidth;
      
      // Draw a simple representation of the digit
      drawDigit(digit, digitX, scoreY);
    }
  }
  
  /**
   * Draw a digit in 7-segment display style
   */
  private void drawDigit(int digit, int x, int y) {
    // Simple representation of digits using lines
    switch (digit) {
      case 0:
        // Draw 0
        addBlankingPoint(x, y);
        addPoint(x + 1000, y, 0, 65535, 0);
        addPoint(x + 1000, y + 2000, 0, 65535, 0);
        addPoint(x, y + 2000, 0, 65535, 0);
        addPoint(x, y, 0, 65535, 0);
        break;
      case 1:
        // Draw 1
        addBlankingPoint(x + 1000, y);
        addPoint(x + 1000, y + 2000, 0, 65535, 0);
        break;
      // Additional digits can be implemented with more case statements
      default:
        // Simple fallback for other digits
        addBlankingPoint(x, y);
        addPoint(x + 1000, y, 0, 65535, 0);
        addPoint(x + 1000, y + 2000, 0, 65535, 0);
        addPoint(x, y + 2000, 0, 65535, 0);
        addPoint(x, y, 0, 65535, 0);
    }
  }
  
  /**
   * Draw the background elements
   */
  private void drawBackground() {
    // Draw some stars in the background
    for (int i = 0; i < 5; i++) {
      float x = sin(frameCounter * 0.01 + i) * 25000;
      float y = cos(frameCounter * 0.02 + i) * 20000;
      
      addBlankingPoint((int)x, (int)y);
      addPoint((int)x + 500, (int)y, 16384, 16384, 32767);
    }
    
    // Draw death ray on right side (game boundary)
    addBlankingPoint(28000, -32767);
    addPoint(28000, 32767, 65535, 0, 0);
    
    // If game over, show game over text
    if (gameOver) {
      // "GAME OVER" text at center
      drawGameOverText();
    }
  }
  
  /**
   * Draw game over text
   */
  private void drawGameOverText() {
    // Center position for game over text
    int textX = -15000;
    int textY = -5000;
    
    // Simplified "GAME OVER" text
    // Just outline text for demonstration
    addBlankingPoint(textX, textY);
    
    // Draw "G"
    addPoint(textX - 2000, textY, 65535, 0, 0);
    addPoint(textX, textY - 2000, 65535, 0, 0);
    addPoint(textX + 2000, textY - 1000, 65535, 0, 0);
    addPoint(textX, textY + 2000, 65535, 0, 0);
    addPoint(textX - 2000, textY, 65535, 0, 0);
    
    // Move to "O"
    addBlankingPoint(textX + 4000, textY - 2000);
    
    // Draw "O"
    addPoint(textX + 6000, textY - 2000, 65535, 0, 0);
    addPoint(textX + 6000, textY + 2000, 65535, 0, 0);
    addPoint(textX + 4000, textY + 2000, 65535, 0, 0);
    addPoint(textX + 4000, textY - 2000, 65535, 0, 0);
  }
}
