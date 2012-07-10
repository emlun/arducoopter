package se.kth.ees.quadrotor.tmote;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.Socket;
import java.net.SocketException;
import java.net.UnknownHostException;

public class TMoteConnection {

    public static final long MILLIS_BETWEEN_MESSAGES = 100;

    private Socket socket;
    private OutputStream out;

    private long lastSendTime = System.currentTimeMillis();

    public TMoteConnection(InetAddress address, int port) throws IOException {

        try {
            socket = new Socket(address, port);
        } catch(IOException e) {
            e.printStackTrace();
            throw e;
        }

        try {
            out = socket.getOutputStream();

            // Handshake
            out.write(85);
            out.write(32);
            out.flush();

        } catch(IOException e) {
            e.printStackTrace();
            throw e;
        }

        new Thread() {

            @Override
            public void run() {
                InputStream i = null;
                try {
                    i = socket.getInputStream();
                } catch(IOException e) {
                    e.printStackTrace();
                    return;
                }
                while(true) {
                    try {
                        int r = i.read();
                        System.out.println("Received " + r);
                    } catch(SocketException e) {
                        System.out.println("SerialForwarder died. EXITING.");
                        return;
                    } catch(IOException e) {
                        e.printStackTrace();
                        return;
                    }
                }
            }
        }.start();

    }

    public TMoteConnection() throws UnknownHostException, IOException {
        this(InetAddress.getLocalHost(), 9002);
    }

    public boolean isReady() {
        return System.currentTimeMillis() - lastSendTime >= MILLIS_BETWEEN_MESSAGES;
    }

    /**
     * 
     * Attempts to send the given payload, but with a cooldown time.
     * 
     * @param destinationMoteId
     * @param payload
     * @return <code>true</code> if message was sent, <code>false</code>
     *         otherwise.
     */
    public boolean sendPayload(short destinationMoteId, byte[] payload) {
        if(isReady()) {

            TMoteDataPacket tdp =
                    new TMoteDataPacket(destinationMoteId, payload);

            try {

                out.write(tdp.getDataPacket());
                out.flush();

                System.out.println("Sent " + tdp);

            } catch(IOException e) {
                System.err.println("Failed to write payload " + tdp);
                e.printStackTrace();
            }

            lastSendTime = System.currentTimeMillis();

            return true;
        }
        return false;
    }

}
