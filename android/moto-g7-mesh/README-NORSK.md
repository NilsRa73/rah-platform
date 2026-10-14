# RAH Moto G7 Mesh — Android-app v1 (candidate)

**Dato:** 14. oktober 2026. **Mål:** En ekte native Android-app for Moto G7 som snakker med RAH Mobile Mesh v2-jobbkoordinatoren på HOVED-PC. **Stable Gate: OPEN** inntil APK er bygget og testet på ekte Moto G7.

## Innhold og funksjoner

- Android Java-prosjekt, API 26–35, svart/gull RAH-grensesnitt, ingen reklame eller betalt API.
- HOVED-PC-helsetest på den faste Tailscale-porten `18885`.
- Paring av `moto-g7` med engangskode fra RAH Mobile Mesh v2-serveren.
- Node-token lagres kryptert via AndroidKeyStore (AES/GCM), ikke i tekstfil/Drive.
- START/STOPP av synlig Android foreground worker. **Ingen automatisk oppstart**.
- `probe`-jobber: ekte v2 claim/result/heartbeat og batteri-/temperaturvern.
- Eksperimentell `llama`-jobb: kobler til **eksisterende lokal** llama.cpp HTTP-server på samme telefon `127.0.0.1:8080/completion` (modell/server installeres ikke). Ingen sky-AI.
- IP-lås til `100.64.0.0/10`, fast port, blokkering av HTTP-redirect, ingen filtilgang / kjøring av eksterne kommandoer.

Dette er **AI-jobbmesh over kryptert Tailscale**, ikke et fysisk Wi-Fi-mesh, mobil hotspot-repeater eller deling av VRAM.

## Viktig: Status for APK

**Kildekode og byggeoppsett er levert, men en ferdig APK er IKKE bygget eller testet i dette ChatGPT-miljøet** fordi Android SDK/Gradle ikke er installert her og nettverkshenting av SDK er utilgjengelig. Ingen APK må kalles verifisert før faktisk Gradle-build og installasjon på Moto G7. Android Studio eller `BUILD-APK-START-HER.cmd` kan bygge den lokalt.

### Bygg med ett klikk på Windows HOVED-PC

1. Pakk ut ZIP; åpne `BUILD-APK-START-HER.cmd` med dobbelklikk. **Ingen administratorrettigheter nødvendig**.
2. Hvis Android SDK mangler: installer gratis [Android Studio](https://developer.android.com/studio) og `Android SDK Platform 35` via SDK Manager. Kjør CMD på nytt. Java er tilgjengelig via Android Studio.
3. CMD laster kun ned **offisiell Gradle 8.11.1** om den mangler, verifiserer SHA-256, bygger appen og åpner APK-mappen.
4. Forventet fil etter PASS: `apk\RAH-MOTO-G7-MESH-v1-debug.apk`.

Alternativt: Åpne prosjektmappen i Android Studio og velg **Build > Build APK(s)**. GitHub Actions-workflowen `.github/workflows/android-apk.yml` kan også bygge når prosjektet legges i en GitHub-repo. Den er ikke kjørt her.

### Installer og par Moto G7

1. På Moto G7: installer **Tailscale** fra offisiell Play Store; logg inn i samme tailnet som HOVED-PC. Android gir VPN-tillatelse til Tailscale.
2. På HOVED-PC: pakk ut **den eksisterende** `RAH-MOBILE-MESH-v2-BIG-BATCH-CANDIDATE.zip`; dobbeltklikk `START-HER.cmd` og start koordinatoren med meny **1**. Bruk meny **2** for å åpne 5-minutters paring av eksakt ID `moto-g7` og noter engangskoden.
3. Overfør APK-filen fra PC til telefonen, åpne den og bekreft installasjon fra den valgte kilden om Android spør. Fjern gjerne tillatelsen etterpå.
4. I **RAH Mesh-appen**: tast HOVED-PCs **Tailscale IPv4** (100.x.x.x), ID `moto-g7`, engangskoden; velg **Test forbindelse**, deretter **Par Moto G7 med kode**.
5. Trykk **Start Mesh-worker**. På HOVED-PC send `probe` mot `moto-g7` med meny **3**, se resultat via meny **4**. Ekte PASS krever `PROBE_OK` fra telefonen.

Lokal AI-modus er **valgfri**, krever en egen allerede kjørende kompatibel `llama-server` på telefonen, med liten GGUF-modell. Moto G7 har begrenset ytelse. Start med `probe`.

## Sikkerhet og avgrensning

- Serveren må lyttes til på HOVED-PCs Tailscale-interface, ikke offentlig. Windows Firewall/Tailscale-grants kan kreve egen konfigurering. Appen endrer dem ikke.
- Android-appen sender bare til `100.64.0.0/10:18885` (og valgfri AI bare til `127.0.0.1:8080`); krypteringen av jobbtrafikk besørges av Tailscale VPN, ikke av HTTP selv.
- Ikke del engangskode, Worker-token, AndroidKeyStore, eller private jobbdata med andre.
- «Slett lokal paring» sletter bare telefonens nøkkel, ikke serverens database; bruk en ny node-ID dersom du ønsker å pare på nytt uten serverreset.
- **GOLD v0.4, Gemma, Raven Bridge og eksisterende RAH Mesh v2 endres ikke** av kildemappen eller APK-en.

## Acceptance

| Test | Status ved levering |
|---|---|
| v2-serverens eget lokalt Python-selvtest | Kjøres som selvtest ved pakking |
| Java-kode/statisk API-kontrakt | Kodekontroll, ingen Android SDK her |
| Gradle bygger signert debug-APK | **IKKE KJØRT** |
| Installasjon Moto G7 | **IKKE KJØRT** |
| Paring / Tailscale / PROBE_OK fra Moto G7 | **IKKE KJØRT** |
| Lokal llama.cpp-inferens Moto G7 | **IKKE KJØRT** |

**Versjon:** `com.rah.mesh` v1.0-candidate, bygget for RAH AI Studios.
