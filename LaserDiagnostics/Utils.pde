/**
 * Utility functions for the laser diagnostics suite.
 * Contains all the helper functions for working with points and laser output.
 */

int distance(Point a, Point b) {
  return (int)sqrt(((a.x-a.y)*(a.x-a.y))+((b.x-b.y)*(b.x-b.y)));
}

DACPoint[] getDACPointsAdjusted(Point[] points) {
    DACPoint[] result = new DACPoint[0];
    Point last = points[points.length-1];
    
    // Track buffer size to keep it small
    int currentBufferSize = 0;
    int maxPoints = 0;
    
    // Determine max points based on which test is running
    if (currentTest == 4 || currentTest == 6 || currentTest == 7 || currentTest == 8) {
      // These tests need smaller buffers
      maxPoints = highComplexityMaxPoints;
    } else {
      maxPoints = maxBufferSize;
    }
    
    for(Point p: points){
      int l = distance(last,p);
      
      // Create a new result array when we approach the buffer limit
      DACPoint[] newPoints;
      
      // Adaptive interpolation based on distance but with reduced point counts
      if (l < 500) {
        // For very short distances, minimal interpolation
        newPoints = getDACPointsLerpAdjusted(last, p, 2, 0.5);
      } else if (l < 2000) {
        // For medium distances
        newPoints = getDACPointsLerpAdjusted(last, p, 4, 0.3);
      } else if (l < 5000) {
        // For longer distances
        newPoints = getDACPointsLerpAdjusted(last, p, 6, 0.2);
      } else {
        // For very long jumps
        newPoints = getDACPointsLerpAdjusted(last, p, 10, 0.15);
      }
      
      // Check if adding these points would exceed our buffer limit
      if (currentBufferSize + newPoints.length > maxPoints) {
        // Start a new buffer - the DAC will process these separately
        result = concatPoints(result, new DACPoint[1]);  // Add a small pause
        currentBufferSize = 0;
      }
      
      result = concatPoints(result, newPoints);
      currentBufferSize += newPoints.length;
      
      last = p;
    }
    return result;
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
  // For problematic tests, use more conservative minimum values
  int adjustedMinimum = minimum;
  
  if (currentTest == 4 || currentTest == 6 || currentTest == 7 || currentTest == 8) {
    // These tests need more conservative minimums
    adjustedMinimum = 300;  // Half the normal value
  }
  
  if (p.length >= adjustedMinimum) {
    return p;
  }
  
  // For high complexity tests, apply more gentle padding
  if (currentTest == 4 || currentTest == 6 || currentTest == 7 || currentTest == 8) {
    // Don't duplicate as aggressively for complex tests
    return concatPoints(p, p);
  }
  
  // Standard approach for other tests
  if (p.length <= (minimum/4)) {
    return pointsMinimum(concatPoints(p, p, p, p), minimum);    
  }
  
  if (p.length <= (minimum/3)) {
    return pointsMinimum(concatPoints(p, p, p), minimum);
  }
  
  return pointsMinimum(concatPoints(p, p), minimum);
}
