/**
 * Plugins.pde
 * 
 * Contains the plugin system for the laser game visualizer.
 * This file defines the base plugin classes and manager but doesn't
 * include specific game implementations (which are in their own files).
 */

/**
 * PluginManager - manages plugin loading and execution
 */
class PluginManager {
  private ArrayList<BaseLaserPlugin> plugins;
  private BaseLaserPlugin activePlugin;
  private LaserCallback callback;
  
  public PluginManager(LaserCallback callback) {
    this.callback = callback;
    this.plugins = new ArrayList<BaseLaserPlugin>();
  }
  
  /**
   * Register a plugin with the manager
   */
  public void registerPlugin(BaseLaserPlugin plugin) {
    plugin.setLaserCallback(callback);
    plugins.add(plugin);
    
    // First registered plugin becomes active
    if (activePlugin == null) {
      activePlugin = plugin;
    }
  }
  
  /**
   * Switch to a specific plugin by index
   */
  public boolean switchToPlugin(int index) {
    if (index >= 0 && index < plugins.size()) {
      activePlugin = plugins.get(index);
      return true;
    }
    return false;
  }
  
  /**
   * Switch to a specific plugin by name
   */
  public boolean switchToPlugin(String name) {
    for (BaseLaserPlugin plugin : plugins) {
      if (plugin.getName().equals(name)) {
        activePlugin = plugin;
        return true;
      }
    }
    return false;
  }
  
  /**
   * Get list of plugin names
   */
  public ArrayList<String> getPluginNames() {
    ArrayList<String> names = new ArrayList<String>();
    for (BaseLaserPlugin plugin : plugins) {
      names.add(plugin.getName());
    }
    return names;
  }
  
  /**
   * Get currently active plugin
   */
  public BaseLaserPlugin getActivePlugin() {
    return activePlugin;
  }
  
  /**
   * Draw the active plugin
   */
  public void draw() {
    if (activePlugin != null) {
      activePlugin.draw();
    }
  }
  
  /**
   * Pass keyPressed event to active plugin
   */
  public void keyPressed() {
    if (activePlugin != null) {
      activePlugin.keyPressed();
    }
  }
  
  /**
   * Pass keyReleased event to active plugin
   */
  public void keyReleased() {
    if (activePlugin != null) {
      activePlugin.keyReleased();
    }
  }
  
  /**
   * Pass mousePressed event to active plugin
   */
  public void mousePressed() {
    if (activePlugin != null) {
      activePlugin.mousePressed();
    }
  }
  
  /**
   * Pass mouseDragged event to active plugin
   */
  public void mouseDragged() {
    if (activePlugin != null) {
      activePlugin.mouseDragged();
    }
  }
  
  /**
   * Pass mouseReleased event to active plugin
   */
  public void mouseReleased() {
    if (activePlugin != null) {
      activePlugin.mouseReleased();
    }
  }
}

/**
 * BaseLaserPlugin - base class for laser game plugins
 */
class BaseLaserPlugin {
  protected String name;
  protected String description;
  protected LaserCallback laserCallback;
  protected ArrayList<DACPoint> currentPoints;
  
  /**
   * Constructor
   */
  public BaseLaserPlugin(String name, String description) {
    this.name = name;
    this.description = description;
    this.currentPoints = new ArrayList<DACPoint>();
  }
  
  /**
   * Get plugin name
   */
  public String getName() {
    return name;
  }
  
  /**
   * Get plugin description
   */
  public String getDescription() {
    return description;
  }
  
  /**
   * Set laser callback for sending points
   */
  public void setLaserCallback(LaserCallback callback) {
    this.laserCallback = callback;
  }
  
  /**
   * Draw method - override in subclass
   */
  public void draw() {
    // Override in subclass
  }
  
  /**
   * Key pressed handler - override in subclass
   */
  public void keyPressed() {
    // Override in subclass
  }
  
  /**
   * Key released handler - override in subclass
   */
  public void keyReleased() {
    // Override in subclass
  }
  
  /**
   * Mouse pressed handler - override in subclass
   */
  public void mousePressed() {
    // Override in subclass
  }
  
  /**
   * Mouse dragged handler - override in subclass
   */
  public void mouseDragged() {
    // Override in subclass
  }
  
  /**
   * Mouse released handler - override in subclass
   */
  public void mouseReleased() {
    // Override in subclass
  }
  
  /**
   * Send points to laser
   */
  protected void sendToLaser() {
    if (laserCallback != null) {
      laserCallback.sendPoints(currentPoints);
    }
  }
  
  /**
   * Add a colored point to the buffer
   */
  protected void addPoint(int x, int y, int r, int g, int b) {
    currentPoints.add(new DACPoint(x, y, r, g, b));
  }
  
  /**
   * Add a blanking point (move without drawing)
   */
  protected void addBlankingPoint(int x, int y) {
    currentPoints.add(new DACPoint(x, y, 0, 0, 0));
  }
}

/**
 * Enhanced plugin class that records original points for visualization
 */
class EnhancedLaserPlugin extends BaseLaserPlugin {
  // Cache for original points
  private ArrayList<PVector> originalPoints;
  private ArrayList<RenderPriority> originalPriorities;
  
  public EnhancedLaserPlugin(String name, String description) {
    super(name, description);
    originalPoints = new ArrayList<PVector>();
    originalPriorities = new ArrayList<RenderPriority>();
  }
  
  @Override
  public void draw() {
    // Clear previous points and caches
    currentPoints.clear();
    originalPoints.clear();
    originalPriorities.clear();
    
    // Draw the plugin content
    renderContent();
    
    // Record original points and priorities before sending
    for (DACPoint p : currentPoints) {
      originalPoints.add(new PVector(p.x, p.y));
      originalPriorities.add(getCurrentPriority());
    }
    
    // Send to visualizer callback
    if (laserCallback instanceof LaserVisualizerCallback) {
      ((LaserVisualizerCallback)laserCallback).recordOriginalPoints(originalPoints, originalPriorities);
    }
    
    // Send points to laser
    sendToLaser();
  }
  
  /**
   * Method to render content - override in subclass
   */
  protected void renderContent() {
    // Override in subclass
  }
  
  /**
   * Method to get current priority - override in subclass
   */
  protected RenderPriority getCurrentPriority() {
    // Override in subclass
    return RenderPriority.MEDIUM;
  }
}
