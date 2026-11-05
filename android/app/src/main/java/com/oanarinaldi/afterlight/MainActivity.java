package com.oanarinaldi.afterlight;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.hardware.*;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.webkit.*;
import androidx.activity.ComponentActivity;
import androidx.activity.OnBackPressedCallback;
import androidx.core.view.*;
import androidx.webkit.WebViewAssetLoader;
import java.io.*;
import java.util.*;
import java.util.zip.InflaterInputStream;
import javax.crypto.*;
import javax.crypto.spec.*;

public final class MainActivity extends ComponentActivity implements SensorEventListener {
    private WebView web;
    private SensorManager sensors;
    private boolean tilt;
    private long lastTilt;
    @SuppressLint("SetJavaScriptEnabled") @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.hide(WindowInsetsCompat.Type.systemBars());
        controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        sensors = (SensorManager)getSystemService(SENSOR_SERVICE);
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true); s.setDomStorageEnabled(true); s.setAllowFileAccess(false); s.setAllowContentAccess(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW); s.setMediaPlaybackRequiresUserGesture(false);
        s.setSupportZoom(false); s.setTextZoom(100);
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);
        WebViewAssetLoader loader = new WebViewAssetLoader.Builder()
            .addPathHandler("/assets/art/", path -> {
                if (!path.matches("[A-Za-z0-9._-]+")) return null;
                try {
                    byte[] packed;
                    try(InputStream input = getAssets().open("art/" + path + ".pack")) {
                        ByteArrayOutputStream bytes=new ByteArrayOutputStream();byte[] block=new byte[16384];int read;
                        while((read=input.read(block))!=-1)bytes.write(block,0,read);
                        packed=bytes.toByteArray();
                    }
                    byte[] iv = Arrays.copyOf(packed,12);
                    Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
                    cipher.init(Cipher.DECRYPT_MODE, new SecretKeySpec(GeneratedAssetKey.KEY, "AES"), new GCMParameterSpec(128, iv));
                    String mime = path.endsWith(".json") ? "application/json" : path.endsWith(".png") ? "image/png" : path.endsWith(".jpg") ? "image/jpeg" : "application/octet-stream";
                    byte[] decoded=cipher.doFinal(packed,12,packed.length-12);
                    return new WebResourceResponse(mime, path.endsWith(".json") ? "UTF-8" : null, new InflaterInputStream(new ByteArrayInputStream(decoded)));
                } catch (Exception e) { return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), new ByteArrayInputStream(new byte[0])); }
            })
            .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this)).build();
        web.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri u=request.getUrl();
                if ("https".equals(u.getScheme()) && "appassets.androidplatform.net".equals(u.getHost())) return loader.shouldInterceptRequest(u);
                return new WebResourceResponse("text/plain", "UTF-8", 403, "Offline only", Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return true; }
        });
        web.addJavascriptInterface(new Bridge(), "AfterlightNative");
        if(BuildConfig.DEBUG)web.setWebChromeClient(new WebChromeClient(){
            @Override public boolean onConsoleMessage(ConsoleMessage m){android.util.Log.d("AfterlightWeb",m.message()+" @ "+m.sourceId()+":"+m.lineNumber());return true;}
        });
        setContentView(web);
        getOnBackPressedDispatcher().addCallback(this,new OnBackPressedCallback(true) {
            @Override public void handleOnBackPressed() { web.evaluateJavascript("window.afterlightBack ? window.afterlightBack() : false",value->{if("false".equals(value))finish();}); }
        });
        web.loadUrl("https://appassets.androidplatform.net/assets/index.html");
    }
    private final class Bridge {
        @JavascriptInterface public boolean isDebug() { return BuildConfig.DEBUG; }
        @JavascriptInterface public void haptic() { runOnUiThread(() -> web.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)); }
        @JavascriptInterface public void tilt(boolean enabled) { runOnUiThread(() -> { tilt=enabled; updateSensor(); }); }
        @JavascriptInterface public void privacy() { runOnUiThread(() -> startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse("https://oanarinaldi.com/afterlightprivacy.html")))); }
    }
    private void updateSensor() {
        sensors.unregisterListener(this);
        if (tilt) { Sensor sensor=sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER); if(sensor!=null) sensors.registerListener(this,sensor,SensorManager.SENSOR_DELAY_GAME); }
    }
    @Override protected void onPause() {
        web.evaluateJavascript("window.afterlightSuspend && window.afterlightSuspend()",null);
        web.onPause(); sensors.unregisterListener(this); super.onPause();
    }
    @Override protected void onResume() { super.onResume(); if(web!=null) {web.onResume(); updateSensor();} }
    @Override protected void onDestroy() { sensors.unregisterListener(this); if(web!=null) {web.removeJavascriptInterface("AfterlightNative");web.destroy();} super.onDestroy(); }
    @Override public void onAccuracyChanged(Sensor sensor,int accuracy) {}
    @Override public void onSensorChanged(SensorEvent event) {
        if(!tilt || event.timestamp-lastTilt<16_000_000) return;lastTilt=event.timestamp;
        int rotation=getWindowManager().getDefaultDisplay().getRotation();
        float gravity = event.values[(rotation==Surface.ROTATION_0||rotation==Surface.ROTATION_180)?0:1]/SensorManager.GRAVITY_EARTH;
        double raw=(rotation==Surface.ROTATION_0||rotation==Surface.ROTATION_90 ? -gravity:gravity)/0.32;
        double value=Math.abs(raw)<=0.06 ? 0 : Math.max(-1,Math.min(1,(Math.abs(raw)-0.06)/0.94*Math.signum(raw)));
        web.evaluateJavascript("window.afterlightTilt && window.afterlightTilt("+value+")",null);
    }
}
