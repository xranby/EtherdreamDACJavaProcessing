/**
 * LaserOutputViz.pde
 * 
 * Visualization for realistic laser output with bloom effects.
 */

/**
 * Draw realistic laser output visualization with bloom effects
 */
void drawLaserOutputVisualization() {
  Rectangle area = currentMode == MODE_ALL ? laserOutputArea : new Rectangle(0, 0, width, height - (showControlPanel ? 150 : 0));
  
  // Draw border and background
  fill(10);
  stroke(30);
  rect(area.x, area.y, area.width, area.height);
  
  // Add header
  fill(255);
  textAlign(CENTER);
  textSize(14);
  text("Realistic Laser Output", area.x + area.width/2, area.y + 20);
  
  // Get physics points to draw laser lines
  ArrayList<PVector> physicsPoints = visualizerCallback.getPhysicsPoints();
  ArrayList<Integer> colors = visualizerCallback.getEnhancedColors();
  
  if (physicsPoints != null && physicsPoints.size() > 0 && colors != null) {
    // Begin drawing to off-screen buffer
    laserOutputBuffer.beginDraw();
    laserOutputBuffer.background(0);
    
    // Transform to screen coordinates
    ArrayList<PVector> screenPoints = transformPointsToScreen(physicsPoints, area);
    
    // Draw laser beams with glow effect
    if (laserOutputQuality >= 1) {
      // Higher quality beam rendering with anti-aliasing and beam width
      laserOutputBuffer.strokeCap(ROUND);
      laserOutputBuffer.strokeWeight(beamWidth);
      laserOutputBuffer.noFill();
      
      // First draw laser beams with full intensity
      for (int i = 1; i < screenPoints.size(); i++) {
        PVector p = screenPoints.get(i);
        PVector prev = screenPoints.get(i-1);
        
        // Determine color based on RGB values
        color beamColor = color(255);
        
        if ((i-1)*3+2 < colors.size()) {
          int r = colors.get((i-1)*3);
          int g = colors.get((i-1)*3+1);
          int b = colors.get((i-1)*3+2);
          
          // Map DAC color values (0-65535) to screen colors (0-255)
          r = (int)(map(r, 0, 65535, 0, 255) * laserBrightness);
          g = (int)(map(g, 0, 65535, 0, 255) * laserBrightness);
          b = (int)(map(b, 0, 65535, 0, 255) * laserBrightness);
          
          beamColor = color(r, g, b);
        }
        
        // Skip blanking moves
        if (brightness(beamColor) < 5) continue;
        
        // Draw the beam
        laserOutputBuffer.stroke(beamColor);
        laserOutputBuffer.line(prev.x, prev.y, p.x, p.y);
      }
    } else {
      // Fast, lower quality rendering
      laserOutputBuffer.strokeWeight(beamWidth);
      
      for (int i = 1; i < screenPoints.size(); i++) {
        PVector p = screenPoints.get(i);
        PVector prev = screenPoints.get(i-1);
        
        // Determine color
        color beamColor = color(255);
        
        if ((i-1)*3+2 < colors.size()) {
          int r = colors.get((i-1)*3);
          int g = colors.get((i-1)*3+1);
          int b = colors.get((i-1)*3+2);
          
          // Map DAC color values
          r = (int)(map(r, 0, 65535, 0, 255) * laserBrightness);
          g = (int)(map(g, 0, 65535, 0, 255) * laserBrightness);
          b = (int)(map(b, 0, 65535, 0, 255) * laserBrightness);
          
          beamColor = color(r, g, b);
        }
        
        // Skip blanking moves
        if (brightness(beamColor) < 5) continue;
        
        laserOutputBuffer.stroke(beamColor);
        laserOutputBuffer.line(prev.x, prev.y, p.x, p.y);
      }
    }
    
    // If using shader-based bloom
    if (bloomShader != null && laserOutputQuality == 2) {
      // Apply bloom shader
      bloomShader.set("bloomStrength", bloomStrength / 50.0);
      bloomShader.set("bloomSize", bloomSize / 10.0);
      laserOutputBuffer.filter(bloomShader);
    } else {
      // Software-based bloom fallback
      applyBloomEffect(laserOutputBuffer, bloomStrength, bloomSize);
    }
    
    // Add atmospheric scattering if enabled
    if (atmosphericScatter) {
      applyAtmosphericEffect(laserOutputBuffer);
    }
    
    laserOutputBuffer.endDraw();
    
    // Display the resulting buffer
    image(laserOutputBuffer, area.x, area.y, area.width, area.height);
  } else {
    // If no points, just show blank area
    fill(0);
    rect(area.x, area.y, area.width, area.height);
    
    fill(150);
    textAlign(CENTER);
    text("No laser output data available", area.x + area.width/2, area.y + area.height/2);
  }
}

/**
 * Apply software-based bloom effect to a PGraphics buffer
 */
void applyBloomEffect(PGraphics buffer, int strength, int size) {
  // Fast gaussian blur approximation
  PGraphics blurBuffer = createGraphics(buffer.width, buffer.height, P2D);
  blurBuffer.beginDraw();
  blurBuffer.background(0);
  
  // Copy original to blur buffer with some smoothing
  blurBuffer.image(buffer, 0, 0);
  
  // Multiple blur passes for larger bloom size
  int passes = constrain(size, 1, 5);
  
  for (int pass = 0; pass < passes; pass++) {
    // Horizontal blur
    blurBuffer.filter(BLUR, 1);
  }
  
  // Adjust brightness of blur based on strength
  float blurAmount = map(strength, 0, 50, 0.2, 0.8);
  blurBuffer.filter(THRESHOLD, 0.1); // Remove dark areas
  blurBuffer.filter(DILATE);         // Expand bright areas
  blurBuffer.filter(BLUR, 2);        // Final blur
  
  // Blend blur back onto original
  blurBuffer.blendMode(ADD);
  blurBuffer.tint(255, 255 * blurAmount);
  blurBuffer.image(buffer, 0, 0);
  blurBuffer.endDraw();
  
  // Copy result back to original buffer
  buffer.beginDraw();
  buffer.image(blurBuffer, 0, 0);
  buffer.endDraw();
}

/**
 * Apply atmospheric scattering effect
 */
void applyAtmosphericEffect(PGraphics buffer) {
  // Add some haze/fog to simulate dust particles in the air
  buffer.beginDraw();
  buffer.blendMode(ADD);
  
  // Create a subtle hazy glow
  buffer.noStroke();
  buffer.fill(20, 20, 30, 5);
  
  // Add subtle random haze spots
  for (int i = 0; i < 10; i++) {
    float x = random(buffer.width);
    float y = random(buffer.height);
    float size = random(50, 200);
    buffer.ellipse(x, y, size, size);
  }
  
  buffer.blendMode(BLEND);
  buffer.endDraw();
}
