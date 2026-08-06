# RAH Local Endpoints

Dato: 6. august 2026

Dette dokumentet er den autoritative oversikten over lokale standardadresser for Raven Core.

## Standarder

| Tjeneste | Standardadresse | Formål |
|---|---|---|
| RAH Desktop Bridge / Raven Core | `http://127.0.0.1:18765` | Vision, Council-proxy, Agent Runner, Chronicle og Case Center |
| LM Studio Local Server | `http://127.0.0.1:1234` | Lokal tekst- og vision-AI bak Bridge |

Nye Raven-sider skal fortrinnsvis kalle Bridge på 18765. Bridge videresender godkjente AI-kall til LM Studio på 1234.

## Viktige endepunkter

### Status og brukerflater

- Health: `http://127.0.0.1:18765/health`
- Lokal Vision-side: `http://127.0.0.1:18765/link`
- Case Center: `http://127.0.0.1:18765/case`
- Chronicle: `http://127.0.0.1:18765/chronicle/ui`
- Insights: `http://127.0.0.1:18765/chronicle/insights-ui`
- Daily Brief: `http://127.0.0.1:18765/chronicle/brief-ui`

### Raven Vision

- Aktivt vindu: `GET /capture/active-window`
- Forsinket fangst: `GET /capture/after-delay?seconds=3`
- Modeller gjennom Bridge: `GET /lm/models`
- Vision-analyse: `POST /lm/analyze`

### Raven Council

- Tekstmodell gjennom Bridge: `POST /lm/chat`

Council-proxyen støtter bare tekstmeldinger og returnerer alltid sikkerhetsfeltene:

- `tools_executed: false`
- `automatic_actions: false`

### Agent Runner v0.1

- Allowlist og tilgjengelighet: `GET /agent/capabilities`
- Kjør én eksplisitt bekreftet capability: `POST /agent/run`

`POST /agent/run` krever:

```json
{
  "capability": "test-council",
  "confirm": true
}
```

Agent Runner v0.1:

- aksepterer ikke vilkårlige kommandoer
- bruker aldri `shell=True`
- skriver ikke filer
- krever bekreftelse for hver kjøring
- kan liste prosjektfiler, lese Git-status og kjøre navngitte tester

### Direkte LM Studio – intern bakside

- Modeller: `http://127.0.0.1:1234/v1/models`
- Chat completions: `http://127.0.0.1:1234/v1/chat/completions`

Raven Council og Vision Core skal bruke Bridge-proxyen i stedet for å kalle disse direkte.

## Origin-beskyttelse

Sensitive lokale endepunkter er sperret for fremmede nettsider:

- `/capture/*`
- `/lm/*`
- `/case*`
- `/chronicle*`
- `/agent/*`

Tillatte Origins:

- `null` for lokale `file://`-sider
- `http://127.0.0.1:18765`
- `http://localhost:18765`
- direkte lokale kall uten Origin-header

## Portregel

Ny kode skal ikke hardkode port 8765. Eldre filer som fortsatt bruker 8765 må oppdateres eller arkiveres etter at Vision Core er fysisk testet.

## Lokal konfigurasjon

Gjeldende Raven-sider bruker:

```js
const bridgeBase = localStorage.getItem("rah.bridge.base")
  || "http://127.0.0.1:18765";
```

Adressen lagres lokalt i nettleseren. Hemmeligheter og sensitive data skal ikke ligge i offentlig kode.
