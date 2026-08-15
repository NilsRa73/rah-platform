# RAH Raven Care — hovedkart

Dato: 6. august 2026

## Hovedprosjekt

**RAH Raven Care** er paraplyen. Det er ett pasientstyrt støtte- og samhandlingssystem, ikke mange uavhengige programmer.

Målet er å hjelpe pasienter med å samle, forstå og følge opp helseopplysninger, målinger, dokumenter, henvisninger, avtaler, frister og egne forklaringer. AI gjør forarbeid og finner mangler, men pasienten og fagpersonen beholder kontroll og godkjenning.

## Produktstruktur

### 1. Raven Case Center — kjernen

Status: fungerende nettleserprototype.

Funksjoner:
- dokumentinnboks
- kronologisk tidslinje
- skille mellom dokumentert faktum, pasientopplysning, faglig tolkning og uavklart forhold
- Missing Evidence Finder
- møteforberedelse
- godkjenningsdesk
- lokal rapport og eksport
- lokal lagring og ingen automatisk sending

Fil: `RAH-RAVEN-CASE-CENTER.html`

### 2. Raven Health & Fatigue — helsemodulen

Status: definert, men ikke ferdig programmert som egen modul.

Planlagte funksjoner:
- daglig fatigue 0–10
- funksjonsnivå og dagsform
- søvnlengde og søvnkvalitet
- puls og hvilepuls
- blodsukker og HbA1c
- medisin- og bivirkningstidslinje
- aktivitet og eventuell forsinket forverring
- mønsteranalyse med tydelig beskjed om at korrelasjon ikke er bevist årsak
- fastlegeoversikt for siste 7, 30 og 90 dager

### 3. Raven Fristvakt — rettighetsmodulen

Status: fungerende nettleserprototype.

Funksjoner:
- henvisningsdato
- vurderingsbrev
- rett til nødvendig helsehjelp
- bindende frist
- første oppmøte
- mulig fristbrudd
- kontroll av Helfo-varsling
- konkret neste handling
- lokal JSON-eksport

Fil: `RAH-RAVEN-FRISTVAKT.html`

### 4. Raven Fastlegevisning — fagpersonens korte oversikt

Status: designet og beskrevet, men ikke ferdig programmert som egen visning.

Skal vise:
- tre viktigste temaer
- kort tidslinje
- siste prøver og egenmålinger
- medisiner og endringer
- uavklarte spørsmål
- ansvarlig person og neste frist
- direkte kilde bak hver opplysning
- hva pasienten ønsker av konsultasjonen

Målet er å bruke mindre konsultasjonstid på å rekonstruere historikken muntlig.

### 5. Raven Samspill — fremtidig integrasjonslag

Status: konsept og langtidsmål.

Skal på sikt koble godkjente datakilder fra:
- Helsenorge
- spesialisthelsetjenesten
- fastlege
- NAV
- kommune
- blodsukkermåler
- smartklokke
- pasientens egne dokumenter

Krever samarbeid, godkjente API-er, sikker identitet, samtykke, rollebasert tilgang, logging og personvernvurdering. MVP-en skal ikke forsøke å omgå innlogging eller hente data skjult.

### 6. UNN innovasjonspilot — veien til utprøving

Status: skriftlig innovasjonspitch ferdig.

Foreslått pilot:
- syntetiske eller avidentifiserte data først
- 5–10 frivillige brukere senere dersom godkjent
- tidslinje, møteark, prøvesvar, fatigue og egenmålinger
- behandlerens kontrollpanel
- måling av tidsbruk, forståelse, oppfølging og brukervennlighet

Fil: `UNN-INNOVASJON-PITCH.md`

## Det som faktisk er ferdig eller kandidatklart

- `RAH-RAVEN-CARE.html` — v0.1 dashboard med lokal navigasjon til Case Center og Fristvakt
- `RAH-RAVEN-CASE-CENTER.html`
- `RAH-RAVEN-FRISTVAKT.html`
- `RAH-RAVEN-CASE-CENTER-SPEC.md`
- `UNN-INNOVASJON-PITCH.md`
- Case Center-lenke i `RAH-RAVEN-START.html`
- demoillustrasjoner til presentasjon

## Det som ikke er ferdig ennå

- Health & Fatigue og Fastlegevisning inne i `RAH-RAVEN-CARE.html`
- automatisk import fra blodsukkermåler
- smartklokke-, puls- og søvnsynkronisering
- automatisk forklaring av blodprøver på vanlig norsk
- godkjent innlogging mot Helsenorge, NAV eller kommune
- sikker fagpersonportal
- automatisk kildebasert AI-analyse av alle dokumenter
- integrert Fristvakt inne i hovedappen
- formell innsending eller pilotavtale med UNN

## Riktig utviklingsrekkefølge

1. Slå sammen Case Center og Fristvakt under ett Raven Care-dashboard.
2. Bygg Health & Fatigue med manuell registrering og CSV-import.
3. Lag fastlegevisning og utskriftsvennlig demo.
4. Koble lokal dokumentuttrekking og LM Studio med kildehenvisninger.
5. Test med syntetiske data og få tilbakemelding fra fastlege.
6. Presentér pilotforslaget for UNN Innovasjon.
7. Vurder offisielle integrasjoner først etter sikkerhets- og personvernavklaring.

## Fast produktregel

**AI forbereder. Pasienten korrigerer. Fagpersonen godkjenner. Ingenting viktig forsvinner.**
