/**
 * DataManager.pde
 * 
 * Handles data persistence, saving and loading calibration parameters,
 * and exporting settings to different formats.
 */

class DataManager {
  GalvoParameters params;
  final String CONFIG_FILE = "data/galvo_config.json";
  
  DataManager(GalvoParameters params) {
    this.params = params;
    
    // Create data directory if it doesn't exist
    File dataFolder = new File(dataPath(""));
    if (!dataFolder.exists()) {
      dataFolder.mkdir();
    }
  }
  
  void saveConfig() {
    JSONObject config = new JSONObject();
    
    // Save all parameters
    config.setFloat("springConstant", params.springConstant);
    config.setFloat("dampingRatio", params.dampingRatio);
    config.setFloat("naturalFrequency", params.naturalFrequency);
    config.setFloat("pointsPerSecond", params.pointsPerSecond);
    config.setFloat("accelerationLimit", params.accelerationLimit);
    config.setFloat("cornerSmoothing", params.cornerSmoothing);
    config.setFloat("patternSpeed", params.patternSpeed);
    config.setFloat("patternSize", params.patternSize);
    config.setFloat("patternComplexity", params.patternComplexity);
    
    // Save performance metrics
    config.setFloat("avgError", params.avgError);
    config.setFloat("maxError", params.maxError);
    config.setFloat("overshootMetric", params.overshootMetric);
    config.setFloat("cornerMetric", params.cornerMetric);
    
    // Save metadata
    config.setString("calibrationDate", getDateTimeString());
    config.setString("version", "1.0");
    
    // Write to file
    saveJSONObject(config, CONFIG_FILE);
    println("Configuration saved to " + CONFIG_FILE);
  }
  
  void loadConfig() {
    try {
      File configFile = new File(dataPath(CONFIG_FILE));
      if (!configFile.exists()) {
        println("No saved configuration found.");
        return;
      }
      
      JSONObject config = loadJSONObject(CONFIG_FILE);
      
      // Load parameters
      params.springConstant = config.getFloat("springConstant");
      params.dampingRatio = config.getFloat("dampingRatio");
      params.naturalFrequency = config.getFloat("naturalFrequency");
      params.pointsPerSecond = config.getFloat("pointsPerSecond");
      params.accelerationLimit = config.getFloat("accelerationLimit");
      params.cornerSmoothing = config.getFloat("cornerSmoothing");
      
      // Optional parameters (may not exist in older config files)
      if (config.hasKey("patternSpeed")) params.patternSpeed = config.getFloat("patternSpeed");
      if (config.hasKey("patternSize")) params.patternSize = config.getFloat("patternSize");
      if (config.hasKey("patternComplexity")) params.patternComplexity = config.getFloat("patternComplexity");
      
      // Update derived parameters
      params.updateDerivedParams();
      
      println("Configuration loaded from " + CONFIG_FILE);
      
      // Display metadata if available
      if (config.hasKey("calibrationDate")) {
        println("Calibration date: " + config.getString("calibrationDate"));
      }
      
      if (config.hasKey("version")) {
        println("Configuration version: " + config.getString("version"));
      }
    } catch (Exception e) {
      println("Error loading configuration: " + e.getMessage());
    }
  }
  
  String getDateTimeString() {
    return year() + "-" + nf(month(), 2) + "-" + nf(day(), 2) + " " + 
           nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
  }
  
  void exportAsJava(String filename) {
    String code = generateJavaCode();
    
    // Save to file
    String exportPath = dataPath(filename);
    saveStrings(exportPath, new String[] { code });
    println("Exported Java code to " + exportPath);
  }
  
  void exportAsProcessing(String filename) {
    String code = generateProcessingCode();
    
    // Save to file
    String exportPath = dataPath(filename);
    saveStrings(exportPath, new String[] { code });
    println("Exported Processing code to " + exportPath);
  }
  
  String generateJavaCode() {
    StringBuilder code = new StringBuilder();
    
    code.append("/**\n");
    code.append(" * Galvanometer Spring Physics Constants\n");
    code.append(" * Auto-calibrated on " + getDateTimeString() + "\n");
    code.append(" */\n\n");
    
    code.append("public class GalvoConstants {\n");
    code.append("    public static final float SPRING_CONSTANT = " + nf(params.springConstant, 0, 5) + "f;\n");
    code.append("    public static final float DAMPING_RATIO = " + nf(params.dampingRatio, 0, 5) + "f;\n");
    code.append("    public static final float NATURAL_FREQUENCY = " + nf(params.naturalFrequency, 0, 2) + "f;\n");
    code.append("    public static final float POINTS_PER_SECOND = " + nf(params.pointsPerSecond, 0, 0) + "f;\n");
    code.append("    public static final float ANGULAR_FREQUENCY = " + nf(params.angularFrequency, 0, 5) + "f;\n");
    code.append("    public static final float ACCELERATION_LIMIT = " + nf(params.accelerationLimit, 0, 5) + "f;\n");
    code.append("    public static final float CORNER_SMOOTHING = " + nf(params.cornerSmoothing, 0, 5) + "f;\n");
    code.append("}\n");
    
    return code.toString();
  }
  
  String generateProcessingCode() {
    StringBuilder code = new StringBuilder();
    
    code.append("/**\n");
    code.append(" * Galvanometer Spring Physics Constants\n");
    code.append(" * Auto-calibrated on " + getDateTimeString() + "\n");
    code.append(" */\n\n");
    
    code.append("// Galvo physics constants\n");
    code.append("final float SPRING_CONSTANT = " + nf(params.springConstant, 0, 5) + "f;\n");
    code.append("final float DAMPING_RATIO = " + nf(params.dampingRatio, 0, 5) + "f;\n");
    code.append("final float NATURAL_FREQUENCY = " + nf(params.naturalFrequency, 0, 2) + "f;\n");
    code.append("final float POINTS_PER_SECOND = " + nf(params.pointsPerSecond, 0, 0) + "f;\n");
    code.append("final float ANGULAR_FREQUENCY = " + nf(params.angularFrequency, 0, 5) + "f;\n");
    code.append("final float ACCELERATION_LIMIT = " + nf(params.accelerationLimit, 0, 5) + "f;\n");
    code.append("final float CORNER_SMOOTHING = " + nf(params.cornerSmoothing, 0, 5) + "f;\n\n");
    
    // Add example of usage
    code.append("/**\n");
    code.append(" * Example spring physics implementation:\n");
    code.append(" */\n");
    code.append("PVector applyGalvoPhysics(PVector lastPoint, PVector targetPoint, float timeStep) {\n");
    code.append("  // Calculate distance to target\n");
    code.append("  float dx = targetPoint.x - lastPoint.x;\n");
    code.append("  float dy = targetPoint.y - lastPoint.y;\n");
    code.append("  \n");
    code.append("  // Apply spring physics\n");
    code.append("  float springFactor;\n");
    code.append("  \n");
    code.append("  if (DAMPING_RATIO < 1.0) {\n");
    code.append("    // Underdamped case (springy)\n");
    code.append("    float dampedFreq = ANGULAR_FREQUENCY * sqrt(1 - DAMPING_RATIO * DAMPING_RATIO);\n");
    code.append("    float decay = exp(-DAMPING_RATIO * ANGULAR_FREQUENCY * timeStep);\n");
    code.append("    \n");
    code.append("    springFactor = 1 - decay * (\n");
    code.append("      cos(dampedFreq * timeStep) +\n");
    code.append("      (DAMPING_RATIO * ANGULAR_FREQUENCY / dampedFreq) * sin(dampedFreq * timeStep)\n");
    code.append("    );\n");
    code.append("  } else {\n");
    code.append("    // Critically damped or overdamped\n");
    code.append("    float decay = exp(-ANGULAR_FREQUENCY * timeStep);\n");
    code.append("    springFactor = 1 - decay * (1 + ANGULAR_FREQUENCY * timeStep);\n");
    code.append("  }\n");
    code.append("  \n");
    code.append("  // Calculate new position based on spring factor\n");
    code.append("  PVector newPos = new PVector();\n");
    code.append("  newPos.x = lastPoint.x + dx * springFactor;\n");
    code.append("  newPos.y = lastPoint.y + dy * springFactor;\n");
    code.append("  \n");
    code.append("  return newPos;\n");
    code.append("}\n");
    
    return code.toString();
  }
  
  void exportCalibrationReport(String filename) {
    StringBuilder report = new StringBuilder();
    
    report.append("# Galvanometer Calibration Report\n\n");
    report.append("Generated: " + getDateTimeString() + "\n\n");
    
    report.append("## Calibrated Parameters\n\n");
    report.append("| Parameter | Value |\n");
    report.append("|-----------|-------|\n");
    report.append("| Spring Constant | " + nf(params.springConstant, 0, 5) + " |\n");
    report.append("| Damping Ratio | " + nf(params.dampingRatio, 0, 5) + " |\n");
    report.append("| Natural Frequency | " + nf(params.naturalFrequency, 0, 2) + " Hz |\n");
    report.append("| Points Per Second | " + nf(params.pointsPerSecond, 0, 0) + " |\n");
    report.append("| Acceleration Limit | " + nf(params.accelerationLimit, 0, 5) + " |\n");
    report.append("| Corner Smoothing | " + nf(params.cornerSmoothing, 0, 5) + " |\n\n");
    
    report.append("## Performance Metrics\n\n");
    report.append("| Metric | Value |\n");
    report.append("|--------|-------|\n");
    report.append("| Average Error | " + nf(params.avgError, 0, 2) + " px |\n");
    report.append("| Maximum Error | " + nf(params.maxError, 0, 2) + " px |\n");
    report.append("| Overshoot | " + nf(params.overshootMetric * 100, 0, 2) + "% |\n");
    report.append("| Corner Handling | " + nf((1 - params.cornerMetric) * 100, 0, 2) + "% |\n\n");
    
    // Overall score calculation
    float overallScore = (1 - params.avgError / 100) * 0.4 + 
                        (1 - params.maxError / 200) * 0.2 + 
                        (1 - params.overshootMetric) * 0.2 + 
                        (1 - params.cornerMetric) * 0.2;
    
    overallScore = constrain(overallScore, 0, 1) * 100;
    
    report.append("**Overall Score:** " + nf(overallScore, 0, 1) + "%\n\n");
    
    report.append("## Notes\n\n");
    report.append("- The spring constant represents the stiffness of the galvanometer's response.\n");
    report.append("- Damping ratio controls oscillation suppression (1.0 is critical damping).\n");
    report.append("- Natural frequency is the resonant frequency of the galvanometer system.\n");
    report.append("- Corner handling represents how well the system manages sharp turns.\n");
    
    // Save to file
    String exportPath = dataPath(filename);
    saveStrings(exportPath, new String[] { report.toString() });
    println("Exported calibration report to " + exportPath);
  }
}
