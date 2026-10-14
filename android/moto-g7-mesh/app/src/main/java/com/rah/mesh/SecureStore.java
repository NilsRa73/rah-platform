package com.rah.mesh;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Keeps the per-device worker token encrypted with AndroidKeyStore; no Google Drive backup. */
final class SecureStore {
    private static final String ALIAS="rah_mesh_worker_aes_v1";
    private final SharedPreferences prefs;
    SecureStore(Context context){prefs=context.getSharedPreferences("mesh_config",Context.MODE_PRIVATE);}
    String ip(){return prefs.getString("ip","");}
    String id(){return prefs.getString("id","moto-g7");}
    String backend(){return prefs.getString("backend","probe");}
    void setBackend(String backend){prefs.edit().putString("backend",backend).apply();}
    boolean paired(){return !prefs.getString("secret","").isEmpty();}
    void save(String ip,String id,String token) throws Exception {
        if(!MeshApi.validTailIp(ip)||!MeshApi.validId(id)||token==null||!token.matches("[0-9a-f]{64}"))
            throw new IllegalArgumentException("Ugyldig paringsdata");
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");ks.load(null);
        if(!ks.containsAlias(ALIAS)){
            KeyGenerator gen=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            gen.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            gen.generateKey();
        }
        SecretKey key=((KeyStore.SecretKeyEntry)ks.getEntry(ALIAS,null)).getSecretKey();
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,key);
        byte[] iv=c.getIV();byte[] ciphertext=c.doFinal(token.getBytes(StandardCharsets.UTF_8));
        prefs.edit().putString("ip",ip).putString("id",id).putString("secret",Base64.encodeToString(ciphertext,Base64.NO_WRAP))
            .putString("iv",Base64.encodeToString(iv,Base64.NO_WRAP)).putString("backend","probe").commit();
    }
    String token() throws Exception {
        String enc=prefs.getString("secret","");if(enc.isEmpty())throw new IllegalStateException("Enheten er ikke paret");
        KeyStore ks=KeyStore.getInstance("AndroidKeyStore");ks.load(null);
        SecretKey key=((KeyStore.SecretKeyEntry)ks.getEntry(ALIAS,null)).getSecretKey();
        Cipher c=Cipher.getInstance("AES/GCM/NoPadding");
        c.init(Cipher.DECRYPT_MODE,key,new GCMParameterSpec(128,Base64.decode(prefs.getString("iv",""),Base64.NO_WRAP)));
        return new String(c.doFinal(Base64.decode(enc,Base64.NO_WRAP)),StandardCharsets.UTF_8);
    }
    void clear(){prefs.edit().clear().commit();}
}
