/**
 * Test 9: Sequential Tests
 * Cycles through all tests over time.
 */
void drawSequentialTests(ArrayList<Point> p) {
  int cycleLength = 600;  // frames to complete full cycle
  int testDuration = cycleLength / 8;  // duration of each test
  
  // Calculate which test to show
  int frameCCount = frameCount % cycleLength;
  int testIndex = frameCCount / testDuration + 1;
  
  // Run the current test
  switch(testIndex) {
    case 1: drawBoundaryTest(p); break;
    case 2: drawColorTest(p); break;
    case 3: drawPrecisionGrid(p); break;
    case 4: drawSpeedTest(p); break;
    case 5: drawLineInterpolationTest(p); break;
    case 6: drawCirclePrecisionTest(p); break;
    case 7: drawComplexCurveTest(p); break;
    case 8: drawResponseTimeTest(p); break;
  }
  
  // On-screen instructions
  fill(255);
  textSize(14);
  text("Test 9: Sequential Tests", 20, 30);
  text("Currently showing: Test " + testIndex, 20, 50);
  text("Tests cycle automatically every " + (testDuration/60) + " seconds", 20, 70);
}
