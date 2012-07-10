package se.kth.ees.quadrotor.tmote;

import javax.swing.JSlider;

@SuppressWarnings("serial")
public class TMoteRemoteSlider extends JSlider implements Runnable {

    private int heldValue;
    private long millisToHold;

    public TMoteRemoteSlider(int orientation, int min, int max, int value) {
        super(orientation, min, max, value);
    }

    @Override
    public void setValue(int value) {
        if(isEnabled()) {
            super.setValue(value);
        }
    }

    @Override
    public int getValue() {
        if(millisToHold > 0) {
            return heldValue;
        }
        return super.getValue();
    }

    public void holdValueFor(int value, long millis) {
        if(millisToHold <= 0) {
            setValue(value);
            heldValue = value;
            setEnabled(false);
            millisToHold = millis;

            new Thread(this).start();
        }
    }

    @Override
    public void run() {
        try {
            Thread.sleep(millisToHold);
        } catch(InterruptedException e) {
            e.printStackTrace();
        }
        setEnabled(true);
        millisToHold = 0;
        TMoteRemote.getInstance().centerSliders();
    }

}
