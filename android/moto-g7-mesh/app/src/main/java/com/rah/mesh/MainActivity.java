package com.rah.mesh;

import android.Manifest;
import android.app.*;
import android.os.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.graphics.*;
import android.graphics.drawable.GradientDrawable;
import android.text.InputType;
import android.view.*;
import android.widget.*;
import org.json.JSONObject;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private final int BG=Color.rgb(9,12,18), PANEL=Color.rgb(20,25,34), GOLD=Color.rgb(246,198,91), WHITE=Color.rgb(245,243,235), MUTED=Color.rgb(171,179,192);
    private EditText ip,id,code;
    private TextView status,paired,mode;
    private Button start,stop;
    private SecureStore store;
    private final ExecutorService io=Executors.newSingleThreadExecutor();
    private BroadcastReceiver events;
    private boolean active=false;
    @Override public void onCreate(Bundle b){super.onCreate(b);
        getWindow().setStatusBarColor(BG);getWindow().setNavigationBarColor(BG);
        store=new SecureStore(this);build();refresh();
        events=new BroadcastReceiver(){@Override public void onReceive(Context c,Intent i){setStatus(i.getStringExtra("message"));}};
    }
    @Override protected void onStart(){super.onStart();
        IntentFilter f=new IntentFilter(MeshWorkerService.ACTION_STATUS);
        if(Build.VERSION.SDK_INT>=33)registerReceiver(events,f,Context.RECEIVER_NOT_EXPORTED);
        else registerReceiver(events,f);
    }
    @Override protected void onStop(){unregisterReceiver(events);super.onStop();}
    @Override protected void onDestroy(){io.shutdownNow();super.onDestroy();}
    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private GradientDrawable bg(int c,int r){GradientDrawable g=new GradientDrawable();g.setColor(c);g.setCornerRadius(dp(r));return g;}
    private TextView txt(String s,int sp,int color,boolean bold){
        TextView t=new TextView(this);t.setText(s);t.setTextSize(sp);t.setTextColor(color);
        if(bold)t.setTypeface(null,1);return t;
    }
    private void build(){
        ScrollView scroll=new ScrollView(this);scroll.setFillViewport(true);scroll.setBackgroundColor(BG);
        LinearLayout root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(dp(22),dp(22),dp(22),dp(32));
        scroll.addView(root);setContentView(scroll);
        TextView mark=txt("RAH  /  AI STUDIOS",13,GOLD,true);root.addView(mark);
        TextView title=txt("MOBILE MESH",32,WHITE,true);title.setPadding(0,dp(9),0,dp(4));root.addView(title);
        TextView sub=txt("MOTO G7  •  TAILSCALE NODE",13,MUTED,true);root.addView(sub);
        TextView info=txt("Koble mobilen til RAH Mesh v2 på HOVED-PC. Gratis, privat og uten endringer i dine stabile tjenester.",15,MUTED,false);
        info.setPadding(0,dp(16),0,dp(16));root.addView(info);
        LinearLayout card=new LinearLayout(this);card.setOrientation(LinearLayout.VERTICAL);card.setPadding(dp(16),dp(18),dp(16),dp(16));card.setBackground(bg(PANEL,16));
        LinearLayout.LayoutParams cardLp=new LinearLayout.LayoutParams(-1,-2);cardLp.bottomMargin=dp(16);root.addView(card,cardLp);
        paired=txt("IKKE PARET",13,GOLD,true);card.addView(paired);
        status=txt("Ikke koblet til",15,WHITE,false);status.setPadding(0,dp(8),0,dp(8));card.addView(status);
        TextView h=txt("01   KOBLE TIL HOVED-PC",15,GOLD,true);h.setPadding(0,dp(12),0,dp(8));root.addView(h);
        ip=field(root,"Tailscale-IP på HOVED-PC (100.x.x.x)",store.ip(),InputType.TYPE_CLASS_PHONE);
        id=field(root,"Node-ID",store.id(),InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        code=field(root,"Engangs-paringskode (12 tegn)","",InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS|InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        button(root,"TEST FORBINDELSE",false,()->{
            String address=ip.getText().toString().trim();execute(()->{JSONObject j=new MeshApi(address,"").getHealth();
            if(!"RAH Mobile Mesh".equals(j.optString("app"))||!j.optString("version","").startsWith("2."))throw new IllegalStateException("Ikke en RAH Mesh v2-koordinator");
            return "HOVED-PC online • "+j.optString("app","RAH Mesh")+" v"+j.optString("version","?");
        });});
        button(root,"PAR MOTO G7 MED KODE",true,()->{
            String address=ip.getText().toString().trim(),name=id.getText().toString().trim().toLowerCase(java.util.Locale.ROOT),pairCode=code.getText().toString();
            execute(()->{MeshApi client=new MeshApi(address,"");JSONObject health=client.getHealth();
            if(!"RAH Mobile Mesh".equals(health.optString("app"))||!health.optString("version","").startsWith("2."))throw new IllegalStateException("Ikke RAH Mesh v2");
            JSONObject r=client.enroll(name,pairCode);
            store.save(address,name,r.getString("worker_token"));
            runOnUiThread(()->{code.setText("");refresh();});
            return "Paring fullført • "+name+" • nøkkel lagret sikkert";
        });});
        TextView h2=txt("02   START MOBIL-NODE",15,GOLD,true);h2.setPadding(0,dp(24),0,dp(10));root.addView(h2);
        mode=txt("Modus: PROBE (nettverkstest, ikke AI-inferens)",14,MUTED,false);root.addView(mode);
        button(root,"VELG PROBE / LOKAL AI",false,()->showModePicker());
        start=button(root,"START MESH-WORKER",true,()->{
            if(!store.paired()){setStatus("Du må pare mobilen først.");return;}
            if(Build.VERSION.SDK_INT>=33&&checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)
                requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS},310);
            try{
                Intent service=new Intent(this,MeshWorkerService.class);
                if(Build.VERSION.SDK_INT>=26)startForegroundService(service);else startService(service);
                active=true;setStatus("Starter node • se statusvarsling øverst");
            }catch(Exception e){setStatus("Kunne ikke starte: "+e.getClass().getSimpleName());}
        });
        stop=button(root,"STOPP MESH-WORKER",false,()->{
            stopService(new Intent(this,MeshWorkerService.class));active=false;setStatus("Arbeider stoppet manuelt");
        });
        TextView h3=txt("03   SIKKERHET OG HJELP",15,GOLD,true);h3.setPadding(0,dp(22),0,dp(6));root.addView(h3);
        TextView expl=txt("• Tailscale må være aktivt på både Moto G7 og HOVED-PC.\n• HOVED-PC må kjøre RAH Mobile Mesh v2-koordinatoren på port 18885.\n• Først oppretter du en engangskode for moto-g7 på HOVED-PC (meny 2).\n• PROBE kjører testjobber. AI-modus krever egen llama.cpp-server på telefonen, kun localhost:8080.\n• Batteri under 35 % eller temperatur 43 °C og høyere pauser nye jobber.\n• Ingen automatisk oppstart eller betalte tjenester.",14,MUTED,false);
        expl.setPadding(0,dp(5),0,dp(12));root.addView(expl);
        button(root,"SLETT LOKAL PARING",false,()->new AlertDialog.Builder(this).setTitle("Slette paring?")
            .setMessage("Lokal nøkkel slettes. HOVED-PC beholder registreringen; du må bruke en ny node-ID ved ny paring hvis server ikke resettes.")
            .setNegativeButton("Avbryt",null).setPositiveButton("Slett",(d,w)->{
                stopService(new Intent(this,MeshWorkerService.class));store.clear();refresh();setStatus("Lokal paring slettet");
            }).show());
        TextView tail=txt("RAH MESH  •  CANDIDATE v1.0  •  STABLE GATE OPEN",11,MUTED,true);tail.setPadding(0,dp(22),0,0);root.addView(tail);
    }
    private EditText field(LinearLayout root,String hint,String value,int type){
        EditText e=new EditText(this);e.setTextColor(WHITE);e.setHintTextColor(MUTED);e.setTextSize(15);
        e.setSingleLine(true);e.setHint(hint);e.setText(value);e.setInputType(type);
        e.setPadding(dp(14),dp(14),dp(14),dp(14));e.setBackground(bg(PANEL,12));
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,dp(55));p.bottomMargin=dp(10);root.addView(e,p);return e;
    }
    private Button button(LinearLayout root,String label,boolean filled,Runnable tap){
        Button b=new Button(this);b.setText(label);b.setTextSize(13);b.setAllCaps(false);
        b.setTextColor(filled?BG:GOLD);b.setBackground(bg(filled?GOLD:PANEL,12));
        LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,dp(52));p.bottomMargin=dp(9);root.addView(b,p);
        b.setOnClickListener(v->tap.run());return b;
    }
    private void showModePicker(){
        String[] items={"PROBE – sikker nettverkstest","LLAMA – lokal AI på 127.0.0.1:8080"};
        new AlertDialog.Builder(this).setTitle("Velg arbeider-modus")
            .setSingleChoiceItems(items,"llama".equals(store.backend())?1:0,(d,which)->{
                store.setBackend(which==0?"probe":"llama");refresh();d.dismiss();
            }).setNegativeButton("Avbryt",null).show();
    }
    private void execute(CheckedTask task){
        setStatus("Kontrollerer …");
        io.submit(()->{
            try{String out=task.run();runOnUiThread(()->setStatus(out));}
            catch(Exception e){String msg=e.getMessage();
                // Suppress any unexpected URL/data in UI; API errors are bounded.
                if(msg==null||msg.contains("http://")||msg.contains("Bearer")||msg.length()>150)msg=e.getClass().getSimpleName();
                final String safe=msg;runOnUiThread(()->setStatus("FEIL: "+safe));
            }
        });
    }
    private void setStatus(String m){status.setText(m==null?"":m);}
    private void refresh(){
        if(paired!=null){paired.setText(store.paired()?"PARET / KLAR":"IKKE PARET");
            mode.setText("Modus: "+store.backend().toUpperCase()+("llama".equals(store.backend())?" • egen lokal llama.cpp-server nødvendig":" • kun jobbtest"));
        }
    }
    @FunctionalInterface private interface CheckedTask{String run()throws Exception;}
}
