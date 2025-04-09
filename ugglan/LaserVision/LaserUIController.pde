/**
 * LaserUIController.pde
 * 
 * UI elements for controlling the laser visualizer settings
 * Provides buttons and sliders for adjusting visualization parameters
 */

    /**
   * The SliderCallback interface is used for slider value change notifications
   */
  interface SliderCallback {
    void onValueChanged(float value);
  }
  // Define the UIElement interface internally
  interface UIElement {
    void draw();
    void mousePressed();
    void mouseDragged();
    void mouseReleased();
  }
class LaserUIController {
  
  
  // UI elements
  private boolean showUI = true;
  private ArrayList<UIElement> uiElements = new ArrayList<UIElement>();
  
  // Reference to the visualizer
  private LaserVisualizer visualizer;
  
  /**
   * Constructor
   */
  public LaserUIController(LaserVisualizer visualizer) {
    this.visualizer = visualizer;
    initializeUI();
  }
  
  /**
   * Initialize UI elements
   */
  private void initializeUI() {
    int startY = 20;
    int spacing = 35;
    int currentY = startY;
    
    // Toggle buttons
    uiElements.add(new ToggleButton("Show Points", 20, currentY, true, 
      () -> visualizer.togglePoints()));
    currentY += spacing;
    
    uiElements.add(new ToggleButton("Show Beam", 20, currentY, true, 
      () -> visualizer.toggleBeam()));
    currentY += spacing;
    
    uiElements.add(new ToggleButton("Velocity Colors", 20, currentY, true, 
      () -> visualizer.toggleVelocityColors()));
    currentY += spacing;
    
    uiElements.add(new ToggleButton("Motion Blur", 20, currentY, true, 
      () -> visualizer.toggleMotionBlur()));
    currentY += spacing;
    
    // Sliders
    currentY += 10;
    uiElements.add(new Slider("Point Size", 20, currentY, 150, 1, 10, 3, 
      (value) -> visualizer.setPointSize((int)value)));
    currentY += spacing;
    
    uiElements.add(new Slider("Trail Length", 20, currentY, 150, 5, 50, 20, 
      (value) -> visualizer.setBlurTrailLength((int)value)));
    currentY += spacing;
    
    uiElements.add(new Slider("Velocity Scale", 20, currentY, 150, 0.1, 2.0, 0.5, 
      (value) -> visualizer.setVelocityScale(value)));
    currentY += spacing;
    
    // Reset button
    uiElements.add(new Button("Reset", 20, currentY, 80, 25, 
      () -> visualizer.reset()));
  }
  
  /**
   * Draw the UI
   */
  public void draw() {
    if (!showUI) return;
    
    // Draw semi-transparent background for UI
    fill(0, 0, 0, 180);
    noStroke();
    rect(10, 10, 180, 280, 10);
    
    // Draw UI elements
    for (UIElement element : uiElements) {
      element.draw();
    }
  }
  
  /**
   * Handle mouse interaction
   */
  public void mousePressed() {
    if (!showUI) return;
    
    for (UIElement element : uiElements) {
      element.mousePressed();
    }
  }
  
  /**
   * Handle mouse drag
   */
  public void mouseDragged() {
    if (!showUI) return;
    
    for (UIElement element : uiElements) {
      element.mouseDragged();
    }
  }
  
  /**
   * Handle mouse release
   */
  public void mouseReleased() {
    if (!showUI) return;
    
    for (UIElement element : uiElements) {
      element.mouseReleased();
    }
  }
  
  /**
   * Toggle UI visibility
   */
  public void toggleUI() {
    showUI = !showUI;
  }
  

  
  /**
   * Button UI element
   */
  class Button implements UIElement {
    String label;
    float x, y, w, h;
    boolean isHovering = false;
    Runnable action;
    
    Button(String label, float x, float y, float w, float h, Runnable action) {
      this.label = label;
      this.x = x;
      this.y = y;
      this.w = w;
      this.h = h;
      this.action = action;
    }
    
    public void draw() {
      // Check if hovering
      isHovering = mouseX >= x && mouseX <= x + w && 
                   mouseY >= y && mouseY <= y + h;
      
      // Draw button
      if (isHovering) {
        fill(100, 100, 255);
      } else {
        fill(60, 60, 180);
      }
      noStroke();
      rect(x, y, w, h, 5);
      
      // Draw label
      fill(255);
      textAlign(CENTER, CENTER);
      text(label, x + w/2, y + h/2);
    }
    
    public void mousePressed() {
      if (isHovering) {
        action.run();
      }
    }
    
    public void mouseDragged() { }
    
    public void mouseReleased() { }
  }
  
  /**
   * Toggle button UI element
   */
  class ToggleButton implements UIElement {
    String label;
    float x, y;
    boolean isChecked;
    boolean isHovering = false;
    Runnable action;
    
    ToggleButton(String label, float x, float y, boolean initialState, Runnable action) {
      this.label = label;
      this.x = x;
      this.y = y;
      this.isChecked = initialState;
      this.action = action;
    }
    
    public void draw() {
      // Check if hovering
      isHovering = mouseX >= x && mouseX <= x + 20 && 
                   mouseY >= y && mouseY <= y + 20;
      
      // Draw checkbox
      if (isHovering) {
        stroke(100, 100, 255);
      } else {
        stroke(150);
      }
      strokeWeight(2);
      fill(40);
      rect(x, y, 20, 20, 3);
      
      // Draw check if checked
      if (isChecked) {
        fill(100, 255, 100);
        noStroke();
        rect(x + 4, y + 4, 12, 12, 2);
      }
      
      // Draw label
      fill(255);
      textAlign(LEFT, CENTER);
      text(label, x + 30, y + 10);
    }
    
    public void mousePressed() {
      if (isHovering) {
        isChecked = !isChecked;
        action.run();
      }
    }
    
    public void mouseDragged() { }
    
    public void mouseReleased() { }
  }
  
  /**
   * Slider UI element
   */
  class Slider implements UIElement {
    String label;
    float x, y, w;
    float minValue, maxValue, value;
    boolean isDragging = false;
    SliderCallback callback;
    
    Slider(String label, float x, float y, float w, 
           float minValue, float maxValue, float initialValue, 
           SliderCallback callback) {
      this.label = label;
      this.x = x;
      this.y = y;
      this.w = w;
      this.minValue = minValue;
      this.maxValue = maxValue;
      this.value = initialValue;
      this.callback = callback;
    }
    
    public void draw() {
      // Draw label
      fill(255);
      textAlign(LEFT, BOTTOM);
      text(label + ": " + nf(value, 0, 1), x, y);
      
      // Draw track
      stroke(150);
      strokeWeight(2);
      line(x, y + 10, x + w, y + 10);
      
      // Draw handle
      float handleX = map(value, minValue, maxValue, x, x + w);
      if (isDragging) {
        fill(100, 255, 100);
      } else {
        fill(100, 180, 255);
      }
      stroke(255);
      strokeWeight(1);
      ellipse(handleX, y + 10, 15, 15);
    }
    
    public void mousePressed() {
      float handleX = map(value, minValue, maxValue, x, x + w);
      if (dist(mouseX, mouseY, handleX, y + 10) < 10) {
        isDragging = true;
      }
    }
    
    public void mouseDragged() {
      if (isDragging) {
        float newValue = map(constrain(mouseX, x, x + w), x, x + w, minValue, maxValue);
        if (newValue != value) {
          value = newValue;
          callback.onValueChanged(value);
        }
      }
    }
    
    public void mouseReleased() {
      isDragging = false;
    }
  }
  
}
