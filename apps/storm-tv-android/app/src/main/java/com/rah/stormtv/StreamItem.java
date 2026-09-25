package com.rah.stormtv;

import org.json.JSONObject;

public class StreamItem {
    public final String name;
    public final String url;
    public final String region;
    public final String logo;
    public final String type;
    public final String referrer;
    public final String userAgent;

    public StreamItem(String name, String url, String region, String logo, String type,
                      String referrer, String userAgent) {
        this.name = name == null || name.isBlank() ? "Channel" : name.trim();
        this.url = url == null ? "" : url.trim();
        this.region = region == null ? "" : region.trim();
        this.logo = logo == null ? "" : logo.trim();
        this.type = type == null ? "tv" : type;
        this.referrer = referrer == null ? "" : referrer.trim();
        this.userAgent = userAgent == null ? "" : userAgent.trim();
    }

    public String key() {
        return type + "|" + url;
    }

    public String toJson() {
        JSONObject o = new JSONObject();
        try {
            o.put("name", name);
            o.put("url", url);
            o.put("region", region);
            o.put("logo", logo);
            o.put("type", type);
            o.put("referrer", referrer);
            o.put("userAgent", userAgent);
        } catch (Exception ignored) {}
        return o.toString();
    }

    public static StreamItem fromJson(String raw) {
        try {
            JSONObject o = new JSONObject(raw);
            return new StreamItem(
                    o.optString("name"),
                    o.optString("url"),
                    o.optString("region"),
                    o.optString("logo"),
                    o.optString("type", "tv"),
                    o.optString("referrer"),
                    o.optString("userAgent")
            );
        } catch (Exception e) {
            return null;
        }
    }
}
