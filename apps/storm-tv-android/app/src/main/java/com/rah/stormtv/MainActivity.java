package com.rah.stormtv;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.Button;
import android.widget.GridLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import androidx.media3.common.MediaItem;
import androidx.media3.common.PlaybackException;
import androidx.media3.common.Player;
import androidx.media3.datasource.DefaultHttpDataSource;
import androidx.media3.exoplayer.ExoPlayer;
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory;
import androidx.media3.ui.PlayerView;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@androidx.media3.common.util.UnstableApi
public class MainActivity extends Activity {
    private static final String TAG = "RAHStormTV";
    private static final String CACHE_BD_TV = "bangladesh_tv";
    private static final String CACHE_WORLD_TV = "world_tv";
    private static final String CACHE_BD_RADIO = "bangladesh_radio";
    private static final String CACHE_WORLD_RADIO = "world_radio";

    private static final int BG = Color.rgb(5, 7, 10);
    private static final int PANEL = Color.rgb(15, 20, 27);
    private static final int GOLD = Color.rgb(244, 200, 74);
    private static final int CYAN = Color.rgb(35, 200, 255);
    private static final int TEXT = Color.rgb(242, 239, 228);
    private static final int MUTED = Color.rgb(159, 166, 176);

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final List<ExoPlayer> activePlayers = new ArrayList<>();
    private final Set<String> loadingCatalogs = new HashSet<>();

    private LinearLayout root;
    private LinearLayout content;
    private TextView status;
    private SharedPreferences prefs;
    private CatalogCache catalogCache;

    private List<StreamItem> currentItems = new ArrayList<>();
    private String currentCatalogTitle = "Bangladesh TV";
    private String activeCatalogKey = "";
    private boolean catalogVisible = true;
    private boolean mosaicVisible = false;
    private int playbackGeneration = 0;

    private StreamItem activeSingleItem;
    private PlayerView activeSingleView;
    private ExoPlayer activeSinglePlayer;
    private Button activeRetryButton;
    private Button activePlayPauseButton;

    private interface CatalogLoader {
        List<StreamItem> load() throws Exception;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window w = getWindow();
        w.setStatusBarColor(BG);
        w.setNavigationBarColor(BG);
        prefs = getSharedPreferences("rah_storm_tv", MODE_PRIVATE);
        catalogCache = new CatalogCache(prefs);
        buildShell();
        loadBangladeshTv();
    }

    private void buildShell() {
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);
        root.setPadding(dp(10), dp(8), dp(10), dp(8));

        TextView title = new TextView(this);
        title.setText("RAH STORM TV • BANGLADESH");
        title.setTextColor(GOLD);
        title.setTextSize(22);
        title.setGravity(Gravity.CENTER_VERTICAL);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        root.addView(title, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(38)));

        TextView sub = new TextView(this);
        sub.setText("SHIMANTO EDITION • বাংলাদেশ • TV + RADIO + 4/9/16 MOSAIC");
        sub.setTextColor(CYAN);
        sub.setTextSize(12);
        root.addView(sub, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(24)));

        HorizontalScrollView navScroll = new HorizontalScrollView(this);
        navScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setPadding(0, dp(4), 0, dp(5));

        addNav(nav, "🇧🇩 BANGLADESH TV", v -> loadBangladeshTv());
        addNav(nav, "🌍 WORLD TV", v -> loadWorldTv());
        addNav(nav, "📻 BD RADIO", v -> loadBangladeshRadio());
        addNav(nav, "🌐 WORLD RADIO", v -> loadWorldRadio());
        addNav(nav, "★ FAVORITES", v -> showFavorites());
        addNav(nav, "▦ 4", v -> showMosaic(4));
        addNav(nav, "▦ 9", v -> showMosaic(9));
        addNav(nav, "▦ 16", v -> showMosaic(16));
        addNav(nav, "↻ REFRESH", v -> refreshCurrent());

        navScroll.addView(nav);
        root.addView(navScroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(58)));

        status = new TextView(this);
        status.setTextColor(MUTED);
        status.setTextSize(11);
        status.setPadding(dp(4), dp(2), dp(4), dp(5));
        root.addView(status, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(28)));

        ScrollView bodyScroll = new ScrollView(this);
        bodyScroll.setFillViewport(true);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER_HORIZONTAL);
        bodyScroll.addView(content, new ScrollView.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT));
        root.addView(bodyScroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));

        setContentView(root);
    }

    private void addNav(LinearLayout nav, String label, View.OnClickListener listener) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(GOLD);
        b.setTextSize(11);
        b.setAllCaps(false);
        b.setFocusable(true);
        styleButton(b, false);
        b.setOnFocusChangeListener((v, focused) -> styleButton((Button) v, focused));
        b.setOnClickListener(listener);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(46));
        lp.setMargins(dp(3), 0, dp(3), 0);
        nav.addView(b, lp);
    }

    private void loadBangladeshTv() {
        loadCatalog(
                CACHE_BD_TV,
                "Bangladesh TV",
                "Loading Bangladesh TV…",
                () -> CatalogRepository.loadM3u(
                        CatalogRepository.BANGLADESH_TV, "Bangladesh", 200)
        );
    }

    private void loadWorldTv() {
        loadCatalog(
                CACHE_WORLD_TV,
                "World TV • first 300 public streams",
                "Loading World TV…",
                () -> CatalogRepository.loadM3u(
                        CatalogRepository.WORLD_TV, "World", 300)
        );
    }

    private void loadBangladeshRadio() {
        loadCatalog(
                CACHE_BD_RADIO,
                "Bangladesh Radio",
                "Loading Bangladesh radio…",
                () -> CatalogRepository.loadBangladeshRadio(120)
        );
    }

    private void loadWorldRadio() {
        loadCatalog(
                CACHE_WORLD_RADIO,
                "World Radio",
                "Loading World Radio…",
                () -> CatalogRepository.loadWorldRadio(180)
        );
    }

    private void loadCatalog(String cacheKey, String title, String loadingMessage, CatalogLoader loader) {
        activeCatalogKey = cacheKey;
        currentCatalogTitle = title;

        List<StreamItem> cached = catalogCache.load(cacheKey);
        if (!cached.isEmpty()) {
            showCatalog(cached, title);
            setStatus("CACHED • " + title + " • refreshing");
        } else {
            showLoading(loadingMessage);
        }

        if (loadingCatalogs.contains(cacheKey)) {
            if (!cached.isEmpty()) setStatus("CACHED • refresh already running");
            return;
        }

        loadingCatalogs.add(cacheKey);
        executor.submit(() -> {
            try {
                List<StreamItem> fresh = loader.load();
                catalogCache.save(cacheKey, fresh);
                main.post(() -> {
                    loadingCatalogs.remove(cacheKey);
                    if (!cacheKey.equals(activeCatalogKey) || !catalogVisible) return;
                    showCatalog(fresh, title);
                    setStatus(title + " • LIVE CATALOG");
                });
            } catch (Exception e) {
                Log.w(TAG, "Catalog refresh failed: " + cacheKey, e);
                main.post(() -> {
                    loadingCatalogs.remove(cacheKey);
                    if (!cacheKey.equals(activeCatalogKey) || !catalogVisible) return;
                    if (!cached.isEmpty()) {
                        showCatalog(cached, title);
                        setStatus("OFFLINE/CACHED • " + title);
                    } else {
                        showCatalogError(
                                title,
                                friendlyCatalogError(e),
                                () -> loadCatalog(cacheKey, title, loadingMessage, loader)
                        );
                    }
                });
            }
        });
    }

    private void refreshCurrent() {
        if (currentCatalogTitle.contains("World Radio")) loadWorldRadio();
        else if (currentCatalogTitle.contains("Bangladesh Radio")) loadBangladeshRadio();
        else if (currentCatalogTitle.startsWith("World")) loadWorldTv();
        else if (currentCatalogTitle.contains("Favorite")) showFavorites();
        else loadBangladeshTv();
    }

    private void showLoading(String message) {
        releasePlayers();
        clearPlaybackUiState();
        catalogVisible = true;
        content.removeAllViews();
        ProgressBar p = new ProgressBar(this);
        content.addView(p, new LinearLayout.LayoutParams(dp(54), dp(54)));
        TextView t = text(message, 16, TEXT);
        t.setGravity(Gravity.CENTER);
        content.addView(t);
        setStatus(message);
    }

    private void showCatalogError(String source, String reason, Runnable retry) {
        releasePlayers();
        clearPlaybackUiState();
        catalogVisible = true;
        content.removeAllViews();

        TextView title = text(source, 18, GOLD);
        title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        title.setGravity(Gravity.CENTER);
        title.setPadding(dp(20), dp(32), dp(20), dp(8));
        content.addView(title);

        TextView t = text(reason + "\n\nThe app is still usable. Retry the source or go back.", 15, TEXT);
        t.setGravity(Gravity.CENTER);
        t.setPadding(dp(25), dp(8), dp(25), dp(18));
        content.addView(t);

        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);
        row.addView(actionButton("↻ TRY AGAIN", v -> retry.run()));
        row.addView(actionButton("← BACK", v -> {
            if (!currentItems.isEmpty()) showCatalog(currentItems, currentCatalogTitle);
            else finish();
        }));
        content.addView(row);

        setStatus(reason + " • " + source);
    }

    private String friendlyCatalogError(Exception error) {
        String message = error == null || error.getMessage() == null
                ? "" : error.getMessage().toLowerCase();
        if (message.contains("timed out") || message.contains("timeout")) return "REQUEST TIMED OUT";
        if (message.contains("unable to resolve") || message.contains("network")) return "NETWORK UNAVAILABLE";
        if (message.contains("http")) return "SOURCE UNAVAILABLE";
        if (message.contains("zero usable") || message.contains("no channel") ||
                message.contains("empty response") || message.contains("no usable")) {
            return "CATALOG INVALID";
        }
        return "CATALOG UNAVAILABLE";
    }

    private void showCatalog(List<StreamItem> items, String title) {
        releasePlayers();
        clearPlaybackUiState();
        currentItems = new ArrayList<>(items);
        currentCatalogTitle = title;
        catalogVisible = true;
        content.removeAllViews();

        TextView heading = text(title + " • " + items.size() + " items", 16, GOLD);
        heading.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        heading.setPadding(dp(5), dp(8), dp(5), dp(10));
        content.addView(heading);

        GridLayout grid = new GridLayout(this);
        int cols = getResources().getDisplayMetrics().widthPixels >= dp(1000) ? 3 : 2;
        grid.setColumnCount(cols);
        grid.setUseDefaultMargins(false);
        int width = getResources().getDisplayMetrics().widthPixels - dp(28);
        int cellWidth = Math.max(dp(150), width / cols - dp(8));

        Set<String> favKeys = favoriteKeys();
        for (StreamItem item : items) {
            Button b = new Button(this);
            String star = favKeys.contains(item.key()) ? "★ " : "";
            b.setText(star + item.name + (item.region.isBlank() ? "" : "\n" + item.region));
            b.setTextColor(TEXT);
            b.setTextSize(12);
            b.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
            b.setAllCaps(false);
            b.setFocusable(true);
            styleChannelButton(b, false);
            b.setOnFocusChangeListener((v, focused) -> styleChannelButton((Button) v, focused));
            b.setOnClickListener(v -> playSingle(item));
            b.setOnLongClickListener(v -> {
                toggleFavorite(item);
                showCatalog(currentItems, currentCatalogTitle);
                return true;
            });
            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = cellWidth;
            lp.height = dp(74);
            lp.setMargins(dp(3), dp(3), dp(3), dp(3));
            grid.addView(b, lp);
        }
        content.addView(grid);
        setStatus(title + " • public streams • long-press an item to favorite");
    }

    private void playRadio(StreamItem item) {
        activeCatalogKey = "";
        releasePlayers();
        clearPlaybackUiState();
        catalogVisible = false;
        activeSingleItem = item;
        content.removeAllViews();

        TextView brand = text("STORM RADIO", 22, GOLD);
        brand.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        brand.setGravity(Gravity.CENTER);
        brand.setPadding(dp(8), dp(22), dp(8), dp(6));
        content.addView(brand);

        TextView now = text(item.name, 24, TEXT);
        now.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        now.setGravity(Gravity.CENTER);
        now.setPadding(dp(18), dp(8), dp(18), dp(6));
        content.addView(now);

        TextView meta = text(item.region.isBlank() ? "LIVE RADIO" : item.region, 14, CYAN);
        meta.setGravity(Gravity.CENTER);
        meta.setPadding(dp(18), 0, dp(18), dp(20));
        content.addView(meta);

        TextView signal = text("◢◣  ●  ◥◤", 34, GOLD);
        signal.setGravity(Gravity.CENTER);
        signal.setPadding(dp(8), dp(10), dp(8), dp(18));
        content.addView(signal);

        PlayerView hidden = new PlayerView(this);
        hidden.setUseController(false);
        hidden.setVisibility(View.GONE);
        activeSingleView = hidden;
        content.addView(hidden, new LinearLayout.LayoutParams(1, 1));

        LinearLayout transport = new LinearLayout(this);
        transport.setGravity(Gravity.CENTER);
        transport.setOrientation(LinearLayout.HORIZONTAL);

        transport.addView(actionButton("⏮ PREV", v -> playRadioNeighbor(-1)));
        Button playPause = actionButton("⏸ PAUSE", v -> toggleRadioPlayback());
        activePlayPauseButton = playPause;
        transport.addView(playPause);
        transport.addView(actionButton("NEXT ⏭", v -> playRadioNeighbor(1)));
        content.addView(transport);

        LinearLayout actions = new LinearLayout(this);
        actions.setGravity(Gravity.CENTER);
        actions.setOrientation(LinearLayout.HORIZONTAL);

        Button back = actionButton("← STATIONS", v -> showCatalog(currentItems, currentCatalogTitle));
        Button fav = actionButton(isFavorite(item) ? "★ FAVORITE" : "☆ FAVORITE", v -> {
            toggleFavorite(item);
            ((Button) v).setText(isFavorite(item) ? "★ FAVORITE" : "☆ FAVORITE");
        });
        Button retry = actionButton("↻ RETRY", v -> retrySinglePlayback());
        retry.setVisibility(View.GONE);
        activeRetryButton = retry;

        actions.addView(back);
        actions.addView(fav);
        actions.addView(retry);
        content.addView(actions);

        setStatus("STORM RADIO • CONNECTING • " + item.name);
        int generation = playbackGeneration;
        startSinglePlayback(hidden, item, 0, generation, retry);
    }

    private void toggleRadioPlayback() {
        ExoPlayer p = activeSinglePlayer;
        if (p == null) {
            retrySinglePlayback();
            return;
        }
        if (p.isPlaying()) {
            p.pause();
            if (activePlayPauseButton != null) activePlayPauseButton.setText("▶ PLAY");
            setStatus("PAUSED • " + (activeSingleItem == null ? "Storm Radio" : activeSingleItem.name));
        } else {
            p.play();
            if (activePlayPauseButton != null) activePlayPauseButton.setText("⏸ PAUSE");
            setStatus("LIVE • " + (activeSingleItem == null ? "Storm Radio" : activeSingleItem.name));
        }
    }

    private void playRadioNeighbor(int delta) {
        StreamItem next = radioNeighbor(activeSingleItem, delta);
        if (next == null) {
            Toast.makeText(this, "No other radio station in this list.", Toast.LENGTH_SHORT).show();
            return;
        }
        playRadio(next);
    }

    private StreamItem radioNeighbor(StreamItem from, int delta) {
        List<StreamItem> radios = new ArrayList<>();
        for (StreamItem x : currentItems) {
            if ("radio".equals(x.type)) radios.add(x);
        }
        if (radios.isEmpty()) return null;

        int index = -1;
        if (from != null) {
            for (int i = 0; i < radios.size(); i++) {
                if (radios.get(i).key().equals(from.key())) {
                    index = i;
                    break;
                }
            }
        }

        int size = radios.size();
        int next = index < 0 ? 0 : (index + delta + size) % size;
        return radios.get(next);
    }

    private void playSingle(StreamItem item) {
        if ("radio".equals(item.type)) {
            playRadio(item);
            return;
        }
        activeCatalogKey = "";
        releasePlayers();
        clearPlaybackUiState();
        catalogVisible = false;
        activeSingleItem = item;
        content.removeAllViews();

        TextView heading = text(item.name + (item.region.isBlank() ? "" : " • " + item.region), 16, GOLD);
        heading.setPadding(dp(5), dp(4), dp(5), dp(6));
        content.addView(heading);

        PlayerView view = new PlayerView(this);
        view.setUseController(true);
        view.setFocusable(true);
        view.setKeepScreenOn(true);
        activeSingleView = view;

        LinearLayout.LayoutParams vp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(420));
        content.addView(view, vp);

        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER);

        Button back = actionButton("← CHANNELS", v -> showCatalog(currentItems, currentCatalogTitle));
        Button fav = actionButton(isFavorite(item) ? "★ FAVORITE" : "☆ FAVORITE", v -> {
            toggleFavorite(item);
            ((Button) v).setText(isFavorite(item) ? "★ FAVORITE" : "☆ FAVORITE");
        });
        Button retry = actionButton("↻ RETRY STREAM", v -> retrySinglePlayback());
        retry.setVisibility(View.GONE);
        activeRetryButton = retry;

        row.addView(back);
        row.addView(fav);
        row.addView(retry);
        content.addView(row);

        int generation = playbackGeneration;
        startSinglePlayback(view, item, 0, generation, retry);
    }

    private void retrySinglePlayback() {
        if (activeSingleItem == null || activeSingleView == null) return;
        if (activeRetryButton != null) activeRetryButton.setVisibility(View.GONE);
        releasePlayers();
        int generation = playbackGeneration;
        startSinglePlayback(activeSingleView, activeSingleItem, 0, generation, activeRetryButton);
    }

    private void startSinglePlayback(PlayerView view, StreamItem item, int attempt,
                                     int generation, Button retryButton) {
        if (generation != playbackGeneration) return;

        ExoPlayer player = createPlayer(item);
        view.setPlayer(player);
        activePlayers.add(player);
        activeSinglePlayer = player;

        player.addListener(new Player.Listener() {
            @Override
            public void onPlaybackStateChanged(int state) {
                if (generation != playbackGeneration) return;
                if (state == Player.STATE_READY) {
                    if (retryButton != null) retryButton.setVisibility(View.GONE);
                    if ("radio".equals(item.type) && activePlayPauseButton != null) {
                        activePlayPauseButton.setText("⏸ PAUSE");
                    }
                    setStatus(("radio".equals(item.type) ? "STORM RADIO • LIVE • " : "LIVE • ") + item.name);
                } else if (state == Player.STATE_BUFFERING) {
                    setStatus((attempt > 0 ? "RETRYING / BUFFERING • " : "BUFFERING • ") + item.name);
                }
            }

            @Override
            public void onPlayerError(PlaybackException error) {
                Log.w(TAG, "Playback failed: " + item.name + " code=" + error.errorCode, error);
                releaseSpecificPlayer(player, view);
                if (generation != playbackGeneration) return;

                String label = playbackErrorLabel(error);
                if (attempt < 1) {
                    setStatus(label + " • RETRYING ONCE");
                    main.postDelayed(() -> {
                        if (generation != playbackGeneration || activeSingleItem == null ||
                                !activeSingleItem.key().equals(item.key())) return;
                        startSinglePlayback(view, item, attempt + 1, generation, retryButton);
                    }, 1200L);
                } else {
                    if ("radio".equals(item.type)) {
                        StreamItem next = radioNeighbor(item, 1);
                        if (next != null && !next.key().equals(item.key())) {
                            setStatus(label + " • SKIPPING TO NEXT STATION");
                            main.postDelayed(() -> {
                                if (generation == playbackGeneration && activeSingleItem != null &&
                                        activeSingleItem.key().equals(item.key())) {
                                    playRadio(next);
                                }
                            }, 900L);
                            return;
                        }
                    }
                    if (retryButton != null) retryButton.setVisibility(View.VISIBLE);
                    setStatus(label + " • RETRY STREAM OR BACK");
                }
            }
        });

        player.prepare();
        player.play();
    }

    private String playbackErrorLabel(PlaybackException error) {
        int code = error == null ? 0 : error.errorCode;
        if (code == 2002) return "STREAM TIMED OUT";
        if (code == 2001) return "NETWORK UNAVAILABLE";
        if (code >= 2000 && code < 3000) return "STREAM OFFLINE";
        if (code >= 3000 && code < 5000) return "FORMAT NOT SUPPORTED";
        return "STREAM FAILED";
    }

    private void showMosaic(int requested) {
        List<StreamItem> tv = new ArrayList<>();
        for (StreamItem x : currentItems) if ("tv".equals(x.type)) tv.add(x);
        if (tv.isEmpty()) {
            Toast.makeText(this, "Open Bangladesh TV or World TV first.", Toast.LENGTH_SHORT).show();
            return;
        }

        activeCatalogKey = "";
        releasePlayers();
        clearPlaybackUiState();
        catalogVisible = false;
        mosaicVisible = true;
        content.removeAllViews();

        int n = Math.min(requested, tv.size());
        int cols = (int) Math.ceil(Math.sqrt(n));
        int rows = (int) Math.ceil((double) n / cols);
        int generation = playbackGeneration;

        TextView heading = text("MOSAIC " + n + " • tap/OK a tile for sound", 14, GOLD);
        heading.setPadding(dp(4), dp(2), dp(4), dp(5));
        content.addView(heading);

        DisplayMetrics dm = getResources().getDisplayMetrics();
        int tileW = Math.max(dp(145), (dm.widthPixels - dp(35)) / cols);
        int tileH = Math.max(dp(92), Math.min(dp(235), (dm.heightPixels - dp(185)) / rows));

        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(cols);

        for (int i = 0; i < n; i++) {
            StreamItem item = tv.get(i);
            PlayerView pv = new PlayerView(this);
            pv.setUseController(false);
            pv.setFocusable(true);
            pv.setClickable(true);
            pv.setKeepScreenOn(true);
            pv.setBackgroundColor(Color.BLACK);

            GridLayout.LayoutParams lp = new GridLayout.LayoutParams();
            lp.width = tileW;
            lp.height = tileH;
            lp.setMargins(dp(2), dp(2), dp(2), dp(2));
            grid.addView(pv, lp);

            main.postDelayed(() -> {
                if (generation != playbackGeneration) return;

                ExoPlayer p = createPlayer(item);
                final boolean[] failed = {false};
                final String[] failureLabel = {""};

                p.setVolume(0f);
                pv.setPlayer(p);
                activePlayers.add(p);

                pv.setOnClickListener(v -> {
                    if (failed[0]) {
                        failed[0] = false;
                        failureLabel[0] = "";
                        pv.setAlpha(1f);
                        pv.setBackgroundColor(Color.BLACK);
                        setStatus("RETRYING • " + item.name);
                        p.prepare();
                        p.play();
                    } else {
                        selectMosaicAudio(p, item);
                    }
                });

                pv.setOnFocusChangeListener((v, focused) -> {
                    if (focused) {
                        v.setBackgroundColor(failed[0] ? Color.rgb(85, 28, 28) : GOLD);
                        if (failed[0]) {
                            setStatus(failureLabel[0] + " • " + item.name + " • press OK to retry");
                        } else {
                            setStatus("FOCUS • " + item.name + " • press OK for sound");
                        }
                    } else {
                        v.setBackgroundColor(failed[0] ? Color.rgb(55, 20, 20) : Color.BLACK);
                    }
                });

                p.addListener(new Player.Listener() {
                    @Override
                    public void onPlaybackStateChanged(int state) {
                        if (state == Player.STATE_READY) {
                            failed[0] = false;
                            failureLabel[0] = "";
                            pv.setAlpha(1f);
                        }
                    }

                    @Override
                    public void onPlayerError(PlaybackException error) {
                        Log.w(TAG, "Mosaic playback failed: " + item.name + " code=" + error.errorCode, error);
                        failed[0] = true;
                        failureLabel[0] = playbackErrorLabel(error);
                        pv.setAlpha(0.48f);
                        pv.setBackgroundColor(Color.rgb(55, 20, 20));
                        pv.setContentDescription(failureLabel[0] + " • " + item.name);
                    }
                });

                p.prepare();
                p.play();
            }, i * 110L);
        }
        content.addView(grid);

        Button back = actionButton("← CHANNELS", v -> showCatalog(currentItems, currentCatalogTitle));
        content.addView(back);
        setStatus("MOSAIC " + n + " • muted until selected • failed tiles can retry");
    }

    private void selectMosaicAudio(ExoPlayer selected, StreamItem item) {
        for (ExoPlayer p : activePlayers) p.setVolume(p == selected ? 1f : 0f);
        setStatus("AUDIO • " + item.name);
    }

    @androidx.media3.common.util.UnstableApi
    private ExoPlayer createPlayer(StreamItem item) {
        DefaultHttpDataSource.Factory http = new DefaultHttpDataSource.Factory()
                .setConnectTimeoutMs(7000)
                .setReadTimeoutMs(12000)
                .setAllowCrossProtocolRedirects(true)
                .setUserAgent(item.userAgent.isBlank() ? "RAH-Storm-TV-Android/1.0" : item.userAgent);

        if (!item.referrer.isBlank()) {
            Map<String, String> headers = new HashMap<>();
            headers.put("Referer", item.referrer);
            http.setDefaultRequestProperties(headers);
        }

        DefaultMediaSourceFactory media = new DefaultMediaSourceFactory(this)
                .setDataSourceFactory(http);
        ExoPlayer p = new ExoPlayer.Builder(this)
                .setMediaSourceFactory(media)
                .build();
        p.setMediaItem(MediaItem.fromUri(item.url));
        return p;
    }

    private void showFavorites() {
        activeCatalogKey = "";
        Set<String> raw = prefs.getStringSet("favorites", new HashSet<>());
        List<StreamItem> items = new ArrayList<>();
        for (String s : raw) {
            StreamItem x = StreamItem.fromJson(s);
            if (x != null && !x.url.isBlank()) items.add(x);
        }
        currentCatalogTitle = "Favorites";
        showCatalog(items, "Favorites");
    }

    private void toggleFavorite(StreamItem item) {
        Set<String> raw = new HashSet<>(prefs.getStringSet("favorites", new HashSet<>()));
        String remove = null;
        for (String s : raw) {
            StreamItem x = StreamItem.fromJson(s);
            if (x != null && x.key().equals(item.key())) {
                remove = s;
                break;
            }
        }
        if (remove != null) raw.remove(remove);
        else raw.add(item.toJson());
        prefs.edit().putStringSet("favorites", raw).apply();
        Toast.makeText(this, remove == null ? "Added to favorites" : "Removed from favorites",
                Toast.LENGTH_SHORT).show();
    }

    private boolean isFavorite(StreamItem item) {
        return favoriteKeys().contains(item.key());
    }

    private Set<String> favoriteKeys() {
        Set<String> out = new HashSet<>();
        for (String s : prefs.getStringSet("favorites", new HashSet<>())) {
            StreamItem x = StreamItem.fromJson(s);
            if (x != null) out.add(x.key());
        }
        return out;
    }

    private Button actionButton(String label, View.OnClickListener action) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(GOLD);
        b.setAllCaps(false);
        b.setFocusable(true);
        styleButton(b, false);
        b.setOnFocusChangeListener((v, focused) -> styleButton((Button) v, focused));
        b.setOnClickListener(action);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(48));
        lp.setMargins(dp(5), dp(7), dp(5), dp(7));
        b.setLayoutParams(lp);
        return b;
    }

    private void styleButton(Button b, boolean focused) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(7));
        g.setStroke(dp(focused ? 3 : 1), focused ? CYAN : GOLD);
        g.setColor(focused ? Color.rgb(24, 47, 58) : PANEL);
        b.setBackground(g);
        b.setTextColor(focused ? Color.WHITE : GOLD);
    }

    private void styleChannelButton(Button b, boolean focused) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(8));
        g.setStroke(dp(focused ? 3 : 1), focused ? CYAN : Color.rgb(75, 63, 30));
        g.setColor(focused ? Color.rgb(21, 48, 61) : PANEL);
        b.setBackground(g);
        b.setTextColor(focused ? Color.WHITE : TEXT);
    }

    private TextView text(String value, int sp, int color) {
        TextView t = new TextView(this);
        t.setText(value);
        t.setTextSize(sp);
        t.setTextColor(color);
        return t;
    }

    private void setStatus(String value) {
        main.post(() -> {
            if (status != null) status.setText(value);
        });
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void releaseSpecificPlayer(ExoPlayer player, PlayerView view) {
        activePlayers.remove(player);
        if (activeSinglePlayer == player) activeSinglePlayer = null;
        if (view != null && view.getPlayer() == player) view.setPlayer(null);
        try {
            player.release();
        } catch (Exception ignored) {}
    }

    private void releasePlayers() {
        playbackGeneration++;
        for (ExoPlayer p : new ArrayList<>(activePlayers)) {
            try {
                p.release();
            } catch (Exception ignored) {}
        }
        activePlayers.clear();
        activeSinglePlayer = null;
        if (activeSingleView != null) activeSingleView.setPlayer(null);
    }

    private void clearPlaybackUiState() {
        activeSingleItem = null;
        activeSingleView = null;
        activeRetryButton = null;
        activePlayPauseButton = null;
        mosaicVisible = false;
    }

    @Override
    protected void onStart() {
        super.onStart();

        if (mosaicVisible && currentItems != null && !currentItems.isEmpty()) {
            showCatalog(currentItems, currentCatalogTitle);
            setStatus("MOSAIC PAUSED • returned to channels");
            return;
        }

        if (!catalogVisible && activeSingleItem != null && activeSingleView != null &&
                activePlayers.isEmpty()) {
            int generation = playbackGeneration;
            startSinglePlayback(activeSingleView, activeSingleItem, 0, generation, activeRetryButton);
        }
    }

    @Override
    public void onBackPressed() {
        if (!catalogVisible && !currentItems.isEmpty()) {
            showCatalog(currentItems, currentCatalogTitle);
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onStop() {
        super.onStop();
        releasePlayers();
    }

    @Override
    protected void onDestroy() {
        releasePlayers();
        executor.shutdownNow();
        super.onDestroy();
    }
}
