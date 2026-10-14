package com.rah.mesh;

import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.regex.Pattern;

/** Strict v2 protocol client: tailnet-only HOVED-PC, fixed port, bounded JSON. */
final class MeshApi {
    private static final Pattern ID = Pattern.compile("[A-Za-z0-9._-]{1,48}");
    private final String endpoint;
    private final String token;

    static boolean validId(String id) { return id != null && ID.matcher(id).matches(); }
    static boolean validTailIp(String ip) {
        if (ip == null || !ip.matches("[0-9.]{7,15}")) return false;
        String[] p = ip.split("\\.", -1);
        if (p.length != 4) return false;
        try {
            int[] n = new int[4];
            for (int i=0;i<4;i++) {
                if (p[i].length()<1 || p[i].length()>3) return false;
                n[i]=Integer.parseInt(p[i]);
                if (n[i]<0 || n[i]>255 || !Integer.toString(n[i]).equals(p[i])) return false;
            }
            return n[0]==100 && n[1]>=64 && n[1]<=127;
        } catch (NumberFormatException e) { return false; }
    }
    MeshApi(String ip, String token) {
        if (!validTailIp(ip)) throw new IllegalArgumentException("Kun Tailscale IPv4 (100.64–100.127) er tillatt");
        this.endpoint="http://" + ip + ":18885";
        this.token=token;
    }
    JSONObject getHealth() throws Exception { return request("GET", "/health", null); }
    JSONObject enroll(String id, String code) throws Exception {
        if (!validId(id)) throw new IllegalArgumentException("Ugyldig node-ID");
        if (code==null || !code.trim().toUpperCase().matches("[2-9A-HJ-NP-Z]{12}"))
            throw new IllegalArgumentException("Parkode må ha 12 tegn");
        return request("POST", "/enroll/claim", new JSONObject().put("worker_id",id).put("code", code.trim().toUpperCase()));
    }
    JSONObject claim(String id, String backend, JSONObject meta) throws Exception {
        return request("POST", "/claim", new JSONObject().put("worker_id",id).put("backend",backend).put("meta",meta));
    }
    JSONObject heartbeat(String id, String backend, JSONObject meta) throws Exception {
        return request("POST", "/heartbeat", new JSONObject().put("worker_id",id).put("backend",backend).put("meta",meta));
    }
    JSONObject result(String id, String jobId, boolean success, String output) throws Exception {
        JSONObject j=new JSONObject().put("worker_id",id).put("id",jobId).put("status",success?"done":"failed");
        if(success)j.put("output",limit(output,16000)); else j.put("error", limit(output,450));
        return request("POST", "/result", j);
    }
    static String limit(String s, int max) {return s==null?"":s.substring(0,Math.min(max,s.length()));}
    private JSONObject request(String method,String path,JSONObject json) throws Exception {
        if(!path.matches("/(health|enroll/claim|claim|heartbeat|result)"))throw new IllegalArgumentException("Endpoint ikke tillatt");
        HttpURLConnection conn=(HttpURLConnection)new URL(endpoint+path).openConnection(java.net.Proxy.NO_PROXY);
        try {
            conn.setRequestMethod(method);
            conn.setConnectTimeout(7000);
            conn.setReadTimeout(12000);
            conn.setUseCaches(false);
            conn.setInstanceFollowRedirects(false);
            conn.setRequestProperty("Accept","application/json");
            if(token!=null && !token.isEmpty())conn.setRequestProperty("Authorization","Bearer "+token);
            if(json!=null){
                conn.setDoOutput(true);
                conn.setRequestProperty("Content-Type","application/json; charset=utf-8");
                byte[] bytes=json.toString().getBytes(StandardCharsets.UTF_8);
                if(bytes.length>40960)throw new IllegalArgumentException("Melding for stor");
                conn.setFixedLengthStreamingMode(bytes.length);
                try(OutputStream out=conn.getOutputStream()){out.write(bytes);}
            }
            int code=conn.getResponseCode();
            if(code>=300 && code<400) throw new java.io.IOException("Omdirigering er blokkert");
            InputStream raw=code>=400?conn.getErrorStream():conn.getInputStream();
            String s="";
            if(raw!=null){
                try(InputStream in=raw;ByteArrayOutputStream buf=new ByteArrayOutputStream()){
                    byte[] block=new byte[2048];int len;
                    while((len=in.read(block))!=-1){
                        if(buf.size()+len>80000)throw new java.io.IOException("Svar for stort");
                        buf.write(block,0,len);
                    }
                    s=buf.toString("UTF-8");
                }
            }
            JSONObject data=new JSONObject(s.isEmpty()?"{}":s);
            if(code<200||code>=300)throw new java.io.IOException("HTTP "+code+": "+limit(data.optString("error","Serverfeil"),130));
            return data;
        } finally {conn.disconnect();}
    }
}
