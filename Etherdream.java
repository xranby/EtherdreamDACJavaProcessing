
import java.io.*;
import java.net.*;
import java.util.Arrays;

import se.zafena.util.ByteFormatter;
import java.nio.ByteBuffer;

public class Etherdream implements Runnable {

    public static byte[] toBytes(final char... charArray) {
        final ByteBuffer bb = ByteBuffer.allocate(2 + (charArray.length * 2));
        for (final char val : charArray) {
            bb.putChar(val);
        }
        return bb.array();
    }

    public static byte[] toBytes(final int... intArray) {
        final ByteBuffer bb = ByteBuffer.allocate(4 + (intArray.length * 4));
        for (final int val : intArray) {
            bb.putInt(val);
        }
        return bb.array();
    }

    public static byte[] toBytes(final short... shortArray) {
        final ByteBuffer bb = ByteBuffer.allocate(2 + (shortArray.length * 2));
        for (final short val : shortArray) {
            bb.putShort(val);
        }
        return bb.array();
    }

    public static byte[] toBytes(final long... longArray) {
        final ByteBuffer bb = ByteBuffer.allocate(8 + (longArray.length * 8));
        for (final long val : longArray) {
            bb.putLong(val);
        }
        return bb.array();
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
        for (Byteable a : arrays) {
            result[i] = a.bytes();
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
        GET_BROADCAST, INIT, WRITE_DATA, BEGIN_PLAYBACK, IDLE;
    }

    // https://ether-dream.com/protocol.html

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
                    return concat(bytes(), toBytes((short) data[0]), toBytes(data[1]));
                default:
                    return concat(bytes(), toBytes(data));
            }

        }

        public byte[] bytes(int lowWaterMark, int pointRate) {
            byte[] w = concat(bytes(), toBytes((short) lowWaterMark), toBytes(pointRate));
            return w;
        }

        public byte[] bytes(DACPoint p) {
            return concat(bytes(), toBytes((short) 1), p.bytes());
        }

        public byte[] bytes(DACPoint[] p) {

            byte[] pb = concat(p);
            byte[] w = concat(bytes(), toBytes((short) p.length), pb);
            return w;
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

        DACPoint() {
            p = new byte[18];
        }

        DACPoint(int x, int y, int r, int g, int b) {
            p = toBytes((char) 0x0, (char) x, (char) y, (char) r, (char) g, (char) b, (char) 0x0, (char) 0x0,
                    (char) 0x0);
        }

        DACPoint(int x, int y) {
            p = toBytes((char) 0x0, (char) x, (char) y, (char) 65536, (char) 65536, (char) 65536, (char) 0x0,
                    (char) 0x0, (char) 0x0);
        }

        /*
         * struct dac_point { uint16_t control; int16_t x; int16_t y; uint16_t r;
         * uint16_t g; uint16_t b; uint16_t i; uint16_t u1; uint16_t u2; };
         */
        public byte[] bytes() {
            return p;
        }
    }

    volatile State state = State.GET_BROADCAST;
    OutputStream output = null;
    InputStream input = null;

    void write(Command cmd) throws IOException {
        switch (cmd) {
            case VERSION:
                System.out.println(((char) cmd.command));
                output.write(cmd.bytes());
                byte[] version = input.readNBytes(32);
                String versionString = new String(version).replace("\0", "").strip();
                System.out.println("Version: " + versionString);
                break;
            default:
                System.out.println(((char) cmd.command));
                output.write(cmd.bytes());
                readResponse(cmd);
        }
    }

    void write(Command cmd, int... data) throws IOException {
        System.out.println(((char) cmd.command));
        output.write(cmd.bytes(data));
        readResponse(cmd);
    }

    void write(Command cmd, DACPoint... data) throws IOException {
        System.out.println(((char) cmd.command));
        output.write(cmd.bytes(data));
        readResponse(cmd);
    }

    void readResponse(Command cmd) throws IOException {
        /*
         * struct dac_response { uint8_t response; uint8_t command; struct status
         * dac_status; };
         *
         * struct dac_status { uint8_t protocol; uint8_t light_engine_state; uint8_t
         * playback_state; uint8_t source; uint16_t light_engine_flags; uint16_t
         * playback_flags; uint16_t source_flags; uint16_t buffer_fullness; uint32_t
         * point_rate; uint32_t point_count; };
         */

        byte[] dac_response = input.readNBytes(22);

        System.out.println(((char) cmd.command) + " " + ByteFormatter.byteArrayToHexString(dac_response));

        // make sure we got an ACK
        if (dac_response[0] != Command.ACK_RESPONSE.command) {
            state = State.GET_BROADCAST;
        }

        // make sure we got the response for current command
        if (dac_response[1] != cmd.command) {
            state = State.GET_BROADCAST;
        }
    }

    @Override
    public void run() {
        InetAddress etherdreamAddress = null;

        Socket socket = null;

        boolean readTwice = false;

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
                             * struct j4cDAC_broadcast { uint8_t mac_address[6]; uint16_t hw_revision;
                             * uint16_t sw_revision; uint16_t buffer_capacity; uint32_t max_point_rate;
                             * struct dac_status status; };
                             */

                            byte[] broadcast = Arrays.copyOfRange(buffer, 0, response.getLength());
                            System.out.println(ByteFormatter.byteArrayToHexString(broadcast));

                            etherdreamAddress = response.getAddress();

                            if (etherdreamAddress != null) {
                                if (socket != null) {
                                    try {
                                        socket.close();
                                        socket = null;
                                    } catch (IOException e1) {
                                        // TODO Auto-generated catch block
                                        e1.printStackTrace();
                                    }
                                }
                                socket = new Socket(etherdreamAddress, 7765);

                                output = socket.getOutputStream();
                                input = socket.getInputStream();
                                state = State.INIT;

                                // When a host first connects to the device, the device immediately sends it a
                                // status reply, as if the host had sent a ping packet
                                readResponse(Command.PING);
                            }

                        }

                        break;
                    }
                    case INIT: {
                        // Send ping using TCP port 7765
                        write(Command.PING);

                        write(Command.VERSION);

                        write(Command.CLEAR_EMERGENCY_STOP);

                        write(Command.PREPARE_STREAM);

                        state = State.WRITE_DATA;
                        break;
                    }
                    case WRITE_DATA: {
                        write(Command.WRITE_DATA, getFrame());
                        state = State.BEGIN_PLAYBACK;
                        break;
                    }
                    case BEGIN_PLAYBACK: {
                        write(Command.BEGIN_PLAYBACK, 0, 24000);
                        state = State.WRITE_DATA;
                        break;
                    }
                    case IDLE:
                        output.write(Command.WRITE_DATA.bytes(getFrame()));
                        output.flush();
                        byte[] dac_status = input.readNBytes(22);

                        break;
                    default:
                        state = State.GET_BROADCAST;
                }
            } catch (Exception e) {
                /*
                 * If any IO error occour for any reason such as network cable disconnect then
                 * try locate the Etherdream DAC again
                 */

                state = State.GET_BROADCAST;
                e.printStackTrace();
            }

        }
    }

    DACPoint[] getFrame() {
        DACPoint[] result = new DACPoint[2000];
        for (int i = 0; i < 2000; i++) {
            result[i] = new DACPoint((int) (65534 * Math.sinh(i / 24000.0)), (int) (65534 * Math.cos(i / 24000.0)),
                    10000, 0, 0);
        }
        return result;
    }
}