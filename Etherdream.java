
import java.io.*;
import java.net.*;
import java.util.Arrays;

import se.zafena.util.ByteFormatter;
import java.nio.ByteBuffer;

public class Etherdream implements Runnable {

    // superbobs toBytes https://gist.github.com/superbob/6548493

    /**
     * Shorthand method to init a byte array from an char.<br>
     * Usefull to get a
     * <code>new byte[] { (byte) 0x01, (byte) 0x02 }</code>
     * from a <code>0x0102</code>.<br>
     * Usage: <code>byte[] array = toBytes(0x0102);</code><br>
     * It works for 2 bytes arrays (char).<br>
     * It works for any multiple of 2 bytes arrays.<br>
     * Ex: <code>byte[] longArray = toBytes(0x0102, 0xAABB, 0x1112)</code>
     * 
     * @param charVal first int to convert in the resulting array (4 bytes), mandatory
     * @param charArray additional ints to add to the array (any more 4 bytes ints)
     * @return the resulting byte array
     */
    public static byte[] toBytes(final char charVal, final char... charArray) {
        if (charArray == null || (charArray.length == 0)) {
            return ByteBuffer.allocate(2).putChar(charVal).array();
        } else {
            final ByteBuffer bb = ByteBuffer.allocate(2 + (charArray.length * 2)).putChar(charVal);
            for (final char val : charArray) {
                bb.putChar(val);
            }
            return bb.array();
        }
    }

    /**
     * Shorthand method to init a byte array from an int.<br>
     * Usefull to get a
     * <code>new byte[] { (byte) 0x01, (byte) 0x02, (byte) 0x03, (byte) 0x04 }</code>
     * from a <code>0x01020304</code>.<br>
     * Usage: <code>byte[] array = toBytes(0x01020304);</code><br>
     * It works for 4 bytes arrays (int).<br>
     * It works for any multiple of 4 bytes arrays.<br>
     * Ex: <code>byte[] longArray = toBytes(0x01020304, 0xAABBCCDD, 0x11121314)</code>
     * 
     * @param intVal first int to convert in the resulting array (4 bytes), mandatory
     * @param intArray additional ints to add to the array (any more 4 bytes ints)
     * @return the resulting byte array
     */
    public static byte[] toBytes(final int intVal, final int... intArray) {
        if (intArray == null || (intArray.length == 0)) {
            return ByteBuffer.allocate(4).putInt(intVal).array();
        } else {
            final ByteBuffer bb = ByteBuffer.allocate(4 + (intArray.length * 4)).putInt(intVal);
            for (final int val : intArray) {
                bb.putInt(val);
            }
            return bb.array();
        }
    }

    /**
     * Shorthand method to init a byte array from a short.<br>
     * Usefull to get a
     * <code>new byte[] { (byte) 0x01, (byte) 0x02 }</code>
     * from a <code>0x0102</code>.<br>
     * Usage: <code>byte[] array = toBytes((short) 0x0102);</code><br>
     * Warning: If the literal is not cast to short, it will be treated as an int, resulting in the call to the {@link #toBytes(int, int...)} method and generating a 4 bytes buffer instead of a 2 bytes buffer.<br>
     * It works for 2 bytes arrays (short).<br>
     * It works for any multiple of 2 bytes arrays.<br>
     * Ex: <code>byte[] longArray = toBytes(0x0102, 0xAABB, 0x1112)</code>
     * 
     * @param shortVal first short to convert in the resulting array (2 bytes), mandatory
     * @param shortArray additional shorts to add to the array (any more 2 bytes shorts)
     * @return the resulting byte array
     */
    public static byte[] toBytes(final short shortVal, final short... shortArray) {
        if (shortArray == null || (shortArray.length == 0)) {
            return ByteBuffer.allocate(2).putShort(shortVal).array();
        } else {
            final ByteBuffer bb = ByteBuffer.allocate(2 + (shortArray.length * 2)).putShort(shortVal);
            for (final short val : shortArray) {
                bb.putShort(val);
            }
            return bb.array();
        }
    }

    /**
     * Shorthand method to init a byte array from a long.<br>
     * Usefull to get a
     * <code>new byte[] { (byte) 0x01, (byte) 0x02, (byte) 0x03, (byte) 0x04, (byte) 0x05, (byte) 0x06, (byte) 0x07, (byte) 0x08 }</code>
     * from a <code>0x0102030405060708L</code>.<br>
     * Usage: <code>byte[] array = toBytes(0x0102030405060708L);</code><br>
     * It works for 8 bytes arrays (long).<br>
     * It works for any multiple of 8 bytes arrays.<br>
     * Ex: <code>byte[] longArray = toBytes(0x0102030405060708L, 0xAABBCCDDEEFF0011L)</code>
     * 
     * @param intVal first long to convert in the resulting array (8 bytes), mandatory
     * @param intArray additional longs to add to the array (any more 8 bytes longs)
     * @return the resulting byte array
     */
    public static byte[] toBytes(final long longVal, final long... longArray) {
        if (longArray == null || (longArray.length == 0)) {
            return ByteBuffer.allocate(8).putLong(longVal).array();
        } else {
            final ByteBuffer bb = ByteBuffer.allocate(8 + (longArray.length * 8)).putLong(longVal);
            for (final long val : longArray) {
                bb.putLong(val);
            }
            return bb.array();
        }
    }

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
        byte[] p;

        DACPoint(){
            p = new byte[18];
        }

        DACPoint(int x, int y, int r, int g, int b){
            p = toBytes((char)0x0, (char)x, (char)y, (char)r, (char)g, (char)b, (char)0x0, (char)0x0 ,(char)0x0);
        }

        DACPoint(int x, int y){
            p = toBytes((char)0x0, (char)x, (char)y, (char)65536, (char)65536, (char)65536, (char)0x0, (char)0x0 ,(char)0x0);
        }

        /*
         * struct dac_point { uint16_t control; int16_t x; int16_t y; uint16_t r;
         * uint16_t g; uint16_t b; uint16_t i; uint16_t u1; uint16_t u2; };
         */
        public byte[] bytes() {
            return p;
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
                        write(Command.WRITE_DATA.bytes(new DACPoint[]{new DACPoint(10,10),new DACPoint(-10,-10)}));
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