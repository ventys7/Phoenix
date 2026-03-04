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
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.view.SurfaceView;

public class MainActivity extends Activity {
    private static final String TAG = "PhoenixClient";
    private static final String SERVICE_TYPE = "_phoenix._udp.";

    private SurfaceView surfaceView;
    private EditText ipInput;
    private Button connectButton;
    private TextView statusText;
    private LinearLayout controlsLayout;

    private VideoDecoder videoDecoder;
    private VideoReceiver videoReceiver;
    private TouchSender touchSender;

    private Handler mainHandler;
    private boolean isConnected = false;
    private boolean isUiVisible = true;

    private NsdManager mNsdManager;
    private NsdManager.DiscoveryListener mDiscoveryListener;
    private WifiManager.MulticastLock multicastLock;

    // Timer per nascondere la UI
    private final Runnable hideUiRunnable = new Runnable() {
        @Override
        public void run() {
            hideSystemUI();
        }
    };

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (android.os.Build.VERSION.SDK_INT > 9) {
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);
        }

        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(R.layout.activity_main);
        mainHandler = new Handler();

        surfaceView = (SurfaceView) findViewById(R.id.surfaceView);
        ipInput = (EditText) findViewById(R.id.ipInput);
        connectButton = (Button) findViewById(R.id.connectButton);
        statusText = (TextView) findViewById(R.id.statusText);
        controlsLayout = (LinearLayout) findViewById(R.id.controlsLayout);

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
                // Se la UI è nascosta, la mostriamo al tocco
                if (!isUiVisible) {
                    showSystemUI();
                    return true;
                }

                // Logica originale del touch sender verso il Mac
                if (!isConnected || touchSender == null) return false;

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
                    Log.e(TAG, "Errore touch", e);
                }
                return true;
            }
        });

        startDiscovery();
    }

    private void hideSystemUI() {
        isUiVisible = false;
        controlsLayout.setVisibility(View.GONE);
        statusText.setVisibility(View.GONE);

        // KitKat Immersive Mode
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    private void showSystemUI() {
        isUiVisible = true;
        controlsLayout.setVisibility(View.VISIBLE);
        statusText.setVisibility(View.VISIBLE);

        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        // Se siamo connessi, facciamo ripartire il timer per nasconderla di nuovo
        if (isConnected) {
            startUiHideTimer();
        }
    }

    private void startUiHideTimer() {
        mainHandler.removeCallbacks(hideUiRunnable);
        mainHandler.postDelayed(hideUiRunnable, 3000);
    }

    private void connect() {
        final String ip = ipInput.getText().toString().trim();
        if (ip.isEmpty()) return;

        try {
            videoDecoder = new VideoDecoder(surfaceView.getHolder().getSurface());
            videoDecoder.start();

            videoReceiver = new VideoReceiver(videoDecoder);
            videoReceiver.start();

            touchSender = new TouchSender();
            touchSender.connect(ip);

            isConnected = true;
            connectButton.setText("Disconnect");
            statusText.setText("Connesso a " + ip);

            // Nasconde tutto dopo 3 secondi
            startUiHideTimer();

        } catch (Exception e) {
            statusText.setText("Errore: " + e.getMessage());
            disconnect();
        }
    }

    private void disconnect() {
        isConnected = false;
        mainHandler.removeCallbacks(hideUiRunnable);
        showSystemUI();

        try {
            if (videoReceiver != null) videoReceiver.stop();
            if (videoDecoder != null) videoDecoder.stop();
            if (touchSender != null) touchSender.disconnect();
        } catch (Exception e) {}

        videoReceiver = null;
        videoDecoder = null;
        touchSender = null;

        connectButton.setText("Connect");
        statusText.setText("Disconnesso");
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
            public void onDiscoveryStarted(String regType) {}
            @Override
            public void onServiceFound(final NsdServiceInfo serviceInfo) {
                mNsdManager.resolveService(serviceInfo, new NsdManager.ResolveListener() {
                    @Override
                    public void onServiceResolved(final NsdServiceInfo resolvedInfo) {
                        final String hostIp = resolvedInfo.getHost().getHostAddress();
                        mainHandler.post(new Runnable() {
                            @Override public void run() {
                                ipInput.setText(hostIp);
                                statusText.setText("Mac trovato: " + hostIp);
                            }
                        });
                    }
                    @Override public void onResolveFailed(NsdServiceInfo serviceInfo, int errorCode) {}
                });
            }
            @Override public void onServiceLost(NsdServiceInfo n) {}
            @Override public void onDiscoveryStopped(String s) {}
            @Override public void onStartDiscoveryFailed(String s, int e) {}
            @Override public void onStopDiscoveryFailed(String s, int e) {}
        };
    }

    private void startDiscovery() {
        try { mNsdManager.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, mDiscoveryListener); } catch (Exception e) {}
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
        if (multicastLock != null && multicastLock.isHeld()) multicastLock.release();
        disconnect();
        super.onDestroy();
    }
}