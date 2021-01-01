
import java.io.*;
import java.net.*;

import se.zafena.util.ByteFormatter;

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
                // TODO Auto-generated catch block
                e.printStackTrace();
            }

        }
    }
    // https://ether-dream.com/protocol.html

    enum EtherdreamState {
        GET_BROADCAST, KEEP_ALIVE_PING,
    }

    enum EtherdreamCommand {
        PREPARE_STREAM(0x70), BEGIN_PLAYBACK(0x62), QUEUE_RATE_CHANGE(0x74), WRITE_DATA(0x64), STOP(0x73),
        EMERGENCY_STOP(0x00), CLEAR_EMERGENCY_STOP(0x63), PING(0x3F),

        ACK_RESPONSE(0x61), NAK_FULL_RESPONSE(0x46), NAK_INVALID_RESPONSE(0x49), NAK_STOPCONDITION_RESPONSE(0x21);

        final byte command;

        private EtherdreamCommand(int cmd) {
            command = (byte) (cmd & 0xFF);
        }

        public byte[] bytes() {
            return new byte[] { command };
        }

        public String toString() {
            return ByteFormatter.byteArrayToHexString(bytes());
        }
    }

    class EtherdreamInput implements Runnable {
        InetAddress etherdreamAddress = null;

        EtherdreamInput() {
            Thread thread = new Thread(this);
            thread.start();
        }

        @Override
        public void run() {
            while (true) {
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

                    byte[] data = ByteFormatter.getFirstBytes(buffer, response.getLength());
                    String quote = ByteFormatter.byteArrayToHexString(data);
                    System.out.println(quote);
                    System.out.println(response.getAddress().toString());
                    etherdreamAddress = response.getAddress();

                } catch (Exception e) {
                    System.out.println(e);
                }
            }
        }
    }

    @Override
    public void run() {

        EtherdreamInput input = new EtherdreamInput();

        EtherdreamState state = EtherdreamState.GET_BROADCAST;
        InetAddress etherdreamAddress = null;
        while (true) {
            System.out.println("state " + state);
            try (DatagramSocket outSocket = new DatagramSocket()) {

                switch (state) {
                    case GET_BROADCAST: {
                        Thread.sleep(10);
                        // get broadcast
                        etherdreamAddress = input.etherdreamAddress;
                        if (etherdreamAddress != null) {
                            state = EtherdreamState.KEEP_ALIVE_PING;
                        }

                        break;
                    }
                    case KEEP_ALIVE_PING: {
                        // Send ping
                        EtherdreamCommand cmd = EtherdreamCommand.PING;
                        System.out.println(cmd);
                        DatagramPacket request = new DatagramPacket(cmd.bytes(), cmd.bytes().length, etherdreamAddress,
                                7654);
                        outSocket.send(request);

                        // Get ACK
                        Thread.sleep(100);
                        state = EtherdreamState.KEEP_ALIVE_PING;

                        break;
                    }
                    default:
                        state = EtherdreamState.GET_BROADCAST;
                }
            } catch (Exception e) {
                state = EtherdreamState.GET_BROADCAST;
                System.out.println(e);
            }

        }
    }
}