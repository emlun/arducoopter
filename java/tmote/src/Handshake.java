import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.Socket;
import java.net.UnknownHostException;
import java.util.Random;



public class Handshake {
    
    public static void main(String[] args) throws UnknownHostException, IOException {
        final Socket s = new Socket("localhost", 9002);
        OutputStream o = s.getOutputStream();
        
        Random r = new Random();
        for(int i=0; i<2; i++) {
            int rand = r.nextInt(128);
            System.out.println("Sending " + rand);
            o.write(rand);
        }
        o.flush();
        
        new Thread() {
            @Override
            public void run() {
                InputStream i = null;
                try {
                    i = s.getInputStream();
                } catch(IOException e) {
                    e.printStackTrace();
                    return;
                }
                while(true) {
                    try {
                        System.out.println("Received " + i.read());
                    } catch(IOException e) {
                        e.printStackTrace();
                        return;
                    }
                }
            }
        }.start();

        while(true) {
            int in = System.in.read();
            System.out.println("Sending " + in);
            o.write(in);
            o.flush();
        }
        
    }

}
