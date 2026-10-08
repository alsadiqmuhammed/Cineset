package app.cineset.mobile;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.Toast;

import androidx.webkit.WebViewAssetLoader;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Hosts the CINESET web app from the APK's assets. All data lives in the WebView's
 * IndexedDB inside this app's private storage; nothing is sent to a server.
 */
public class MainActivity extends Activity {
    private static final String APP_URL = "https://appassets.androidplatform.net/assets/www/index.html";
    private static final int REQ_PICK_FILE = 1;
    private static final int REQ_SAVE_FILE = 2;

    private WebView webView;
    private FrameLayout root;
    private View fullscreenView;
    private WebChromeClient.CustomViewCallback fullscreenCallback;
    private ValueCallback<Uri[]> pendingFilePick;

    /** Files being prepared for "Save to phone": token -> temp file in the cache. */
    private final Map<String, File> pendingSaves = new HashMap<>();
    private final Map<String, String> pendingSaveNames = new HashMap<>();
    private final Map<String, String> pendingSaveTypes = new HashMap<>();
    private String saveInProgress;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        root = new FrameLayout(this);
        root.setBackgroundColor(0xFF0B0C0F);
        webView = new WebView(this);
        webView.setBackgroundColor(0xFF0B0C0F);
        root.addView(webView, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        // Android 15 draws apps edge to edge; keep the page clear of the status and navigation bars.
        root.setOnApplyWindowInsetsListener((v, insets) -> {
            int top, bottom, left, right;
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                android.graphics.Insets bars = insets.getInsets(WindowInsets.Type.systemBars() | WindowInsets.Type.displayCutout() | WindowInsets.Type.ime());
                top = bars.top; bottom = bars.bottom; left = bars.left; right = bars.right;
            } else {
                top = insets.getSystemWindowInsetTop(); bottom = insets.getSystemWindowInsetBottom();
                left = insets.getSystemWindowInsetLeft(); right = insets.getSystemWindowInsetRight();
            }
            v.setPadding(left, top, right, bottom);
            return insets;
        });

        WebSettings s = webView.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(false);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setSupportMultipleWindows(false);

        WebViewAssetLoader assets = new WebViewAssetLoader.Builder()
                .addPathHandler("/assets/", new WebViewAssetLoader.AssetsPathHandler(this))
                .build();

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assets.shouldInterceptRequest(request.getUrl());
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri url = request.getUrl();
                if ("appassets.androidplatform.net".equals(url.getHost())) return false;
                openExternal(url.toString());
                return true;
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (pendingFilePick != null) pendingFilePick.onReceiveValue(null);
                pendingFilePick = callback;
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                String[] types = params.getAcceptTypes();
                String type = "*/*";
                if (types != null && types.length == 1 && types[0] != null && types[0].contains("/")) type = types[0];
                intent.setType(type);
                try {
                    startActivityForResult(intent, REQ_PICK_FILE);
                } catch (ActivityNotFoundException e) {
                    pendingFilePick = null;
                    return false;
                }
                return true;
            }

            @Override
            public void onShowCustomView(View view, CustomViewCallback callback) {
                if (fullscreenView != null) { callback.onCustomViewHidden(); return; }
                fullscreenView = view;
                fullscreenCallback = callback;
                root.addView(view, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
                webView.setVisibility(View.GONE);
            }

            @Override
            public void onHideCustomView() {
                if (fullscreenView == null) return;
                root.removeView(fullscreenView);
                fullscreenView = null;
                webView.setVisibility(View.VISIBLE);
                if (fullscreenCallback != null) fullscreenCallback.onCustomViewHidden();
                fullscreenCallback = null;
            }
        });

        webView.addJavascriptInterface(new Bridge(), "CinesetNative");
        if (savedInstanceState != null) webView.restoreState(savedInstanceState);
        else webView.loadUrl(APP_URL);
    }

    /** Methods the web app calls as window.CinesetNative.*. */
    private class Bridge {
        /** Starts collecting a file to save; returns a token for appendChunk/finishSave. */
        @JavascriptInterface
        public String beginSave(String name, String mimeType) {
            try {
                String token = UUID.randomUUID().toString();
                File tmp = File.createTempFile("save-", ".part", getCacheDir());
                synchronized (pendingSaves) {
                    pendingSaves.put(token, tmp);
                    pendingSaveNames.put(token, name);
                    pendingSaveTypes.put(token, mimeType);
                }
                return token;
            } catch (Exception e) {
                return "";
            }
        }

        @JavascriptInterface
        public boolean appendChunk(String token, String base64) {
            File tmp;
            synchronized (pendingSaves) { tmp = pendingSaves.get(token); }
            if (tmp == null) return false;
            try (OutputStream out = new FileOutputStream(tmp, true)) {
                out.write(Base64.decode(base64, Base64.DEFAULT));
                return true;
            } catch (Exception e) {
                return false;
            }
        }

        /** Asks where to save (system file picker), then copies the collected file there. */
        @JavascriptInterface
        public void finishSave(String token) {
            runOnUiThread(() -> {
                String name, type;
                synchronized (pendingSaves) {
                    name = pendingSaveNames.get(token);
                    type = pendingSaveTypes.get(token);
                }
                if (name == null) { notifySaved(token, false); return; }
                saveInProgress = token;
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                intent.addCategory(Intent.CATEGORY_OPENABLE);
                intent.setType(type == null || type.isEmpty() ? "application/octet-stream" : type);
                intent.putExtra(Intent.EXTRA_TITLE, name);
                try {
                    startActivityForResult(intent, REQ_SAVE_FILE);
                } catch (ActivityNotFoundException e) {
                    finishPendingSave(null);
                }
            });
        }

        @JavascriptInterface
        public void openExternal(String url) {
            runOnUiThread(() -> MainActivity.this.openExternal(url));
        }
    }

    private void openExternal(String url) {
        if (url == null || !(url.startsWith("https://") || url.startsWith("http://"))) return;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
        } catch (ActivityNotFoundException ignored) {
        }
    }

    private void finishPendingSave(Uri target) {
        String token = saveInProgress;
        saveInProgress = null;
        if (token == null) return;
        File tmp;
        synchronized (pendingSaves) {
            tmp = pendingSaves.remove(token);
            pendingSaveNames.remove(token);
            pendingSaveTypes.remove(token);
        }
        boolean ok = false;
        if (target != null && tmp != null) {
            try (InputStream in = new FileInputStream(tmp); OutputStream out = getContentResolver().openOutputStream(target)) {
                byte[] buf = new byte[1 << 16];
                int n;
                while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
                ok = true;
            } catch (Exception e) {
                Toast.makeText(this, "Could not save the file", Toast.LENGTH_LONG).show();
            }
        }
        if (tmp != null) //noinspection ResultOfMethodCallIgnored
            tmp.delete();
        notifySaved(token, ok);
    }

    private void notifySaved(String token, boolean ok) {
        webView.evaluateJavascript("window.__cinesetSaved&&window.__cinesetSaved('" + token + "'," + ok + ")", null);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_PICK_FILE) {
            if (pendingFilePick != null) {
                Uri uri = resultCode == RESULT_OK && data != null ? data.getData() : null;
                pendingFilePick.onReceiveValue(uri != null ? new Uri[]{uri} : null);
                pendingFilePick = null;
            }
        } else if (requestCode == REQ_SAVE_FILE) {
            finishPendingSave(resultCode == RESULT_OK && data != null ? data.getData() : null);
        }
    }

    @Override
    public void onBackPressed() {
        if (fullscreenView != null) {
            webView.getWebChromeClient().onHideCustomView();
            return;
        }
        // Let the app close dialogs or go back to the overview first; leave the app only from the overview.
        webView.evaluateJavascript("window.cinesetBack?String(window.cinesetBack()):'false'", result -> {
            if (!"\"true\"".equals(result)) MainActivity.super.onBackPressed();
        });
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        webView.saveState(outState);
    }

    @Override
    protected void onPause() {
        super.onPause();
        webView.evaluateJavascript("window.cinesetLocal&&window.cinesetLocal.flush()", null);
        webView.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        webView.onResume();
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            root.removeView(webView);
            webView.destroy();
        }
        super.onDestroy();
    }
}
