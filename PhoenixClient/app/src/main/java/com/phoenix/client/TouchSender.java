package com.phoenix.client;

import android.util.Log;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.io.IOException;

/**
 * Touch event sender using UDP
 * Sends 12-byte packets to Mac server
 * Format (Little Endian):
 * - X: UInt16 (0-1023)
 * - Y: UInt16 (0-767)
 * - Action: UInt8 (1=down, 2=move, 3=up)
 * - Pressure: UInt8 (0-255)
 * - Padding: UInt8
 * - Timestamp: UInt32 (ms)
 */
public class TouchSender {
    private static final String TAG = "TouchSender";
    private static final int TOUCH_PORT = 5555;
    private static final int PACKET_SIZE = 12;

    private DatagramSocket socket;
    private InetAddress serverAddress;
    private boolean isConnected = false;
    private Thread senderThread;
    private volatile boolean isRunning = false;

    // Touch event data (12 bytes)
    private byte[] packetData = new byte[PACKET_SIZE];
    private int x, y, action;
    private float pressure = 1.0f;
    private long timestamp;

    // Connection state
    private String serverIP = "255.255.255.255";

    public TouchSender() {
    }

    /**
     * Connect to Mac server
     */
    public void connect(String ip) throws IOException {
        if (isConnected) return;

        serverIP = ip;
        serverAddress = InetAddress.getByName(serverIP);
        
        socket = new DatagramSocket();
        socket.setBroadcast(true);
        
        isConnected = true;
        isRunning = true;
        
        Log.d(TAG, "Connected to " + serverIP + ":" + TOUCH_PORT);
    }

    /**
     * Disconnect from server
     */
    public void disconnect() {
        isRunning = false;
        isConnected = false;
        
        if (socket != null) {
            socket.close();
            socket = null;
        }
        
        Log.d(TAG, "Disconnected");
    }

    /**
     * Send touch down event
     */
    public void touchDown(int x, int y) {
        this.x = x;
        this.y = y;
        this.action = 1;
        this.timestamp = System.currentTimeMillis();
        sendTouchEvent();
    }

    /**
     * Send touch move event
     */
    public void touchMove(int x, int y) {
        this.x = x;
        this.y = y;
        this.action = 2;
        this.timestamp = System.currentTimeMillis();
        sendTouchEvent();
    }

    /**
     * Send touch up event
     */
    public void touchUp() {
        this.action = 3;
        this.timestamp = System.currentTimeMillis();
        sendTouchEvent();
    }

    /**
     * Send touch event via UDP (Little Endian)
     */
    private void sendTouchEvent() {
        if (!isConnected || socket == null) return;

        try {
            // Build packet in Little Endian format
            packetData[0] = (byte) (x & 0xFF);
            packetData[1] = (byte) ((x >> 8) & 0xFF);
            packetData[2] = (byte) (y & 0xFF);
            packetData[3] = (byte) ((y >> 8) & 0xFF);
            packetData[4] = (byte) action;
            packetData[5] = (byte) (pressure * 255);
            packetData[6] = 0; // padding
            packetData[7] = (byte) (timestamp & 0xFF);
            packetData[8] = (byte) ((timestamp >> 8) & 0xFF);
            packetData[9] = (byte) ((timestamp >> 16) & 0xFF);
            packetData[10] = (byte) ((timestamp >> 24) & 0xFF);
            packetData[11] = 0; // padding

            DatagramPacket packet = new DatagramPacket(
                packetData, PACKET_SIZE, serverAddress, TOUCH_PORT);
            
            socket.send(packet);
            
        } catch (IOException e) {
            Log.e(TAG, "Failed to send touch event", e);
        }
    }

    /**
     * Set pressure
     */
    public void setPressure(float pressure) {
        this.pressure = Math.max(0, Math.min(1, pressure));
    }
}
