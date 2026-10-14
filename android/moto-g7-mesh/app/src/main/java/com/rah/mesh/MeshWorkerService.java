package com.rah.mesh;

import android.app.*;
import android.content.*;
import android.os.*;
import org.json.JSONObject;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Visible, user-controlled foreground worker. No boot/autostart or remote commands. */
public final class MeshWorkerService extends Service {
    static final String ACTION_STATUS="com.rah.mesh.WORKER_STATUS";
    static final String CHANNEL="rah_mesh_worker";
    private final AtomicBoolean running=new AtomicBoolean(false);
    private Thread thread;
    private int completed=0;
    @Override public IBinder onBind(Intent intent){return null;}
    @Override public void onCreate(){super.onCreate();
        if(Build.VERSION.SDK_INT>=26){NotificationChannel nc=new NotificationChannel(CHANNEL,"RAH Mesh-arbeider",NotificationManager.IMPORTANCE_LOW);
            nc.setDescription("Viser at RAH Mesh sender sikre jobber via Tailscale");
            ((NotificationManager)getSystemService(NOTIFICATION_SERVICE)).createNotificationChannel(nc);
        }
    }
    @Override public int onStartCommand(Intent intent,int flags,int startId){
        startForeground(18785,notice("RAH Mesh starter…"));
        if(running.compareAndSet(false,true)){
            thread=new Thread(this::poll,"RAH-MESH-Worker");thread.start();
        }
        return START_NOT_STICKY; // Explicit tap required after reboot/process death.
    }
    private Notification notice(String status){
        Intent open=new Intent(this,MainActivity.class);
        PendingIntent pi=PendingIntent.getActivity(this,0,open,PendingIntent.FLAG_UPDATE_CURRENT|PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this,CHANNEL).setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("RAH MESH • Moto G7").setContentText(status)
            .setOngoing(true).setContentIntent(pi).build();
    }
    private void event(String text){
        Intent i=new Intent(ACTION_STATUS).setPackage(getPackageName()).putExtra("message",text);
        sendBroadcast(i);
        android.util.Log.i("RAH-Mesh",text.replaceAll("[0-9a-f]{64}","[secret]"));
    }
    private void poll(){
        try {
            SecureStore store=new SecureStore(this);
            String id=store.id(),backend=store.backend();
            MeshApi api=new MeshApi(store.ip(),store.token());
            event("Arbeider aktiv • "+id+" • "+backend);
            while(running.get() && !Thread.currentThread().isInterrupted()){
                try {
                    JSONObject meta=batteryMeta();
                    int percent=meta.optInt("battery_pct",100);
                    double temp=meta.optDouble("battery_temp_c",0);
                    if(percent<35 || (temp>0 && temp>=43)){
                        api.heartbeat(id,backend,meta);
                        event("Pause: batteri "+percent+" % / "+temp+" °C (minst 35 %, under 43 °C)");
                    } else {
                        JSONObject response=api.claim(id,backend,meta);
                        JSONObject job=response.optJSONObject("job");
                        if(job!=null)handle(api,id,backend,job);
                        else if(completed==0) event("Tilkoblet HOVED-PC • venter på jobb");
                    }
                    sleep(5000);
                } catch(Exception e) {
                    event("Forbindelse avbrutt (kontroller Tailscale/HOVED-PC): "+safeError(e));
                    sleep(10000);
                }
            }
        } catch(Exception e){ event("Kan ikke starte: "+safeError(e)); }
        finally {running.set(false);stopSelf();}
    }
    private void handle(MeshApi api,String id,String backend,JSONObject job) throws Exception{
        String jid=job.optString("id",""),type=job.optString("task","");
        if(!jid.matches("[0-9a-f]{20}"))throw new IllegalStateException("Ugyldig jobb-ID");
        boolean ok=true;String result;
        try {
            if("probe".equals(type)){
                result="PROBE_OK "+id+" "+new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'",Locale.ROOT){{setTimeZone(TimeZone.getTimeZone("UTC"));}}.format(new Date());
            } else if("infer".equals(type) && "llama".equals(backend)){
                result=localInference(job.optString("prompt",""));
            } else {throw new IllegalArgumentException("Oppgavetype ikke tillatt i valgt modus");}
        }catch(Exception e){ok=false;result=safeError(e);}
        api.result(id,jid,ok,result);
        completed++;
        event((ok?"PASS ":"FEIL ")+type+" • jobb "+jid.substring(0,8)+" • totalt "+completed);
    }
    private String localInference(String prompt)throws Exception{
        // Only local llama.cpp server on the same phone; never cloud inference.
        if(prompt.trim().isEmpty() || prompt.length()>1200)throw new IllegalArgumentException("Ugyldig prompt");
        HttpURLConnection conn=(HttpURLConnection)new URL("http://127.0.0.1:8080/completion").openConnection(Proxy.NO_PROXY);
        try{
            conn.setConnectTimeout(4000);conn.setReadTimeout(45000);conn.setRequestMethod("POST");
            conn.setDoOutput(true);conn.setInstanceFollowRedirects(false);
            conn.setRequestProperty("Content-Type","application/json");
            byte[] body=new JSONObject().put("prompt",prompt).put("n_predict",64).put("temperature",0.0).toString().getBytes(StandardCharsets.UTF_8);
            try(OutputStream out=conn.getOutputStream()){out.write(body);}
            if(conn.getResponseCode()!=200)throw new IOException("Lokal llama.cpp svarer ikke (HTTP "+conn.getResponseCode()+")");
            try(InputStream in=conn.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] b=new byte[4096];int n;while((n=in.read(b))>0){if(out.size()+n>40000)throw new IOException("AI-svar for stort");out.write(b,0,n);}
                JSONObject r=new JSONObject(out.toString("UTF-8"));
                String content=r.optString("content","").trim();
                if(content.isEmpty())throw new IOException("Lokal modell returnerte ikke tekst");
                return MeshApi.limit(content,15000);
            }
        }finally{conn.disconnect();}
    }
    private JSONObject batteryMeta()throws Exception{
        JSONObject m=new JSONObject().put("platform","android");
        Intent i=registerReceiver(null,new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if(i!=null){
            int level=i.getIntExtra(BatteryManager.EXTRA_LEVEL,-1),scale=i.getIntExtra(BatteryManager.EXTRA_SCALE,-1);
            if(level>=0&&scale>0)m.put("battery_pct",(int)(100.0*level/scale));
            int temp=i.getIntExtra(BatteryManager.EXTRA_TEMPERATURE,-1);
            if(temp>=0)m.put("battery_temp_c",temp/10.0);
        }
        return m;
    }
    private void sleep(long time){try{Thread.sleep(time);}catch(InterruptedException e){Thread.currentThread().interrupt();}}
    private static String safeError(Exception e){
        // Do not display raw network URL or prompts/tokens in the UI, logs, or notification.
        if(e instanceof java.net.SocketTimeoutException)return "Tidsavbrudd";
        if(e instanceof java.net.ConnectException)return "HOVED-PC er utilgjengelig";
        String m=e.getMessage();
        if(m!=null && m.startsWith("HTTP ")) return MeshApi.limit(m,120);
        if(e instanceof IllegalArgumentException)return MeshApi.limit(m,100);
        return e.getClass().getSimpleName();
    }
    @Override public void onDestroy(){running.set(false);if(thread!=null)thread.interrupt();super.onDestroy();}
}
