package com.rah.stormtv;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public final class CatalogRepository {
    public static final String BANGLADESH_TV = "https://iptv-org.github.io/iptv/countries/bd.m3u";
    public static final String WORLD_TV = "https://iptv-org.github.io/iptv/index.country.m3u";

    private CatalogRepository() {}

    public static List<StreamItem> loadM3u(String url, String fallbackRegion, int limit) throws Exception {
        String text = get(url);
        List<StreamItem> out = new ArrayList<>();

        String pendingName = "";
        String pendingGroup = fallbackRegion;
        String pendingLogo = "";
        String pendingReferrer = "";
        String pendingUserAgent = "";
        boolean waitingForUrl = false;

        for (String raw : text.split("\n")) {
            String line = raw.trim();
            if (line.isEmpty()) continue;

            if (line.startsWith("#EXTINF:")) {
                int comma = line.indexOf(',');
                pendingName = comma >= 0 ? line.substring(comma + 1).trim() : "Channel";
                pendingGroup = attr(line, "group-title");
                if (pendingGroup.isBlank()) pendingGroup = fallbackRegion;
                pendingLogo = attr(line, "tvg-logo");
                pendingReferrer = "";
                pendingUserAgent = "";
                waitingForUrl = true;
                continue;
            }

            if (waitingForUrl && line.startsWith("#EXTVLCOPT:http-referrer=")) {
                pendingReferrer = line.substring("#EXTVLCOPT:http-referrer=".length()).trim();
                continue;
            }
            if (waitingForUrl && line.startsWith("#EXTVLCOPT:http-user-agent=")) {
                pendingUserAgent = line.substring("#EXTVLCOPT:http-user-agent=".length()).trim();
                continue;
            }

            if (waitingForUrl && !line.startsWith("#") &&
                    (line.startsWith("http://") || line.startsWith("https://"))) {
                out.add(new StreamItem(
                        pendingName, line, pendingGroup, pendingLogo, "tv",
                        pendingReferrer, pendingUserAgent
                ));
                waitingForUrl = false;
                if (out.size() >= limit) break;
            }
        }
        return out;
    }

    public static List<StreamItem> loadBangladeshRadio(int limit) throws Exception {
        String[] mirrors = {
                "https://de1.api.radio-browser.info",
                "https://nl1.api.radio-browser.info"
        };
        Exception last = null;
        for (String host : mirrors) {
            try {
                String endpoint = host + "/json/stations/search?countrycode=BD&hidebroken=true&order=clickcount&reverse=true&limit=" + limit;
                JSONArray a = new JSONArray(get(endpoint));
                List<StreamItem> out = new ArrayList<>();
                for (int i = 0; i < a.length() && out.size() < limit; i++) {
                    JSONObject o = a.optJSONObject(i);
                    if (o == null || o.optInt("lastcheckok", 1) == 0) continue;
                    String u = o.optString("url_resolved", o.optString("url"));
                    if (u == null || u.isBlank()) continue;
                    String details = o.optString("country", "Bangladesh");
                    String codec = o.optString("codec");
                    int bitrate = o.optInt("bitrate", 0);
                    if (!codec.isBlank() || bitrate > 0) {
                        details += " • " + codec.toUpperCase(Locale.ROOT) + (bitrate > 0 ? " " + bitrate + " kbps" : "");
                    }
                    out.add(new StreamItem(
                            o.optString("name", "Radio"),
                            u,
                            details,
                            o.optString("favicon"),
                            "radio",
                            "",
                            ""
                    ));
                }
                if (!out.isEmpty()) return out;
            } catch (Exception e) {
                last = e;
            }
        }
        throw last != null ? last : new Exception("No radio mirror available");
    }

    private static String attr(String line, String key) {
        String marker = key + "=\"";
        int start = line.indexOf(marker);
        if (start < 0) return "";
        start += marker.length();
        int end = line.indexOf('"', start);
        return end > start ? line.substring(start, end) : "";
    }

    private static String get(String url) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        c.setConnectTimeout(9000);
        c.setReadTimeout(15000);
        c.setInstanceFollowRedirects(true);
        c.setRequestProperty("User-Agent", "RAH-Storm-TV-Android/1.0");
        int code = c.getResponseCode();
        if (code < 200 || code >= 400) throw new Exception("HTTP " + code + " for " + url);
        try (BufferedReader r = new BufferedReader(
                new InputStreamReader(c.getInputStream(), StandardCharsets.UTF_8))) {
            StringBuilder b = new StringBuilder();
            String line;
            while ((line = r.readLine()) != null) b.append(line).append('\n');
            return b.toString();
        } finally {
            c.disconnect();
        }
    }
}
