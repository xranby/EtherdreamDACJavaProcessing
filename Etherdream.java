
import java.io.*;
import java.net.*;
import java.util.Arrays;

import se.zafena.util.ByteFormatter;

public class Etherdream implements Runnable {

    // Wayne Uroda's byte concat
    // https://stackoverflow.com/questions/5513152/easy-way-to-concatenate-two-byte-arrays/12141556#12141556
    static byte[] concat(byte[]... arrays) {
        // Determine the length of the result array
        int totalLength = 0;
        for (int i = 0; i < arrays.length; i++) {
            totalLength += arrays[i].length;
        }

        // create the result array
        byte[] result = new byte[totalLength];

        // copy the source arrays into the result array
        int currentIndex = 0;
        for (int i = 0; i < arrays.length; i++) {
            System.arraycopy(arrays[i], 0, result, currentIndex, arrays[i].length);
            currentIndex += arrays[i].length;
        }

        return result;
    }

    interface Byteable {
        public byte[] bytes();
    }

    static byte[] concat(Byteable... arrays) {
        byte[][] result = new byte[arrays.length][];
        int i = 0;
        for(Byteable a:arrays){
            result[i]=a.bytes();
            i++;
        }
        return concat(result);
    }

    final Thread thread;
    public Etherdream() {
        thread = new Thread(this);
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
        GET_BROADCAST, KEEP_ALIVE_PING, WRITE_DATA,
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

        public byte[] bytes(DACPoint p) {
            return concat(bytes(), new byte[]{(byte)1} , p.bytes());
        }

        public byte[] bytes(DACPoint[] p) {

            byte[] pb = concat(p);
            return concat(bytes(), new byte[]{(byte)p.length} , pb);
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

    public class DACPoint implements Byteable {
        byte[] b = new byte[18];

        /*
         * struct dac_point { uint16_t control; int16_t x; int16_t y; uint16_t r;
         * uint16_t g; uint16_t b; uint16_t i; uint16_t u1; uint16_t u2; };
         */
        public byte[] bytes() {
            return b;
        }
    }

    public void write(byte[] data){
        outputBytes = data;
        state = State.WRITE_DATA;
    }


    volatile State state = State.GET_BROADCAST;
    volatile byte[] outputBytes = {};
    @Override
    public void run() {
        InetAddress etherdreamAddress = null;
        while (true) {
            System.out.println("state " + state);
            try {
                try{
                Thread.sleep(500);
                } catch (InterruptedException e){}
                switch (state) {
                    case GET_BROADCAST: {
                        // Wait and get broadcast using UDP

                        try (DatagramSocket inSocket = new DatagramSocket(7654)) {

                            // get broadcast
                            byte[] buffer = new byte[512];
                            DatagramPacket response = new DatagramPacket(buffer, buffer.length);
                            inSocket.receive(response);

                            /*
                             * struct j4cDAC_broadcast { uint8_t mac_address[6]; uint16_t hw_revision;
                             * uint16_t sw_revision; uint16_t buffer_capacity; uint32_t max_point_rate;
                             * struct dac_status status; };
                             */

                            byte[] broadcast = Arrays.copyOfRange(buffer, 0, response.getLength());
                            System.out.println(ByteFormatter.byteArrayToHexString(broadcast));

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

                            Command cmd = Command.PING;
                            OutputStream output = socket.getOutputStream();
                            InputStream input = socket.getInputStream();
                            output.write(cmd.bytes());

                            /*
                             * struct dac_response { uint8_t response; uint8_t command; struct status
                             * dac_status; };
                             */

                            byte[] dac_response = input.readNBytes(3);

                            System.out.println(ByteFormatter.byteArrayToHexString(dac_response));

                            // make sure we got an ACK
                            if (dac_response[0] != Command.ACK_RESPONSE.command) {
                                state = State.GET_BROADCAST;
                                break;
                            }

                            // make sure we got the response form the PING command
                            if (dac_response[1] != cmd.command) {
                                state = State.GET_BROADCAST;
                                break;
                            }

                            /*
                             * struct dac_status { uint8_t protocol; uint8_t light_engine_state; uint8_t
                             * playback_state; uint8_t source; uint16_t light_engine_flags; uint16_t
                             * playback_flags; uint16_t source_flags; uint16_t buffer_fullness; uint32_t
                             * point_rate; uint32_t point_count; };
                             */
                            byte[] dac_status = input.readNBytes(20);

                        }
                        write(Command.WRITE_DATA.bytes(new DACPoint[]{new DACPoint(),new DACPoint()}));
                        break;
                    }
                    case WRITE_DATA: {

                        try (Socket socket = new Socket(etherdreamAddress, 7765)) {
                            OutputStream output = socket.getOutputStream();
                            InputStream input = socket.getInputStream();

                            System.out.println(ByteFormatter.byteArrayToHexString(outputBytes));
                            output.write(outputBytes);

                            /*
                             * struct dac_response { uint8_t response; uint8_t command; struct status
                             * dac_status; };
                             */

                            byte[] dac_response = input.readNBytes(3);

                            System.out.println(ByteFormatter.byteArrayToHexString(dac_response));

                            // make sure we got an ACK
                            if (dac_response[0] != Command.ACK_RESPONSE.command) {
                                state = State.GET_BROADCAST;
                                break;
                            }

                            // make sure we got the response form the PING command
                            if (dac_response[1] != outputBytes[0]) {
                                state = State.GET_BROADCAST;
                                break;
                            }

                            /*
                             * struct dac_status { uint8_t protocol; uint8_t light_engine_state; uint8_t
                             * playback_state; uint8_t source; uint16_t light_engine_flags; uint16_t
                             * playback_flags; uint16_t source_flags; uint16_t buffer_fullness; uint32_t
                             * point_rate; uint32_t point_count; };
                             */
                            byte[] dac_status = input.readNBytes(20);

                        }

                        break;
                    }
                    default:
                        state = State.GET_BROADCAST;
                }
            } catch (Exception e) {
                /*
                 * If any IO error occour for any reason such as network cable disconnect then
                 * try locate the Etherdream DAC again
                 */
                state = State.GET_BROADCAST;
                System.out.println(e);
            }

        }
    }
}