/* LICENSE: BSD 2-Clause "Simplified" License
Copyright 2021 Xerxes Rånby
Copyright 2025 - Improvements

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * Etherdream DAC for Java and Processing 4 
 * By Xerxes Rånby 2021
 * Improved version 2025
 * 
 * Implementation of the ether-dream protocol
 * https://ether-dream.com/protocol.html
 * 
 * Features:
 * - Automatic discovery of the DAC by listening for UDP broadcast
 * - State machine manages connection and handles recovery
 * - Automatic reconnection on connection loss
 * - Adaptive buffer management for improved stability
 * - Emergency stop detection and recovery
 * - Hardware capability detection
 * 
 */
import java.io.*;
import java.net.*;
import java.util.Arrays;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import java.lang.reflect.Method;

/**
 * DAC state machine states
 */
enum State {
    STARTUP, GET_BROADCAST, INIT, WRITE_DATA, ERROR_RECOVERY;
}

/**
 * Commands that can be sent to the DAC
 */
enum Command {
    PREPARE_STREAM('p'), BEGIN_PLAYBACK('b'), QUEUE_RATE_CHANGE('q'), WRITE_DATA('d'), STOP('s'),
    EMERGENCY_STOP(0x00), EMERGENCY_STOP_ALTERNATIVE(0xFF), CLEAR_EMERGENCY_STOP('c'),
    PING('?'), VERSION('v'),
    ACK_RESPONSE('a'), NAK_FULL_RESPONSE('F'), NAK_INVALID_RESPONSE('i'), NAK_STOPCONDITION_RESPONSE('!');

    final byte command;

    private Command(int cmd) {
        command = (byte) (cmd & 0xFF);
    }

    public byte[] bytes() {
        return new byte[] { command };
    }

    public byte[] bytes(int... data) {
        switch (this) {
            case BEGIN_PLAYBACK:
                return safeConcat(bytes(), toBytesShort(data[0]), toBytes(data[1]));
            default:
                return safeConcat(bytes(), toBytesShort(data));
        }
    }

    // Add overloaded method to handle byte arrays directly
    public byte[] bytes(byte[] data) {
        if (data == null) {
            return bytes();
        }
        return safeConcat(bytes(), data);
    }

    public byte[] bytes(DACPoint p) {
        if (p == null) {
            return safeConcat(bytes(), toBytes((short) 0));
        }
        return safeConcat(bytes(), toBytes((short) 1), p.bytes());
    }

    public byte[] bytes(DACPoint[] p) {
        if (p == null || p.length == 0) {
            return safeConcat(bytes(), toBytes((short) 0));
        }
        
        byte[] pb = safeConcat(p);
        return safeConcat(bytes(), toBytes((short) p.length), pb);
    }

    public byte getCommand() {
        return command;
    }
}

/**
 * DAC playback status values
 */
enum DACStatus {
    IDLE(0x01), PREPARED(0x02), PLAYING(0x03);

    final byte status;

    private DACStatus(int cmd) {
        status = (byte) (cmd & 0xFF);
    }

    public byte[] bytes() {
        return new byte[] { status };
    }
}

/**
 * Represents a single point to be displayed by the laser
 */
public class DACPoint implements Byteable {
    byte[] p;

    DACPoint() {
        p = new byte[18];
    }

    /**
     * Creates a new point with specified coordinates and RGB color values
     * 
     * @param x X coordinate (-32767 to 32767)
     * @param y Y coordinate (-32767 to 32767)
     * @param r Red value (0 to 65535)
     * @param g Green value (0 to 65535)
     * @param b Blue value (0 to 65535)
     */
    DACPoint(int x, int y, int r, int g, int b) {
        p = toBytes((char) 0x0, (char) x, (char) y, (char) r, (char) g, (char) b, (char) 0x0, (char) 0x0,
                (char) 0x0);
    }

    /**
     * Creates a new white point at specified coordinates
     * 
     * @param x X coordinate (-32767 to 32767)
     * @param y Y coordinate (-32767 to 32767)
     */
    DACPoint(int x, int y) {
        p = toBytes((char) 0x0, (char) x, (char) y, (char) 65535, (char) 65535, (char) 65535, (char) 0x0,
                (char) 0x0, (char) 0x0);
    }

    /*
     * struct dac_point { 
     *   uint16_t control; 
     *   int16_t x; 
     *   int16_t y; 
     *   uint16_t r;
     *   uint16_t g; 
     *   uint16_t b; 
     *   uint16_t i; 
     *   uint16_t u1; 
     *   uint16_t u2; 
     * };
     */
    public byte[] bytes() {
        return p;
    }
}

/**
 * Main Etherdream DAC interface class
 */
class Etherdream implements Runnable {

    // Processing callback for getting frames
    Method method_get_frame = null;
    Object processing = null;
    
    // Communication state
    volatile State state = State.GET_BROADCAST;
    OutputStream output = null;
    InputStream input = null;
    
    // Configuration
    private int maxPointsPerFrame = 600;      // Maximum points in a single frame
    private int frameRetryLimit = 3;          // Number of retries for failed frames
    private int reconnectDelayMs = 1000;      // Delay before reconnection attempts
    private int bufferLowWatermark = 100;     // Start sending more data when buffer drops below this
    private boolean debugOutput = true;       // Enable/disable debug messages
    
    // Buffer management and recovery enhancements
    private float maxBufferUtilization = 0.65f;  // Only use 65% of buffer capacity
    private int maxPointRate = 25000;            // Reduced from 30000
    private int maxRetries = 5;                  // Increased retry limit
    private int lastBufferFullness = 0;
    private boolean throttlingActive = false;
    private long lastSuccessfulPingTime = 0;
    private long pingTimeoutThreshold = 5000;    // 5 seconds
    
    // Internal state tracking
    private AtomicInteger failedFrames = new AtomicInteger(0);
    private AtomicInteger successfulFrames = new AtomicInteger(0);
    private AtomicLong lastSuccessTime = new AtomicLong(0);
    private AtomicInteger connectionAttempts = new AtomicInteger(0);
    
    // Queue for pending frames
    private ConcurrentLinkedQueue<DACPoint[]> frameQueue = new ConcurrentLinkedQueue<>();

    /**
     * Creates a new Etherdream instance for communicating with the DAC
     * 
     * @param processing The Processing sketch instance (used for callbacks)
     */
    public Etherdream(Object processing) {
        this.processing = processing;
        try {
           method_get_frame = processing.getClass().getMethod("getDACPoints", new Class[] {});
        } catch(Exception e) {
           log("Warning: getDACPoints method not found in Processing sketch");
        }
        
        final Thread thread = new Thread(this);
        thread.setDaemon(true);
        thread.setName("Etherdream-DAC");
        thread.start();
        
        log("Etherdream DAC interface started");
    }
    
    /**
     * Configure the DAC interface parameters
     * 
     * @param maxPoints Maximum points per frame (default 600)
     * @param debug Enable/disable debug output (default true)
     */
    public void configure(int maxPoints, boolean debug) {
        this.maxPointsPerFrame = maxPoints;
        this.debugOutput = debug;
        log("Configuration updated: maxPoints=" + maxPoints + ", debug=" + debug);
    }
    
    /**
     * Configure buffer management parameters
     * 
     * @param bufferUtilization Maximum buffer utilization (0.0-1.0)
     * @param pointRate Maximum point rate
     */
    public void configureBuffer(float bufferUtilization, int pointRate) {
        this.maxBufferUtilization = Math.max(0.1f, Math.min(0.9f, bufferUtilization));
        this.maxPointRate = pointRate;
        log("Buffer configuration updated: utilization=" + maxBufferUtilization + 
            ", pointRate=" + maxPointRate);
    }
    
    /**
     * Get current performance statistics
     * 
     * @return String containing performance information
     */
    public String getStats() {
        return String.format("Frames: %d successful, %d failed, Queue: %d, Buffer: %d", 
                             successfulFrames.get(), failedFrames.get(), 
                             frameQueue.size(), lastBufferFullness);
    }
    
    /**
     * Reset performance counters
     */
    public void resetStats() {
        failedFrames.set(0);
        successfulFrames.set(0);
    }
    
    /**
     * Sends a command to the DAC and reads the response with improved timeout handling
     */
    DACResponse write(Command cmd) throws IOException {
        try {
            switch (cmd) {
                case VERSION:
                    output.write(cmd.bytes());
                    output.flush();
                    // Use a safe read method with timeout handling
                    byte[] version = safeReadBytes(32);
                    String versionString = new String(version).replace("\0", "").strip();
                    log("DAC Version: " + versionString);
                    return null;
                default:
                    output.write(cmd.bytes());
                    output.flush();
                    return readResponse(cmd);
            }
        } catch (IOException e) {
            log("IO Error during command " + cmd + ": " + e.getMessage());
            throw e;
        }
    }

    /**
     * Sends a command with integer parameters to the DAC
     * 
     * @param cmd Command to send
     * @param data Integer parameters
     * @return DAC response
     * @throws IOException If communication fails
     */
    DACResponse write(Command cmd, int... data) throws IOException {
        byte[] bytes = cmd.bytes(data);
        output.write(bytes);
        output.flush();
        return readResponse(cmd);
    }

    /**
     * Sends points to the DAC
     * 
     * @param cmd Command to send (usually WRITE_DATA)
     * @param data Points to send
     * @return DAC response
     * @throws IOException If communication fails
     */
    DACResponse write(Command cmd, DACPoint... data) throws IOException {
        if (data == null || data.length == 0) {
            // Handle empty data case gracefully
            byte[] bytes = cmd.bytes(toBytes((short) 0));
            output.write(bytes);
            output.flush();
            return readResponse(cmd);
        }
        
        byte[] bytes = cmd.bytes(data);
        output.write(bytes);
        output.flush();
        return readResponse(cmd);
    }

    /**
     * Safely reads bytes with better timeout handling
     */
    private byte[] safeReadBytes(int numBytes) throws IOException {
        byte[] buffer = new byte[numBytes];
        int totalBytesRead = 0;
        int timeout = 0;
        
        while (totalBytesRead < numBytes) {
            if (input.available() > 0) {
                int bytesRead = input.read(buffer, totalBytesRead, numBytes - totalBytesRead);
                if (bytesRead == -1) {
                    throw new IOException("End of stream reached");
                }
                totalBytesRead += bytesRead;
                timeout = 0; // Reset timeout counter
            } else {
                // Short delay to prevent CPU thrashing
                try {
                    Thread.sleep(1);
                } catch (InterruptedException e) {
                    // Ignore
                }
                
                timeout++;
                if (timeout > 3000) { // 3 second timeout
                    throw new SocketTimeoutException("Read timed out after 3 seconds");
                }
            }
        }
        
        return buffer;
    }

    /**
     * Reads and parses a response from the DAC with improved error handling
     */
    DACResponse readResponse(Command cmd) throws IOException {
        try {
            // Use safe read method with timeout handling
            byte[] responseBytes = safeReadBytes(22);
            
            if (responseBytes.length < 22) {
                throw new IOException("Incomplete response from DAC: " + responseBytes.length + " bytes");
            }
            
            DACResponse dac_response = new DACResponse(responseBytes);

            // Handle emergency stop condition
            if(dac_response.playback_state == 3) {
                log("E-STOP detected: light_engine_flags=" + dac_response.light_engine_flags + 
                    " playback_flags=" + dac_response.playback_flags);
                log("Response for " + ((char) cmd.command) + ": " + dac_response);
            }

            // Verify we got an ACK
            if (dac_response.response != Command.ACK_RESPONSE.command) {
                log("Unexpected response: " + ((char) dac_response.response) + " (" + dac_response.response + ")");
                failedFrames.incrementAndGet();
                state = State.ERROR_RECOVERY;
            }

            // Verify we got the response for the correct command
            if (dac_response.command != cmd.command) {
                if(dac_response.command == Command.EMERGENCY_STOP.command) {
                    log("E-STOP response: light_engine_flags=" + dac_response.light_engine_flags);
                    log("Response for " + ((char) cmd.command) + ": " + dac_response);
                } else {
                    log("Unexpected response from wrong command: " + ((char) dac_response.command) + 
                        " (" + dac_response.command + "), expected: " + ((char) cmd.command) + 
                        " (" + cmd.command + ")");
                }
                failedFrames.incrementAndGet();
                state = State.ERROR_RECOVERY;
            } else {
                // Command succeeded
                successfulFrames.incrementAndGet();
                lastSuccessTime.set(System.currentTimeMillis());
            }

            return dac_response;
        } catch (IOException e) {
            log("IO Error during response read: " + e.getMessage());
            throw e;
        }
    }

    /**
     * Information about a DAC received from its broadcast
     */
    class DACBroadcast {
        /*
         * struct j4cDAC_broadcast { 
         *   uint8_t mac_address[6]; 
         *   uint16_t hw_revision;
         *   uint16_t sw_revision; 
         *   uint16_t buffer_capacity; 
         *   uint32_t max_point_rate;
         *   struct dac_status status; 
         * };
         */
        
        public final byte[] mac_address;
        public final int 
        /* uint16_t */   hw_revision, sw_revision, buffer_capacity, max_point_rate;

        DACBroadcast(byte[] dac_broadcast) {
            final ByteBuffer bb = ByteBuffer.wrap(dac_broadcast);
            bb.order(ByteOrder.LITTLE_ENDIAN);

            mac_address = new byte[]{bb.get(),bb.get(),bb.get(),bb.get(),bb.get(),bb.get()};
            /* uint16_t */ 
            hw_revision = bb.getShort()&0xFFFF;
            sw_revision = bb.getShort()&0xFFFF;
            buffer_capacity = bb.getShort()&0xFFFF;
            max_point_rate = bb.getShort()&0xFFFF;
        }

        public String toString() {
            return String.format("MAC: %02X:%02X:%02X:%02X:%02X:%02X, HW Rev: %d, SW Rev: %d, Buffer: %d points, Max Rate: %d pps",
                mac_address[0]&0xFF, mac_address[1]&0xFF, mac_address[2]&0xFF, 
                mac_address[3]&0xFF, mac_address[4]&0xFF, mac_address[5]&0xFF,
                hw_revision, sw_revision, buffer_capacity, max_point_rate);
        }
    }

    /**
     * Response from the DAC after a command
     */
    class DACResponse {
        /*
         * struct dac_response { 
         *   uint8_t response; 
         *   uint8_t command; 
         *   struct status dac_status; 
         * };
         *
         * struct dac_status { 
         *   uint8_t protocol; 
         *   uint8_t light_engine_state; 
         *   uint8_t playback_state; 
         *   uint8_t source; 
         *   uint16_t light_engine_flags; 
         *   uint16_t playback_flags; 
         *   uint16_t source_flags; 
         *   uint16_t buffer_fullness; 
         *   uint32_t point_rate; 
         *   uint32_t point_count; 
         * };
         */
        public final int 
        /* uint8_t  */   response, command, protocol, light_engine_state, playback_state, source,
        /* uint16_t */   light_engine_flags, playback_flags, source_flags, buffer_fullness,
        /* uint32_t */   point_rate, point_count;
        
        
        DACResponse(byte[] dac_response) {
            final ByteBuffer bb = ByteBuffer.wrap(dac_response);
            bb.order(ByteOrder.LITTLE_ENDIAN);
            
            response = bb.get()&0xFF;
            command = bb.get()&0xFF;
            /* uint8_t  */
            protocol = bb.get()&0xFF;
            light_engine_state = bb.get()&0xFF;
            playback_state = bb.get()&0xFF;
            source = bb.get()&0xFF;
            /* uint16_t */
            light_engine_flags = bb.getShort()&0xFFFF;
            playback_flags = bb.getShort()&0xFFFF;
            source_flags = bb.getShort()&0xFFFF;
            buffer_fullness = bb.getShort()&0xFFFF;
            /* uint32_t */
            point_rate = bb.getInt()&0xFFFFFFFF;
            point_count = bb.getInt()&0xFFFFFFFF;
        }

        public String toString() {
            return String.format("LE state: %d, Playback state: %d, Buffer: %d/%d, Rate: %d pps, Count: %d points",
                light_engine_state, playback_state, buffer_fullness, 1800, point_rate, point_count);
        }
    }

    /**
     * Main DAC communication thread
     */
    @Override
    public void run() {
        State lastState = State.STARTUP;
        DACBroadcast dacBroadcast = null;
        InetAddress etherdreamAddress = null;
        Socket socket = null;
        DACPoint[] frame = null;
        int reconnectDelay = reconnectDelayMs;
        int errorCount = 0;
        
        // Main state machine loop
        while (true) {
            // Log state transitions
            if(lastState != state) {
                log("State transition: " + lastState + " -> " + state);
                lastState = state;
            }
            
            try {
                switch (state) {
                    // Waiting for DAC broadcast
                    case GET_BROADCAST: {
                        connectionAttempts.incrementAndGet();
                        
                        try (DatagramSocket inSocket = new DatagramSocket(7654)) {
                            inSocket.setSoTimeout(5000); // 5 second timeout
                            log("Waiting for DAC broadcast on port 7654...");

                            // Wait for broadcast
                            byte[] buffer = new byte[512];
                            DatagramPacket response = new DatagramPacket(buffer, buffer.length);
                            inSocket.receive(response);

                            dacBroadcast = new DACBroadcast(Arrays.copyOfRange(buffer, 0, response.getLength()));
                            log("Discovered DAC: " + dacBroadcast);
                            etherdreamAddress = response.getAddress();
                            log("DAC IP address: " + etherdreamAddress.getHostAddress());

                            if (etherdreamAddress != null) {
                                // Close existing socket if present
                                if (socket != null) {
                                    try {
                                        socket.close();
                                        socket = null;
                                    } catch (IOException e1) {
                                        // Ignore close errors
                                    }
                                }
                                
                                // Connect to DAC
                                log("Connecting to DAC on port 7765...");
                                socket = new Socket();
                                socket.connect(new InetSocketAddress(etherdreamAddress, 7765), 2000); // 2 second connect timeout
                                socket.setSoTimeout(3000); // 3 second read timeout
                                
                                output = socket.getOutputStream();
                                input = socket.getInputStream();
                                state = State.INIT;
                                reconnectDelay = reconnectDelayMs; // Reset reconnect delay
                                errorCount = 0; // Reset error counter

                                // When a host first connects to the device, the device immediately sends it a
                                // status reply, as if the host had sent a ping packet
                                readResponse(Command.PING);
                            }
                        } catch (SocketTimeoutException ste) {
                            log("Timeout waiting for DAC broadcast, retrying...");
                            Thread.sleep(reconnectDelay);
                        }
                        break;
                    }
                    
                    // Initialize DAC connection
                    case INIT: {
                        try {
                            // Reset key state variables
                            throttlingActive = false;
                            lastSuccessfulPingTime = System.currentTimeMillis();
                            
                            // Send ping and get version with shortened timeout
                            log("Initializing DAC connection...");
                            socket.setSoTimeout(1500); // Shorter timeout for initialization
                            
                            DACResponse r = write(Command.PING);
                            write(Command.VERSION);

                            // Clear emergency stop if needed
                            if (r != null && r.light_engine_state == 3) {
                                log("Clearing emergency stop condition");
                                write(Command.CLEAR_EMERGENCY_STOP);
                            }

                            // Prepare for streaming
                            r = write(Command.PREPARE_STREAM);
                            log("Stream prepared: " + r);

                            // Get initial frames - ensure we have valid data
                            frame = getFrame();
                            if (frame == null || frame.length == 0) {
                                log("Warning: Empty frame received during initialization");
                                frame = getTestPattern();
                            }
                            log("Initial frame ready with " + frame.length + " points");
                            
                            // Send first frame
                            r = write(Command.WRITE_DATA, frame);
                            log("First frame sent: " + r);
                            
                            // Get second frame for buffer
                            frame = getFrame();
                            if (frame == null || frame.length == 0) {
                                log("Warning: Empty frame received for buffer");
                                frame = getTestPattern();
                            }
                            log("Second frame ready with " + frame.length + " points");
                            
                            // Start playback at reduced point rate for stability
                            int pointRate = dacBroadcast != null ? 
                                Math.min(maxPointRate, dacBroadcast.max_point_rate) : maxPointRate;
                            
                            log("Starting playback at " + pointRate + " points per second");
                            r = write(Command.BEGIN_PLAYBACK, 0, pointRate);
                            log("Playback started: " + r);
                            
                            // Reset timeout to normal
                            socket.setSoTimeout(3000);
                            
                            // Successful initialization
                            state = State.WRITE_DATA;
                            errorCount = 0; // Reset error counter on successful init
                        } catch (Exception e) {
                            log("Error during initialization: " + e.getMessage());
                            e.printStackTrace();
                            state = State.ERROR_RECOVERY;
                        }
                        break;
                    }
                    
                    // Normal operation - keep sending data
                    case WRITE_DATA: {
                        try {
                            // Check if we've had a successful ping recently to avoid timeouts
                            long timeSinceLastSuccess = System.currentTimeMillis() - lastSuccessfulPingTime;
                            if (timeSinceLastSuccess > pingTimeoutThreshold) {
                                log("No successful ping for " + (timeSinceLastSuccess/1000) + " seconds, entering recovery");
                                state = State.ERROR_RECOVERY;
                                break;
                            }
                            
                            // Check DAC status with shorter timeout
                            socket.setSoTimeout(800); // Shorter timeout
                            DACResponse r;
                            
                            try {
                                r = write(Command.PING);
                                lastSuccessfulPingTime = System.currentTimeMillis();
                                
                                // Store buffer fullness for monitoring
                                lastBufferFullness = r.buffer_fullness;
                            } catch (SocketTimeoutException ste) {
                                log("Ping timeout in WRITE_DATA, entering recovery");
                                state = State.ERROR_RECOVERY;
                                break;
                            }
                            
                            // Determine buffer capacity 
                            int bufferCapacity = (dacBroadcast != null) ? 
                                dacBroadcast.buffer_capacity : 1800;
                            
                            // Calculate safe buffer limit based on utilization target
                            int safeBufferLimit = (int)(bufferCapacity * maxBufferUtilization);
                            
                            // Make sure we have a valid frame
                            if (frame == null || frame.length == 0) {
                                frame = getTestPattern();
                            }
                            
                            // Check if we're above the safe threshold
                            if (r.buffer_fullness > safeBufferLimit) {
                                // Buffer getting full, activate throttling
                                if (!throttlingActive) {
                                    throttlingActive = true;
                                    log("Activating throttling at " + r.buffer_fullness + "/" + bufferCapacity + 
                                        " (" + (int)(r.buffer_fullness * 100.0 / bufferCapacity) + "%)");
                                }
                                
                                // Wait longer when buffer is fuller (dynamic delay)
                                int delayMs = (int)(50 * (r.buffer_fullness - safeBufferLimit) / 
                                          (bufferCapacity - safeBufferLimit));
                                delayMs = Math.min(100, Math.max(20, delayMs));
                                
                                log("Buffer high (" + r.buffer_fullness + "/" + bufferCapacity + 
                                    "), waiting " + delayMs + "ms");
                                Thread.sleep(delayMs);
                                
                                // Just continue without sending to let buffer drain
                                continue;
                            } else if (throttlingActive && r.buffer_fullness < (safeBufferLimit * 0.8)) {
                                // Resume normal operation when buffer is well below threshold
                                throttlingActive = false;
                                log("Deactivating throttling at " + r.buffer_fullness + "/" + bufferCapacity);
                            }
                            
                            // If there's room in the buffer, send more frames
                            if (r.buffer_fullness < (bufferCapacity - frame.length)) {
                                // Log frame details
                                log("Sending frame with " + frame.length + " points, buffer: " + 
                                    r.buffer_fullness + "/" + bufferCapacity + 
                                    " (" + (int)(r.buffer_fullness * 100.0 / bufferCapacity) + "%)");
                                
                                // Send frame
                                write(Command.WRITE_DATA, frame);
                                
                                // Get next frame immediately
                                frame = getFrame();
                                
                                // Small delay between frames for stability
                                Thread.sleep(5);
                            } else {
                                // Buffer full, wait longer
                                log("Buffer full (" + r.buffer_fullness + "/" + bufferCapacity + 
                                    "), waiting before sending more");
                                Thread.sleep(30);
                            }
                            
                            // Reset timeout back to normal
                            socket.setSoTimeout(3000);
                        } catch (Exception e) {
                            log("Error in WRITE_DATA state: " + e.getMessage());
                            e.printStackTrace();
                            state = State.ERROR_RECOVERY;
                        }
                        break;
                    }
                        
                    // Error recovery
case ERROR_RECOVERY: {
    errorCount++;
    log("Error recovery attempt " + errorCount + "/" + maxRetries);
    
    // Close socket immediately to free resources
    if (socket != null) {
        try {
            log("Closing existing socket connection");
            socket.close();
            socket = null;
        } catch (Exception e) {
            // Ignore close errors
            log("Error closing socket: " + e.getMessage());
        }
    }
    
    // Clear input/output streams
    input = null;
    output = null;
    
    // Sleep longer between recovery attempts (exponential backoff)
    int recoveryDelay = 500 * (1 << Math.min(errorCount, 4)); // 500ms to 8000ms
    log("Waiting " + recoveryDelay + "ms before retry");
    
    try {
        Thread.sleep(recoveryDelay);
    } catch (InterruptedException ie) {
        // Ignore interrupts
    }
    
    // After too many attempts, restart from broadcast discovery
    if (errorCount >= maxRetries) {
        log("Too many recovery attempts (" + errorCount + "), restarting from broadcast discovery");
        errorCount = 0;
        state = State.GET_BROADCAST;
        
        // Force a longer delay before restarting
        try {
            Thread.sleep(3000);
        } catch (InterruptedException ie) {
            // Ignore interrupts
        }
    } else {
        // For initial retries, try to reconnect directly
        try {
            log("Attempting direct reconnection to " + etherdreamAddress);
            
            // Create new socket with fresh connection
            socket = new Socket();
            socket.connect(new InetSocketAddress(etherdreamAddress, 7765), 2000);
            socket.setSoTimeout(3000);
            
            // Reset streams
            output = socket.getOutputStream();
            input = socket.getInputStream();
            
            // Read initial response that DAC sends on connection
            try {
                log("Reading initial response");
                readResponse(Command.PING);
                log("Successfully reconnected");
                state = State.INIT;
            } catch (Exception e) {
                log("Failed to read initial response: " + e.getMessage());
                socket.close();
                socket = null;
                // Continue in ERROR_RECOVERY state for next attempt
            }
        } catch (Exception e) {
            log("Direct reconnection failed: " + e.getMessage());
            // Continue in ERROR_RECOVERY state for next attempt
        }
    }
    break;
}                    
                    // Default behavior for unexpected states
                    default:
                        log("Unexpected state: " + state + ", resetting");
                        state = State.GET_BROADCAST;
                }
            } catch (SocketTimeoutException ste) {
                log("Communication timeout: " + ste.getMessage());
                state = State.ERROR_RECOVERY;
            } catch (SocketException se) {
                log("Socket error: " + se.getMessage());
                if (socket != null) {
                    try {
                        socket.close();
                    } catch (Exception e) {
                        // Ignore close errors
                    }
                    socket = null;
                }
                state = State.GET_BROADCAST;
                
                // Implement exponential backoff for reconnection
                try {
                    Thread.sleep(reconnectDelay);
                    reconnectDelay = Math.min(reconnectDelay * 2, 10000); // Max 10 second delay
                } catch (InterruptedException ie) {
                    // Ignore interrupts
                }
            } catch (Exception e) {
                // Handle all other exceptions
                log("Error in DAC communication: " + e.getMessage());
                e.printStackTrace();
                state = State.GET_BROADCAST;
                
                try {
                    Thread.sleep(reconnectDelay);
                } catch (InterruptedException ie) {
                    // Ignore interrupts
                }
            }
        }
    }

    /**
     * Get the next frame to display
     * 
     * @return Array of points to display
     */


/**
 * Get the next frame to display with more robust handling and logging
 */
DACPoint[] getFrame() {
    // First try to get a frame from the queue
    DACPoint[] queuedFrame = frameQueue.poll();
    if (queuedFrame != null && queuedFrame.length > 0) {
        log("Using queued frame with " + queuedFrame.length + " points");
        return queuedFrame;
    }
    
    // If no frames in queue, get a frame from the callback
    if (method_get_frame != null) {
        try {
            DACPoint[] result = (DACPoint[]) method_get_frame.invoke(processing, new Object[] {});
            if (result != null && result.length > 0) {
                log("Got frame from callback with " + result.length + " points");
                return result;
            } else {
                log("Warning: Callback returned null or empty frame");
            }
        } catch(Exception e) {
            log("Error getting frame from callback: " + e.getMessage());
            e.printStackTrace();
        }
    } else {
        log("No frame callback method available");
    }
    
    // Fall back to a simple test pattern if no callback available
    log("Generating test pattern frame");
    return getTestPattern();
}
    
    
/**
 * Generate a test pattern with explicit points count for diagnostics
 */
/**
 * Generate an optimized test pattern specifically for EtherDream DACs
 * This pattern is designed to be very stable and low-complexity
 */
DACPoint[] getTestPattern() {
    // Create a diamond pattern which is very stable for laser DACs
    // Using fewer points for more reliable operation
    int points = 100;  // Reduced from earlier values for stability
    DACPoint[] result = new DACPoint[points];
    
    log("Generating test pattern with " + points + " points");
    
    // Create simple diamond pattern (square rotated 45 degrees)
    // This generates clean straight lines that are easy for galvos
    for (int i = 0; i < points; i++) {
        float progress = (float)i / points;
        float angle = (float)(progress * 2 * Math.PI);
        
        // Create a diamond shape (square rotated 45 degrees)
        float x, y;
        float segment = progress * 4; // 4 segments
        int segmentNum = (int)segment;
        float segmentPos = segment - segmentNum;
        
        // Shape is a diamond - 4 straight lines
        switch (segmentNum % 4) {
            case 0: // Top right edge
                x = 1 - segmentPos;
                y = segmentPos;
                break;
            case 1: // Bottom right edge
                x = -segmentPos;
                y = 1 - segmentPos;
                break;
            case 2: // Bottom left edge
                x = -1 + segmentPos;
                y = -segmentPos;
                break;
            case 3: // Top left edge
                x = segmentPos;
                y = -1 + segmentPos;
                break;
            default:
                x = 0;
                y = 0;
        }
        
        // Scale to 70% of max range for safety (25000 instead of 32767)
        result[i] = new DACPoint(
            (int)(x * 25000),
            (int)(y * 25000),
            65535, 65535, 65535 // Full white
        );
    }
    
    return result;
}

/**
 * Get a frame for boundary test - simpler pattern that's very stable
 * This can be used for Test 1 in your diagnostics tool
 */
DACPoint[] getBoundaryTestFrame() {
    // Create a simple square with crosshair that's ideal for boundary testing
    // The simple geometric pattern uses fewer points and is galvo-friendly
    int points = 120; // 30 points per side of square + center crosshair
    DACPoint[] result = new DACPoint[points];
    
    log("Generating boundary test with " + points + " points");
    
    // First draw the square outline
    for (int i = 0; i < 120; i++) {
        float progress = (float)i / 120;
        float segment = progress * 4; // 4 segments
        int segmentNum = (int)segment;
        float segmentPos = segment - segmentNum;
        
        float x, y;
        
        if (i < 100) {
            // Square outline - 25 points per side
            switch (segmentNum % 4) {
                case 0: // Top edge
                    x = segmentPos * 2 - 1; // -1 to 1
                    y = 1;
                    break;
                case 1: // Right edge
                    x = 1;
                    y = 1 - segmentPos * 2; // 1 to -1
                    break;
                case 2: // Bottom edge
                    x = 1 - segmentPos * 2; // 1 to -1
                    y = -1;
                    break;
                case 3: // Left edge
                    x = -1;
                    y = -1 + segmentPos * 2; // -1 to 1
                    break;
                default:
                    x = 0;
                    y = 0;
            }
        } else {
            // Center crosshair - 20 points
            int crossIndex = i - 100;
            if (crossIndex < 10) {
                // Horizontal line
                x = (crossIndex / 10.0f) * 2 - 1; // -1 to 1
                y = 0;
            } else {
                // Vertical line
                x = 0;
                y = ((crossIndex - 10) / 10.0f) * 2 - 1; // -1 to 1
            }
        }
        
        // Color based on segment
        int r = 0, g = 0, b = 0;
        if (i < 100) {
            // Square outline - different color per side
            switch (segmentNum % 4) {
                case 0: r = 65535; break;              // Top: Red
                case 1: g = 65535; break;              // Right: Green
                case 2: b = 65535; break;              // Bottom: Blue
                case 3: r = 65535; g = 65535; break;   // Left: Yellow
            }
        } else {
            // Crosshair - white
            r = g = b = 65535;
        }
        
        // Scale to 80% of max range for safety (26000 instead of 32767)
        result[i] = new DACPoint(
            (int)(x * 26000),
            (int)(y * 26000),
            r, g, b
        );
    }
    
    return result;
}    
    /**
     * Queue a frame for display
     * 
     * @param frame Array of points to display
     * @return true if frame was queued, false if queue is full
     */
    public boolean queueFrame(DACPoint[] frame) {
        if (frameQueue.size() < 5) { // Keep queue small
            frameQueue.add(frame);
            return true;
        }
        return false;
    }
    
    /**
     * Clear all queued frames
     */
    public void clearQueue() {
        frameQueue.clear();
    }
    
    /**
     * Log a message if debug output is enabled
     * 
     * @param message Message to log
     */
    private void log(String message) {
        if (debugOutput) {
            System.out.println("[Etherdream] " + message);
        }
    }
}

// ================================================
// Helper Functions
// ================================================

/**
 * Interface for objects that can be converted to bytes
 */
interface Byteable {
    public byte[] bytes();
}

/**
 * Convert char array to bytes in little-endian format
 */
public static byte[] toBytes(final char... charArray) {
    if (charArray == null || charArray.length == 0) {
        return new byte[0];
    }
    
    final ByteBuffer bb = ByteBuffer.allocate((charArray.length * 2));
    bb.order(ByteOrder.LITTLE_ENDIAN);
    for (final char val : charArray) {
        bb.putChar(val);
    }
    return bb.array();
}

/**
 * Convert int array to bytes in little-endian format
 */
public static byte[] toBytes(final int... intArray) {
    if (intArray == null || intArray.length == 0) {
        return new byte[0];
    }
    
    final ByteBuffer bb = ByteBuffer.allocate((intArray.length * 4));
    bb.order(ByteOrder.LITTLE_ENDIAN);
    for (final int val : intArray) {
        bb.putInt(val);
    }
    return bb.array();
}

/**
 * Convert int array to short bytes in little-endian format
 */
public static byte[] toBytesShort(final int... intArray) {
    if (intArray == null || intArray.length == 0) {
        return new byte[0];
    }
    
    final ByteBuffer bb = ByteBuffer.allocate((intArray.length * 2));
    bb.order(ByteOrder.LITTLE_ENDIAN);
    for (final int val : intArray) {
        bb.putShort((short)val);
    }
    return bb.array();
}

/**
 * Convert short array to bytes in little-endian format
 */
public static byte[] toBytes(final short... shortArray) {
    if (shortArray == null || shortArray.length == 0) {
        return new byte[0];
    }
    
    final ByteBuffer bb = ByteBuffer.allocate((shortArray.length * 2));
    bb.order(ByteOrder.LITTLE_ENDIAN);
    for (final short val : shortArray) {
        bb.putShort(val);
    }
    return bb.array();
}

/**
 * Concatenate multiple byte arrays - null-safe version
 */
static byte[] safeConcat(byte[]... arrays) {
    // Handle null or empty arrays
    if (arrays == null || arrays.length == 0) {
        return new byte[0];
    }
    
    // Calculate total length, ignoring null arrays
    int totalLength = 0;
    for (int i = 0; i < arrays.length; i++) {
        if (arrays[i] != null) {
            totalLength += arrays[i].length;
        }
    }

    // Create result array
    byte[] result = new byte[totalLength];

    // Copy the source arrays into the result array
    int currentIndex = 0;
    for (int i = 0; i < arrays.length; i++) {
        if (arrays[i] != null && arrays[i].length > 0) {
            System.arraycopy(arrays[i], 0, result, currentIndex, arrays[i].length);
            currentIndex += arrays[i].length;
        }
    }

    return result;
}

/**
 * Concatenate multiple Byteable objects - null-safe version
 */
static byte[] safeConcat(Byteable... byteables) {
    if (byteables == null || byteables.length == 0) {
        return new byte[0];
    }
    
    // Count non-null elements and create array of byte arrays
    int nonNullCount = 0;
    for (Byteable b : byteables) {
        if (b != null) {
            nonNullCount++;
        }
    }
    
    byte[][] result = new byte[nonNullCount][];
    int i = 0;
    for (Byteable b : byteables) {
        if (b != null) {
            result[i] = b.bytes();
            i++;
        }
    }
    
    return safeConcat(result);
}
