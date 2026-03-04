package com.phoenix.client;

import android.media.MediaCodec;
import android.media.MediaFormat;
import android.view.Surface;
import android.util.Log;
import java.io.IOException;
import java.nio.ByteBuffer;

public class VideoDecoder {
    private static final String TAG = "VideoDecoder";
    private static final String MIME_TYPE = "video/avc";
    private MediaCodec codec;
    private Surface surface;
    private volatile boolean isRunning = false;
    private Thread decoderThread;

    private byte[] latestPacket = null;
    private final Object packetLock = new Object();

    public VideoDecoder(Surface surface) {
        this.surface = surface;
    }

    public synchronized void start() throws IOException {
        if (isRunning) return;
        codec = MediaCodec.createDecoderByType(MIME_TYPE);
        MediaFormat format = MediaFormat.createVideoFormat(MIME_TYPE, 1024, 768);

        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 1024 * 768);
        format.setInteger("low-latency", 1);
        format.setInteger("vendor.mtk-vdec-lowlatency", 1);

        codec.configure(format, surface, null, 0);
        codec.start();

        isRunning = true;
        decoderThread = new Thread(new DecoderRunnable(), "VideoDecoderThread");
        decoderThread.setPriority(Thread.MAX_PRIORITY);
        decoderThread.start();
    }

    public void addPacket(byte[] data) {
        synchronized (packetLock) {
            // L'unico pacchetto che conta è l'ultimo ricevuto.
            latestPacket = data;
        }
    }

    private class DecoderRunnable implements Runnable {
        @Override
        @SuppressWarnings("deprecation")
        public void run() {
            MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
            ByteBuffer[] inputBuffers = codec.getInputBuffers();
            boolean waitingForConfig = true;

            while (isRunning) {
                try {
                    byte[] packet = null;
                    synchronized (packetLock) {
                        packet = latestPacket;
                        latestPacket = null; // Consumato
                    }

                    if (packet != null) {
                        if (waitingForConfig && !isConfigFrame(packet)) continue;
                        waitingForConfig = false;

                        int inputIndex = codec.dequeueInputBuffer(0); // Non aspettare
                        if (inputIndex >= 0) {
                            ByteBuffer buffer = inputBuffers[inputIndex];
                            buffer.clear();
                            buffer.put(packet);
                            codec.queueInputBuffer(inputIndex, 0, packet.length, System.nanoTime()/1000, 0);
                        }
                    }

                    // Rendering immediato: timeout 0
                    int outputIndex = codec.dequeueOutputBuffer(info, 0);
                    if (outputIndex >= 0) {
                        codec.releaseOutputBuffer(outputIndex, true);
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Decoder loop err: " + e.getMessage());
                }
            }
        }

        private boolean isConfigFrame(byte[] data) {
            return data.length > 4 && ((data[4] & 0x1F) == 7 || (data[4] & 0x1F) == 8);
        }
    }

    public synchronized void stop() {
        isRunning = false;
        if (codec != null) {
            try { codec.stop(); codec.release(); } catch (Exception e) {}
            codec = null;
        }
    }
}