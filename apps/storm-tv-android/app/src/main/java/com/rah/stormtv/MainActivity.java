package com.rah.stormtv;

import android.app.Activity;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.DisplayMetrics;
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

public class MainActivity extends Activity {
    private static final int BG = Color.rgb(5, 7, 10);
    private static final int PANEL = Color.rgb(15, 20, 27);
    private static final int GOLD = Color.rgb(244, 200, 74);
    private static final int CYAN = Color.rgb(35, 200, 255);
    private static final int TEXT = Color.rgb(242, 239, 228);
    private static final int MUTED = Color.rgb(159, 166, 176);

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private final List<ExoPlayer> activePlayers = new ArrayList<>();

    private LinearLayout root;
    private LinearLayout content;
    private TextView status;
    private SharedPreferences prefs;

    private List<StreamItem> currentItems = new ArrayList<>();
    private String currentCatalogTitle = "Bangladesh TV";
    private boolean catalogVisible = true;
    private int playbackGeneration = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window w = getWindow();
        w.setStatusBarColor(BG);
        w.setNavigationBarColor(BG);
        prefs = getSharedPreferences("rah_storm_tv", MODE_PRIVATE);
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
        title.setTypeface(null, 1);
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
        addNav(nav, "📻 RADIO", v -> loadRadio());
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
        currentCatalogTitle = "Bangladesh TV";
        showLoading("Loading Bangladesh TV…");
        executor.submit(() -> {
            try {
                List<StreamItem> items = CatalogRepository.loadM3u(
                        CatalogRepository.BANGLADESH_TV, "Bangladesh", 200);
                main.post(() -> showCatalog(items, "Bangladesh TV"));
            } catch (Exception e) {
                main.post(() -> showError("Bangladesh TV", e));
            }
        });
    }

    private void loadWorldTv() {
        currentCatalogTitle = "World TV";
        showLoading("Loading World TV…");
        executor.submit(() -> {
            try {
                List<StreamItem> items = CatalogRepository.loadM3u(
                        CatalogRepository.WORLD_TV, "World", 300);
                main.post(() -> showCatalog(items, "World TV • first 300 public streams"));
            } catch (Exception e) {
                main.post(() -> showError("World TV", e));
            }
        });
    }

    private void loadRadio() {
        currentCatalogTitle = "Bangladesh Radio";
        showLoading("Loading Bangladesh radio…");
        executor.submit(() -> {
            try {
                List<StreamItem> items = CatalogRepository.loadBangladeshRadio(100);
                main.post(() -> showCatalog(items, "Bangladesh Radio"));
            } catch (Exception e) {
                main.post(() -> showError("Bangladesh Radio", e));
            }
        });
    }

    private void refreshCurrent() {
        if (currentCatalogTitle.startsWith("World")) loadWorldTv();
        else if (currentCatalogTitle.contains("Radio")) loadRadio();
        else if (currentCatalogTitle.contains("Favorite")) showFavorites();
        else loadBangladeshTv();
    }

    private void showLoading(String message) {
        releasePlayers();
        catalogVisible = false;
        content.removeAllViews();
        ProgressBar p = new ProgressBar(this);
        content.addView(p, new LinearLayout.LayoutParams(dp(54), dp(54)));
        TextView t = text(message, 16, TEXT);
        t.setGravity(Gravity.CENTER);
        content.addView(t);
        setStatus(message);
    }

    private void showError(String source, Exception e) {
        releasePlayers();
        content.removeAllViews();
        TextView t = text(source + " could not load.\n\n" + e.getMessage() +
                "\n\nPress REFRESH to try again.", 16, TEXT);
        t.setGravity(Gravity.CENTER);
        t.setPadding(dp(25), dp(35), dp(25), dp(35));
        content.addView(t);
        setStatus("ERROR • " + source);
    }

    private void showCatalog(List<StreamItem> items, String title) {
        releasePlayers();
        currentItems = new ArrayList<>(items);
        currentCatalogTitle = title;
        catalogVisible = true;
        content.removeAllViews();

        TextView heading = text(title + " • " + items.size() + " channels", 16, GOLD);
        heading.setTypeface(null, 1);
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
        setStatus(title + " • public streams • long-press a channel to favorite");
    }

    private void playSingle(StreamItem item) {
        releasePlayers();
        catalogVisible = false;
        content.removeAllViews();

        TextView heading = text(item.name + (item.region.isBlank() ? "" : " • " + item.region), 16, GOLD);
        heading.setPadding(dp(5), dp(4), dp(5), dp(6));
        content.addView(heading);

        PlayerView view = new PlayerView(this);
        view.setUseController(true);
        view.setFocusable(true);
        view.setKeepScreenOn(true);
        ExoPlayer player = createPlayer(item);
        view.setPlayer(player);
        activePlayers.add(player);

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
        row.addView(back);
        row.addView(fav);
        content.addView(row);

        player.addListener(new Player.Listener() {
            @Override public void onPlaybackStateChanged(int state) {
                if (state == Player.STATE_READY) setStatus("LIVE • " + item.name);
                else if (state == Player.STATE_BUFFERING) setStatus("BUFFERING • " + item.name);
            }
            @Override public void onPlayerError(androidx.media3.common.PlaybackException error) {
                setStatus("STREAM FAILED • choose another channel");
            }
        });
        player.prepare();
        player.play();
    }

    private void showMosaic(int requested) {
        List<StreamItem> tv = new ArrayList<>();
        for (StreamItem x : currentItems) if ("tv".equals(x.type)) tv.add(x);
        if (tv.isEmpty()) {
            Toast.makeText(this, "Open Bangladesh TV or World TV first.", Toast.LENGTH_SHORT).show();
            return;
        }

        releasePlayers();
        catalogVisible = false;
        content.removeAllViews();
        int n = Math.min(requested, tv.size());
        int cols = (int) Math.ceil(Math.sqrt(n));
        int rows = (int) Math.ceil((double) n / cols);
        int generation = ++playbackGeneration;

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
                p.setVolume(0f);
                pv.setPlayer(p);
                activePlayers.add(p);
                pv.setOnClickListener(v -> selectMosaicAudio(p, item));
                pv.setOnFocusChangeListener((v, focused) -> {
                    if (focused) {
                        v.setBackgroundColor(GOLD);
                        setStatus("FOCUS • " + item.name + " • press OK for sound");
                    } else {
                        v.setBackgroundColor(Color.BLACK);
                    }
                });
                p.prepare();
                p.play();
            }, i * 110L);
        }
        content.addView(grid);

        Button back = actionButton("← CHANNELS", v -> showCatalog(currentItems, currentCatalogTitle));
        content.addView(back);
        setStatus("MOSAIC " + n + " • local Android decoding • muted until selected");
    }

    private void selectMosaicAudio(ExoPlayer selected, StreamItem item) {
        for (ExoPlayer p : activePlayers) p.setVolume(p == selected ? 1f : 0f);
        setStatus("AUDIO • " + item.name);
    }

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
        main.post(() -> status.setText(value));
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    private void releasePlayers() {
        playbackGeneration++;
        for (ExoPlayer p : activePlayers) {
            try { p.release(); } catch (Exception ignored) {}
        }
        activePlayers.clear();
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
