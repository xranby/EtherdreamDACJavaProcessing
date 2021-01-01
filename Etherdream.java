
import java.io.*;
import java.net.*;
import java.util.Arrays;

public class Etherdream implements Runnable {

    public Etherdream() {
        Thread thread = new Thread(this);
        thread.start();
    }

    public static void main(String[] args) {
        Etherdream laser = new Etherdream();
        while (true) {
            try {
                Thread.sleep(4000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        }
    }
    
    enum State {
        GET_BROADCAST, KEEP_ALIVE_PING,
    }

    // https://ether-dream.com/protocol.html

    enum Command {
        PREPARE_STREAM(0x70), BEGIN_PLAYBACK(0x62), QUEUE_RATE_CHANGE(0x74), WRITE_DATA(0x64), STOP(0x73),
        EMERGENCY_STOP(0x00), EMERGENCY_STOP_ALTERNATIVE(0xFF), CLEAR_EMERGENCY_STOP(0x63), PING(0x3F),

        ACK_RESPONSE(0x61), NAK_FULL_RESPONSE(0x46), NAK_INVALID_RESPONSE(0x49), NAK_STOPCONDITION_RESPONSE(0x21);

        final byte command;

        private Command(int cmd) {
            command = (byte) (cmd & 0xFF);
        }

        public byte[] bytes() {
            return new byte[] { command };
        }

        public byte getCommand() {
            return command;
        }
    }

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


    @Override
    public void run() {
        State state = State.GET_BROADCAST;
        InetAddress etherdreamAddress = null;
        while (true) {
            System.out.println("state " + state);
            try {
                switch (state) {
                    case GET_BROADCAST: {
                        // Wait and get broadcast using UDP

                        try (DatagramSocket inSocket = new DatagramSocket(7654)) {

                            // get broadcast
                            byte[] buffer = new byte[512];
                            DatagramPacket response = new DatagramPacket(buffer, buffer.length);
                            inSocket.receive(response);
        
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
        
                            byte[] broadcast = Arrays.copyOfRange(buffer, 0, response.getLength());

                            etherdreamAddress = response.getAddress();
        
                            if (etherdreamAddress != null) {
                                state = State.KEEP_ALIVE_PING;
                            }

                        }

                        break;
                    }
                    case KEEP_ALIVE_PING: {
                        // Send ping using TCP port 7765
                        
                        try (Socket socket = new Socket(etherdreamAddress, 7765)) {
 
                            Thread.sleep(500);
                            Command cmd = Command.PING;
                            OutputStream output = socket.getOutputStream();
                            InputStream input = socket.getInputStream();
                            output.write(cmd.bytes());
                            
                            /*  
                             *  struct dac_response {
	                         *    uint8_t response;
	                         *    uint8_t command;
	                         *    struct status dac_status;
                             *  };  
                             */
                            
                            byte[] dac_response = input.readNBytes(3);

                            // make sure we got an ACK
                            if(dac_response[0]!=Command.ACK_RESPONSE.command){
                                state = State.GET_BROADCAST;
                                break;
                            }

                            // make sure we got the response form the PING command
                            if(dac_response[1]!=cmd.command){
                                state = State.GET_BROADCAST;
                                break;
                            }
                            /*
                             *   struct dac_status {
                             *       uint8_t protocol;
                             *       uint8_t light_engine_state;
                             *       uint8_t playback_state;
                             *       uint8_t source;
                             *       uint16_t light_engine_flags;
                             *       uint16_t playback_flags;
                             *       uint16_t source_flags;
                             *       uint16_t buffer_fullness;
                             *	    uint32_t point_rate;
                             *	    uint32_t point_count;
                             *   };
                             */
                            byte[] dac_status = input.readNBytes(20);

                        }

                        break;
                    }
                    default:
                        state = State.GET_BROADCAST;
                }
            } catch (Exception e) {
                /* If any IO error occour
                 * for any reason such as
                 * network cable disconnect
                 * then try locate the Etherdream DAC again
                 */ 
                state = State.GET_BROADCAST;
                System.out.println(e);
            }

        }
    }
}