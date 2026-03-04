package com.phoenix.client;

import android.util.Log;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.io.IOException;

public class VideoReceiver {
    private static final String TAG = "VideoReceiver";
    private static final int VIDEO_PORT = 5554;
    private static final int BUFFER_SIZE = 65535;
    private DatagramSocket socket;
    private boolean isRunning = false;
    private VideoDecoder decoder;

    public VideoReceiver(VideoDecoder decoder) {
        this.decoder = decoder;
    }

    public void start() throws IOException {
        if (isRunning) return;
        socket = new DatagramSocket(VIDEO_PORT);

        // KitKat optimization: non esagerare col buffer di sistema o accumula ritardo
        socket.setReceiveBufferSize(1024 * 1024);
        socket.setTrafficClass(0x10); // LOW DELAY

        isRunning = true;
        new Thread(new Runnable() {
            @Override
            public void run() {
                byte[] receiveBuffer = new byte[BUFFER_SIZE];
                while (isRunning) {
                    try {
                        DatagramPacket packet = new DatagramPacket(receiveBuffer, BUFFER_SIZE);
                        socket.receive(packet);
                        if (packet.getLength() > 0) {
                            byte[] data = new byte[packet.getLength()];
                            System.arraycopy(receiveBuffer, 0, data, 0, packet.getLength());
                            if (decoder != null) decoder.addPacket(data);
                        }
                    } catch (IOException e) {
                        if (isRunning) Log.e(TAG, "Recv err: " + e.getMessage());
                    }
                }
            }
        }, "VideoReceiverThread").start();
    }

    public void stop() {
        isRunning = false;
        if (socket != null) socket.close();
    }
}