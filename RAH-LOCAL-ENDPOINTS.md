# RAH Local Endpoints

Dato: 6. august 2026

Dette dokumentet er den autoritative oversikten over lokale standardadresser for Raven Core.

## Standarder

| Tjeneste | Standardadresse | Formål |
|---|---|---|
| RAH Desktop Bridge v1.6/v1.7 | `http://127.0.0.1:18765` | Vision-fangst, Chronicle, Case Center og tillatte lokale handlinger |
| LM Studio Local Server | `http://127.0.0.1:1234` | Lokal tekst- og vision-AI |

## Viktige endepunkter

### Desktop Bridge

- Health: `http://127.0.0.1:18765/health`
- Aktivt vindu: `http://127.0.0.1:18765/capture/active-window`
- Lokal Vision-side: `http://127.0.0.1:18765/link`
- Case Center: `http://127.0.0.1:18765/case`
- Chronicle: `http://127.0.0.1:18765/chronicle/ui`
- Insights: `http://127.0.0.1:18765/chronicle/insights-ui`
- Daily Brief: `http://127.0.0.1:18765/chronicle/brief-ui`

### LM Studio

- Modeller: `http://127.0.0.1:1234/v1/models`
- Chat completions: `http://127.0.0.1:1234/v1/chat/completions`

## Regel

Ny kode skal ikke hardkode port 8765. Eldre filer som fortsatt bruker 8765 må oppdateres eller lese adressen fra en delt konfigurasjon.

## Planlagt delt konfigurasjon

```js
window.RAH_LOCAL = {
  bridgeBase: "http://127.0.0.1:18765",
  lmBase: "http://127.0.0.1:1234"
};
```

På sikt skal brukerens valgte adresser kunne lagres lokalt uten at hemmeligheter eller sensitive data legges i offentlig kode.
