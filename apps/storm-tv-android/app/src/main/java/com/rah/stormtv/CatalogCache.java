package com.rah.stormtv;

import android.content.SharedPreferences;

import org.json.JSONArray;

import java.util.ArrayList;
import java.util.List;

public final class CatalogCache {
    private static final String PREFIX = "catalog_cache_v1_";

    private final SharedPreferences prefs;

    public CatalogCache(SharedPreferences prefs) {
        this.prefs = prefs;
    }

    public List<StreamItem> load(String key) {
        List<StreamItem> out = new ArrayList<>();
        String raw = prefs.getString(PREFIX + key, "");
        if (raw == null || raw.isBlank()) return out;

        try {
            JSONArray array = new JSONArray(raw);
            for (int i = 0; i < array.length(); i++) {
                StreamItem item = StreamItem.fromJson(array.optString(i, ""));
                if (item != null && !item.url.isBlank()) out.add(item);
            }
        } catch (Exception ignored) {
            prefs.edit().remove(PREFIX + key).apply();
        }
        return out;
    }

    public void save(String key, List<StreamItem> items) {
        if (items == null || items.isEmpty()) return;
        JSONArray array = new JSONArray();
        for (StreamItem item : items) {
            if (item != null && !item.url.isBlank()) array.put(item.toJson());
        }
        if (array.length() > 0) {
            prefs.edit().putString(PREFIX + key, array.toString()).apply();
        }
    }
}
