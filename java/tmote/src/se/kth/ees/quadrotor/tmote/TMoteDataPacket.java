package se.kth.ees.quadrotor.tmote;


public class TMoteDataPacket {
    
    private static final byte METADATA_LENGTH = 10;
    
    private short destinationMoteId;
    private byte[] payload;
    private byte[] dataPacket;
    
    public TMoteDataPacket(short destinationMoteId, byte[] payload) {
        this.destinationMoteId = destinationMoteId;
        this.payload = payload;
        
        dataPacket = new byte[METADATA_LENGTH + payload.length];
        
        dataPacket[0] = (byte) (METADATA_LENGTH-1 + payload.length);
        dataPacket[1] = 0;                                  // 0 in LabView
        
        dataPacket[2] = (byte) (destinationMoteId/256);     // High part of destination mote id [uint16] 
        dataPacket[3] = (byte) (destinationMoteId%256);     // Low part of destination mote id [uint16] 
        
        dataPacket[4] = 0;                                  // High part of 1 [uint16]
        dataPacket[5] = 1;                                  // Low part of 1 [uint16]
        
        dataPacket[6] = (byte) (payload.length + 1);              // Payload length
        
        dataPacket[7] = 0;                                  // GroupId 0
        
        dataPacket[8] = 6;                                  // 6 from LabView
        
        dataPacket[9] = 1;                                  // MsgType 1
        
        for(int i=0; i<payload.length; i++) {
            dataPacket[i+METADATA_LENGTH] = payload[i];
        }
        
    }
    
    public byte[] getDataPacket() {
        return dataPacket.clone();
    }
    
    @Override
    public String toString() {
        StringBuffer result = new StringBuffer("{");
        result.append(destinationMoteId);
        result.append(": [");
        
        result.append(payload[0]);
        for(int i=1; i<payload.length; i++) {
            result.append(", ");
            result.append(payload[i]);
        }
        result.append("]");
        result.append("}");
        return result.toString();
    }

}
