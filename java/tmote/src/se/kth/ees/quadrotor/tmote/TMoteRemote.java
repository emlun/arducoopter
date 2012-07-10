package se.kth.ees.quadrotor.tmote;

import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.io.IOException;
import java.net.UnknownHostException;

import javax.swing.BoxLayout;
import javax.swing.JFrame;
import javax.swing.JSlider;
import javax.swing.border.TitledBorder;

public class TMoteRemote extends JFrame implements Runnable, MouseListener {

    public static final short DESTINATION_MOTE_ID = 13;

    private TMoteConnection con;
    private JSlider[] channelSliders;
    private boolean[] centering = new boolean[]{true, true, false, true, false,
            false, false, false};

    byte[] payload = new byte[8];

    public TMoteRemote() {

        setTitle("Virtual 8ch Radio Controller");
        setDefaultCloseOperation(EXIT_ON_CLOSE);

        setLayout(new BoxLayout(getContentPane(), BoxLayout.X_AXIS));

        channelSliders = new JSlider[8];
        for(int i = 0; i < 8; i++) {
            channelSliders[i] = new JSlider(JSlider.VERTICAL, 0, 255, 0);
            channelSliders[i].addMouseListener(this);
            add(channelSliders[i]);

            channelSliders[i].setBorder(new TitledBorder("" + (i + 1)));
            channelSliders[i].setMajorTickSpacing(50);
            channelSliders[i].setMinorTickSpacing(5);
            channelSliders[i].setPaintTicks(true);
            channelSliders[i].setPaintLabels(true);
        }

        mouseReleased(null);

        try {
            con = new TMoteConnection();
        } catch(UnknownHostException e) {
            e.printStackTrace();
        } catch(IOException e) {
            e.printStackTrace();
        }

        pack();
        setVisible(true);
        
        new Thread(this).start();

    }

    public static void main(String[] args) {
        new TMoteRemote();
    }
    
    private void sendPayload() {
        if(con.isReady()) {
            for(int i = 0; i < 8; i++) {
                payload[i] = (byte) (channelSliders[i].getValue());
            }
            con.sendPayload(DESTINATION_MOTE_ID, payload);
        }
    }
    
    @Override
    public void run() {
        while(true) {
            sendPayload();

            try {
                Thread.sleep(98);
            } catch(InterruptedException e) {
                e.printStackTrace();
            }
        }
    }

    @Override public void mouseClicked(MouseEvent arg0) {}
    @Override public void mouseEntered(MouseEvent arg0) {}
    @Override public void mouseExited(MouseEvent arg0) {}
    @Override public void mousePressed(MouseEvent arg0) {}

    @Override
    public void mouseReleased(MouseEvent event) {
        for(int i = 0; i < 8; i++) {
            if(centering[i]) {
                channelSliders[i].setValue(127);
            }
        }
    }

}
