import themidibus.*; //Import the library
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Queue;

MidiBus myBus; // The MidiBus

Queue<String> q = new ConcurrentLinkedQueue<String>();
CopyOnWriteArrayList<String> l = new CopyOnWriteArrayList<String>();
ConcurrentHashMap<Integer,Integer> h = new ConcurrentHashMap<Integer,Integer>();

void setup() {
  size(400, 400);
  background(0);

  MidiBus.list(); // List all available Midi devices on STDOUT. This will show each device's index and name.

  // Either you can
  //                   Parent In Out
  //                     |    |  |
  //myBus = new MidiBus(this, 0, 1); // Create a new MidiBus using the device index to select the Midi input and output devices respectively.

  // or you can ...
  //                   Parent         In                   Out
  //                     |            |                     |
  //myBus = new MidiBus(this, "IncomingDeviceName", "OutgoingDeviceName"); // Create a new MidiBus using the device names to select the Midi input and output devices respectively.

  // or for testing you could ...
  //                 Parent  In        Out
  //                   |     |          |
  myBus = new MidiBus(this, 0, 1); // Create a new MidiBus with no input device and the default Java Sound Synthesizer as the output device.
}

void draw() {
 /* int channel = 0;
  int pitch = 86;
  int velocity = 68;


  myBus.sendControllerChange(0, 88, 29); // set default bank
  myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
  delay(100);
  myBus.sendNoteOff(channel, pitch, velocity); // Send a Midi nodeOff

  int number = 0;
  int value = 90;

  //myBus.sendControllerChange(channel, number, value); // Send a controllerChange
  //delay(2000);
  */
  background(255);
  for(Integer k : h.values()){
    line(width/2,0,width/12*(k%12),(height));
  }
}

void noteOn(int channel, int pitch, int velocity) {
  // Receive a noteOn
  /*println();
  println("Note On:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);*/
  
  myBus.sendNoteOn(channel, pitch, velocity); // Send a Midi noteOn
  h.put(Integer.valueOf(pitch),Integer.valueOf(velocity));
}

void noteOff(int channel, int pitch, int velocity) {
  // Receive a noteOff
  /*
  println();
  println("Note Off:");
  println("--------");
  println("Channel:"+channel);
  println("Pitch:"+pitch);
  println("Velocity:"+velocity);
  */
  myBus.sendNoteOff(channel, pitch, velocity); // Send a Midi nodeOff
  h.put(Integer.valueOf(pitch),Integer.valueOf(0));
}

void controllerChange(int channel, int number, int value) {
  // Receive a controllerChange
/*  println();
  println("Controller Change:");
  println("--------");
  println("Channel:"+channel);
  println("Number:"+number);
  println("Value:"+value); */
  myBus.sendControllerChange(channel, number, value);
}

void delay(int time) {
  int current = millis();
  while (millis () < current+time) Thread.yield();
}
