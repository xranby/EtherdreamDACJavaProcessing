/**
 * PluginInterface.pde
 * 
 * Defines a plugin architecture that allows different laser applications
 * to be integrated with the galvanometer calibration system.
 */

/**
 * Base interface for all plugins
 */
interface LaserPlugin {
  // Basic lifecycle methods
  void setup();        // Called when plugin is first loaded
  void draw();         // Called every frame
  void cleanup();      // Called when exiting plugin
  
  // Event handling
  void keyPressed();   // Called on key press
  void keyReleased();  // Called on key release
  void mousePressed(); // Called on mouse press
  void mouseDragged(); // Called on mouse drag
  void mouseReleased(); // Called on mouse release
  
  // Plugin info
  String getName();       // Get plugin name
  String getDescription(); // Get plugin description
  
  // Laser control
  ArrayList<DACPoint> getPoints(); // Get current laser points
  void setLaserCallback(LaserCallback callback); // Set callback for sending points
}

/**
 * Callback interface for allowing plugins to send points to the laser
 */
interface LaserCallback {
  // Send points to the laser
  void sendPoints(ArrayList<DACPoint> points);
  
  // Get current DAC status
  boolean isLaserConnected();
  
  // Get DAC capabilities
  int getMaxPoints();
  int getPointRate();
}

/**
 * Plugin manager - manages loading and switching between plugins
 */
class PluginManager {
  ArrayList<LaserPlugin> plugins;
  LaserPlugin activePlugin;
  int activePluginIndex = -1;
  
  LaserCallback laserCallback;
  
  PluginManager(LaserCallback callback) {
    plugins = new ArrayList<LaserPlugin>();
    laserCallback = callback;
  }
  
  void registerPlugin(LaserPlugin plugin) {
    plugins.add(plugin);
    plugin.setLaserCallback(laserCallback);
    
    // If this is the first plugin, activate it
    if (plugins.size() == 1) {
      activatePlugin(0);
    }
    
    println("Registered plugin: " + plugin.getName());
  }
  
  void activatePlugin(int index) {
    if (index < 0 || index >= plugins.size()) {
      println("Invalid plugin index: " + index);
      return;
    }
    
    // Clean up current plugin if active
    if (activePlugin != null) {
      activePlugin.cleanup();
    }
    
    // Switch to new plugin
    activePluginIndex = index;
    activePlugin = plugins.get(index);
    activePlugin.setup();
    
    println("Activated plugin: " + activePlugin.getName());
  }
  
  void nextPlugin() {
    int nextIndex = (activePluginIndex + 1) % plugins.size();
    activatePlugin(nextIndex);
  }
  
  void prevPlugin() {
    int prevIndex = (activePluginIndex - 1 + plugins.size()) % plugins.size();
    activatePlugin(prevIndex);
  }
  
  LaserPlugin getActivePlugin() {
    return activePlugin;
  }
  
  int getPluginCount() {
    return plugins.size();
  }
  
  String[] getPluginNames() {
    String[] names = new String[plugins.size()];
    for (int i = 0; i < plugins.size(); i++) {
      names[i] = plugins.get(i).getName();
    }
    return names;
  }
  
  // Forward event handling to active plugin
  void draw() {
    if (activePlugin != null) {
      activePlugin.draw();
    }
  }
  
  void keyPressed() {
    if (activePlugin != null) {
      activePlugin.keyPressed();
    }
  }
  
  void keyReleased() {
    if (activePlugin != null) {
      activePlugin.keyReleased();
    }
  }
  
  void mousePressed() {
    if (activePlugin != null) {
      activePlugin.mousePressed();
    }
  }
  
  void mouseDragged() {
    if (activePlugin != null) {
      activePlugin.mouseDragged();
    }
  }
  
  void mouseReleased() {
    if (activePlugin != null) {
      activePlugin.mouseReleased();
    }
  }
  
  void cleanup() {
    if (activePlugin != null) {
      activePlugin.cleanup();
    }
  }
}
