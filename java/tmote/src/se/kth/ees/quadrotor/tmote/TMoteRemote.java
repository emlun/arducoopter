package se.kth.ees.quadrotor.tmote;

import java.awt.event.ActionEvent;
import java.awt.event.MouseEvent;
import java.awt.event.MouseListener;
import java.io.IOException;
import java.net.UnknownHostException;

import javax.swing.AbstractAction;
import javax.swing.BoxLayout;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JPanel;
import javax.swing.JSlider;
import javax.swing.border.TitledBorder;

public final class TMoteRemote extends JFrame implements Runnable, MouseListener {

    public static final short DESTINATION_MOTE_ID = 13;
    
    public static final int SLIDER_MIN_VALUE = 0;
    public static final int SLIDER_MAX_VALUE = 255;
    public static final long ARM_DISARM_DELAY = 2500;
    public static final long CALIBRATE_IMU_DELAY = 13000;
    
    public static final int MAX_LOITER = 48;
    public static final int MIN_LAND = -59 + 256;

    
    private static TMoteRemote theInstance;

    private TMoteConnection con;
    
    private JPanel upperButtonsPanel;
    private JPanel lowerButtonsPanel;
    
    private TMoteRemoteSlider[] channelSliders;
    
    private TMoteRemoteSlider rollSlider;
    private TMoteRemoteSlider pitchSlider;
    private TMoteRemoteSlider throttleSlider;
    private TMoteRemoteSlider yawSlider;
    private TMoteRemoteSlider modeSlider;
    
    private boolean[] centering = new boolean[]{true, true, false, true, false,
            false, false, false};

    byte[] payload = new byte[8];
    
    public static TMoteRemote getInstance() {
        if(theInstance == null) {
            theInstance = new TMoteRemote();
        }
        return theInstance;
    }

    @SuppressWarnings("serial")
    private TMoteRemote() {

        setTitle("Virtual 8ch Radio Controller");
        setDefaultCloseOperation(EXIT_ON_CLOSE);

        setLayout(new BoxLayout(getContentPane(), BoxLayout.Y_AXIS));
        
        upperButtonsPanel = new JPanel();
        upperButtonsPanel.setLayout(new BoxLayout(upperButtonsPanel, BoxLayout.X_AXIS));
        add(upperButtonsPanel);
        

        JPanel slidersPanel = new JPanel();
        slidersPanel.setLayout(new BoxLayout(slidersPanel, BoxLayout.X_AXIS));
        add(slidersPanel);
        
        lowerButtonsPanel = new JPanel();
        lowerButtonsPanel.setLayout(new BoxLayout(lowerButtonsPanel, BoxLayout.X_AXIS));
        add(lowerButtonsPanel);
        
        initializeSliders(slidersPanel);
        initializeButtons();
        centerSliders();

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

    private void initializeSliders(JPanel slidersPanel) {
        channelSliders = new TMoteRemoteSlider[8];
        for(int i = 0; i < 8; i++) {
            channelSliders[i] = new TMoteRemoteSlider(JSlider.VERTICAL, SLIDER_MIN_VALUE, SLIDER_MAX_VALUE, SLIDER_MIN_VALUE);
            channelSliders[i].addMouseListener(this);
            slidersPanel.add(channelSliders[i]);

            channelSliders[i].setBorder(new TitledBorder("" + (i + 1)));
            channelSliders[i].setMajorTickSpacing(50);
            channelSliders[i].setMinorTickSpacing(5);
            channelSliders[i].setPaintTicks(true);
            channelSliders[i].setPaintLabels(true);
        }
        
        rollSlider = channelSliders[0];
        pitchSlider = channelSliders[1];
        throttleSlider = channelSliders[2];
        yawSlider = channelSliders[3];
        modeSlider = channelSliders[4];
    }

    @SuppressWarnings("serial")
    private void initializeButtons() {
        upperButtonsPanel.add(new JButton(new AbstractAction("Arm motors") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                throttleSlider.holdValueFor(SLIDER_MIN_VALUE, ARM_DISARM_DELAY);
                rollSlider.holdValueFor(SLIDER_MAX_VALUE, ARM_DISARM_DELAY);
            }
        }));
        
        upperButtonsPanel.add(new JButton(new AbstractAction("Disarm motors") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                throttleSlider.holdValueFor(SLIDER_MIN_VALUE, ARM_DISARM_DELAY);
                rollSlider.holdValueFor(SLIDER_MIN_VALUE, ARM_DISARM_DELAY);
            }
        }));
        
        upperButtonsPanel.add(new JButton(new AbstractAction("Calibrate IMU") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                throttleSlider.holdValueFor(SLIDER_MIN_VALUE, CALIBRATE_IMU_DELAY);
                rollSlider.holdValueFor(SLIDER_MIN_VALUE, CALIBRATE_IMU_DELAY);
            }
        }));
        
        lowerButtonsPanel.add(new JButton(new AbstractAction("Stabilize") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                modeStabilize();
            }
        }));
        lowerButtonsPanel.add(new JButton(new AbstractAction("Land") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                modeLand();
            }
        }));
        lowerButtonsPanel.add(new JButton(new AbstractAction("Loiter") {
            @Override
            public void actionPerformed(ActionEvent arg0) {
                modeLoiter();
            }
        }));
    }

    public static void main(String[] args) {
        TMoteRemote.getInstance();
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

    public void centerSliders() {
        for(int i = 0; i < 8; i++) {
            if(centering[i] && channelSliders[i].isEnabled()) {
                channelSliders[i].setValue(127);
            }
        }
    }
    
    public void modeStabilize() {
        modeSlider.setValue((SLIDER_MAX_VALUE + SLIDER_MIN_VALUE)/2);
    }
    
    public void modeLand() {
        modeSlider.setValue(SLIDER_MIN_VALUE);
    }
    
    public void modeLoiter() {
        modeSlider.setValue(SLIDER_MAX_VALUE);
    }
    
    @Override
    public void mouseReleased(MouseEvent event) {
        centerSliders();
    }

}
