package com.phoenix.client;

import android.app.Activity;
import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.StrictMode;
import android.util.Log;
import android.view.MotionEvent;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import java.io.IOException;

public class MainActivity extends Activity {
    private static final String TAG = "PhoenixClient";
    private static final String SERVICE_TYPE = "_phoenix._udp.";

    private SurfaceView surfaceView;
    private EditText ipInput;
    private Button connectButton;
    private TextView statusText;

    private VideoDecoder videoDecoder;
    private VideoReceiver videoReceiver;
    private TouchSender touchSender;

    private Handler mainHandler;
    private boolean isConnected = false;

    // Discovery components
    private NsdManager mNsdManager;
    private NsdManager.DiscoveryListener mDiscoveryListener;
    private WifiManager.MulticastLock multicastLock;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- FIX: NETWORK ON MAIN THREAD ---
        // Questa patch evita il crash "NetworkOnMainThreadException"
        if (android.os.Build.VERSION.SDK_INT > 9) {
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);
        }

        // Mantiene lo schermo acceso durante lo streaming
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        setContentView(R.layout.activity_main);
        mainHandler = new Handler();

        surfaceView = (SurfaceView) findViewById(R.id.surfaceView);
        ipInput = (EditText) findViewById(R.id.ipInput);
        connectButton = (Button) findViewById(R.id.connectButton);
        statusText = (TextView) findViewById(R.id.statusText);

        // Forza il tablet a "sentire" i pacchetti mDNS (Bonjour) del Mac
        setupMulticast();

        mNsdManager = (NsdManager) getSystemService(Context.NSD_SERVICE);
        initializeDiscoveryListener();

        connectButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (isConnected) disconnect(); else connect();
            }
        });

        surfaceView.setOnTouchListener(new View.OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                if (!isConnected || touchSender == null) return false;

                // Calcolo coordinate relative al desktop Mac (1024x768)
                // Usiamo float per precisione e poi castiamo a int
                int x = (int) (event.getX() * 1024 / surfaceView.getWidth());
                int y = (int) (event.getY() * 768 / surfaceView.getHeight());

                try {
                    switch (event.getAction()) {
                        case MotionEvent.ACTION_DOWN:
                            touchSender.touchDown(x, y);
                            break;
                        case MotionEvent.ACTION_MOVE:
                            touchSender.touchMove(x, y);
                            break;
                        case MotionEvent.ACTION_UP:
                            touchSender.touchUp();
                            break;
                    }
                } catch (Exception e) {
                    Log.e(TAG, "Errore invio touch", e);
                }
                return true;
            }
        });

        startDiscovery();
    }

    private void setupMulticast() {
        WifiManager wifi = (WifiManager) getSystemService(Context.WIFI_SERVICE);
        if (wifi != null) {
            multicastLock = wifi.createMulticastLock("phoenixLock");
            multicastLock.setReferenceCounted(true);
            multicastLock.acquire();
        }
    }

    private void initializeDiscoveryListener() {
        mDiscoveryListener = new NsdManager.DiscoveryListener() {
            @Override
            public void onDiscoveryStarted(String regType) {
                Log.d(TAG, "Ricerca Mac avviata...");
            }

            @Override
            public void onServiceFound(final NsdServiceInfo serviceInfo) {
                mNsdManager.resolveService(serviceInfo, new NsdManager.ResolveListener() {
                    @Override
                    public void onServiceResolved(final NsdServiceInfo resolvedInfo) {
                        final String hostIp = resolvedInfo.getHost().getHostAddress();
                        mainHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                ipInput.setText(hostIp);
                                statusText.setText("Mac trovato: " + hostIp);
                            }
                        });
                    }
                    @Override
                    public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {
                        Log.e(TAG, "Errore risoluzione: " + errorCode);
                    }
                });
            }

            @Override public void onServiceLost(NsdServiceInfo n) {
                mainHandler.post(new Runnable() {
                    @Override public void run() { statusText.setText("Connessione Mac persa"); }
                });
            }
            @Override public void onDiscoveryStopped(String s) {}
            @Override public void onStartDiscoveryFailed(String s, int e) {}
            @Override public void onStopDiscoveryFailed(String s, int e) {}
        };
    }

    private void startDiscovery() {
        try {
            mNsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, mDiscoveryListener);
        } catch (Exception e) {
            Log.e(TAG, "Errore discovery", e);
        }
    }

    private void connect() {
        final String ip = ipInput.getText().toString().trim();
        if (ip.isEmpty()) return;

        try {
            // Setup Video Decoder con la Surface attuale
            videoDecoder = new VideoDecoder(surfaceView.getHolder().getSurface());
            videoDecoder.start();

            // Setup Video Receiver
            videoReceiver = new VideoReceiver(videoDecoder);
            videoReceiver.start();

            // Setup Touch
            touchSender = new TouchSender();
            touchSender.connect(ip);

            isConnected = true;
            connectButton.setText("Disconnect");
            statusText.setText("Connesso a " + ip);
            Log.d(TAG, "Streaming avviato con successo");

        } catch (Exception e) {
            Log.e(TAG, "Errore connessione", e);
            statusText.setText("Errore: " + e.getMessage());
            disconnect();
        }
    }

    private void disconnect() {
        isConnected = false;
        try {
            if (videoReceiver != null) videoReceiver.stop();
            if (videoDecoder != null) videoDecoder.stop();
            if (touchSender != null) touchSender.disconnect();
        } catch (Exception e) {
            Log.e(TAG, "Errore durante disconnect", e);
        }

        videoReceiver = null;
        videoDecoder = null;
        touchSender = null;

        connectButton.setText("Connect");
        statusText.setText("Disconnesso");
    }

    @Override
    protected void onPause() {
        if (mNsdManager != null && mDiscoveryListener != null) {
            try { mNsdManager.stopServiceDiscovery(mDiscoveryListener); } catch (Exception e) {}
        }
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (mNsdManager != null) startDiscovery();
    }

    @Override
    protected void onDestroy() {
        if (multicastLock != null && multicastLock.isHeld()) {
            multicastLock.release();
        }
        disconnect();
        super.onDestroy();
    }
}