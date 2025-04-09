/**
 * SimulationRecorder.pde
 * 
 * Component for recording and saving laser simulation data for later analysis
 * Records point data, movements, and timing for debugging or visualization
 */

class SimulationRecorder {
  // Recording parameters
  private boolean isRecording = false;
  private int maxFrames = 3600;  // 60 seconds at 60fps
  private ArrayList<DACPoint[]> recordedFrames = new ArrayList<DACPoint[]>();
  private String recordingFilename = "laser_recording";
  
  // Statistics tracking
  private int totalPoints = 0;
  private float avgPointsPerFrame = 0;
  private float maxVelocity = 0;
  private float avgVelocity = 0;
  
  /**
   * Constructor
   */
  public SimulationRecorder() {
    // Initialize with empty recording
    resetRecording();
  }
  
  /**
   * Start recording
   */
  public void startRecording() {
    resetRecording();
    isRecording = true;
    println("Recording started...");
  }
  
  /**
   * Stop recording
   */
  public void stopRecording() {
    isRecording = false;
    calculateStatistics();
    println("Recording stopped. " + recordedFrames.size() + " frames recorded.");
  }
  
  /**
   * Reset the recording
   */
  public void resetRecording() {
    recordedFrames.clear();
    totalPoints = 0;
    avgPointsPerFrame = 0;
    maxVelocity = 0;
    avgVelocity = 0;
  }
  
  /**
   * Record a frame of points
   */
  public void recordFrame(DACPoint[] points) {
    if (!isRecording) return;
    
    // Don't exceed max frames
    if (recordedFrames.size() >= maxFrames) {
      stopRecording();
      return;
    }
    
    // Make a copy of the points array
    DACPoint[] frameCopy = new DACPoint[points.length];
    for (int i = 0; i < points.length; i++) {
      frameCopy[i] = new DACPoint(
        points[i].x, 
        points[i].y, 
        points[i].r, 
        points[i].g, 
        points[i].b
      );
    }
    
    // Add to recorded frames
    recordedFrames.add(frameCopy);
    totalPoints += points.length;
  }
  
  /**
   * Calculate statistics for the recording
   */
  private void calculateStatistics() {
    if (recordedFrames.size() == 0) return;
    
    avgPointsPerFrame = (float)totalPoints / recordedFrames.size();
    
    // Calculate velocities
    float totalVelocity = 0;
    int velocityCount = 0;
    
    for (DACPoint[] frame : recordedFrames) {
      for (int i = 1; i < frame.length; i++) {
        DACPoint prev = frame[i-1];
        DACPoint curr = frame[i];
        
        // Calculate distance (velocity)
        float dx = curr.x - prev.x;
        float dy = curr.y - prev.y;
        float distance = sqrt(dx*dx + dy*dy);
        
        totalVelocity += distance;
        velocityCount++;
        
        if (distance > maxVelocity) {
          maxVelocity = distance;
        }
      }
    }
    
    if (velocityCount > 0) {
      avgVelocity = totalVelocity / velocityCount;
    }
  }
  
  /**
   * Save the recording to a file
   */
  public void saveRecording(String filename) {
    if (recordedFrames.size() == 0) {
      println("No recording to save.");
      return;
    }
    
    // Create JSON object for recording
    JSONObject recording = new JSONObject();
    
    // Add metadata
    recording.setInt("frameCount", recordedFrames.size());
    recording.setInt("totalPoints", totalPoints);
    recording.setFloat("avgPointsPerFrame", avgPointsPerFrame);
    recording.setFloat("maxVelocity", maxVelocity);
    recording.setFloat("avgVelocity", avgVelocity);
    
    // Add frames
    JSONArray framesArray = new JSONArray();
    
    for (int i = 0; i < recordedFrames.size(); i++) {
      DACPoint[] frame = recordedFrames.get(i);
      JSONArray pointsArray = new JSONArray();
      
      for (int j = 0; j < frame.length; j++) {
        DACPoint point = frame[j];
        JSONObject pointObj = new JSONObject();
        pointObj.setInt("x", point.x);
        pointObj.setInt("y", point.y);
        pointObj.setInt("r", point.r);
        pointObj.setInt("g", point.g);
        pointObj.setInt("b", point.b);
        pointsArray.setJSONObject(j, pointObj);
      }
      
      framesArray.setJSONArray(i, pointsArray);
    }
    
    recording.setJSONArray("frames", framesArray);
    
    // Save to file
    saveJSONObject(recording, "data/" + filename + ".json");
    println("Recording saved to: " + filename + ".json");
  }
  
  /**
   * Get recording status
   */
  public boolean isRecording() {
    return isRecording;
  }
  
  /**
   * Set the maximum number of frames to record
   */
  public void setMaxFrames(int maxFrames) {
    this.maxFrames = maxFrames;
  }
  
  /**
   * Get statistics as a formatted string
   */
  public String getStatisticsString() {
    if (recordedFrames.size() == 0) {
      return "No recording data available.";
    }
    
    return "Frames: " + recordedFrames.size() +
           "\nTotal Points: " + totalPoints +
           "\nAvg Points/Frame: " + nf(avgPointsPerFrame, 0, 2) +
           "\nMax Velocity: " + nf(maxVelocity, 0, 2) +
           "\nAvg Velocity: " + nf(avgVelocity, 0, 2);
  }
  
  /**
   * Get the number of recorded frames
   */
  public int getFrameCount() {
    return recordedFrames.size();
  }
}
