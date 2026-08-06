# RAH Master Execution Plan 2026–2027

Dato: 6. august 2026

## Formål

Denne planen skal gjøre alle RAH-idéer håndterbare og avsluttbare. Målet er ikke at alle ideer skal bygges samtidig. Målet er at hver idé får ett tydelig utfall:

1. ferdig fungerende MVP
2. slått sammen med et annet prosjekt
3. parkert med begrunnelse og senere dato
4. avsluttet som konsept og dokumentert

Ingen idé skal bli hengende som et uklart halvprosjekt.

## Hovedstruktur

Alle prosjekter ligger under én paraply:

**RAH AI Studios / RAH Platform**

Plattformen er fundamentet. Produkter som Raven Care, Raven Browser, RAH Gammon, Home Control og senere Raven OS er moduler, ikke uavhengige kaosprosjekter.

## Arbeidsregel: maks tre aktive spor

Det skal aldri være mer enn tre aktive spor samtidig:

### Spor A — Plattform og stabilitet
- Command Center
- Mission Control
- Project Brain
- Desktop Bridge
- Raven Vision
- tester, backup og énklikk-start

### Spor B — Ett hovedprodukt
Første hovedprodukt er **RAH Raven Care**.

### Spor C — Vedlikehold og dokumentasjon
- feilretting
- statusoppdatering
- versjonering
- brukerhåndbok
- arkivering av eldre versjoner

Alle andre ideer går til køen. Nye ideer kan registreres, men skal ikke starte automatisk.

## Hva «ferdig» betyr

Et prosjekt er ikke ferdig bare fordi en skjerm ser fin ut. En MVP er ferdig når:

- én kan starte den uten å lete etter riktig fil
- hovedfunksjonen faktisk virker
- data kan lagres og hentes igjen
- ingen kjente kritiske feil står åpne
- filene ligger i riktig GitHub-mappe
- programmet har versjonsnummer
- det finnes kort startveiledning
- det finnes demo eller skjermbilde
- tester eller manuell kontroll er gjennomført
- neste beslutning er skrevet: videreutvikle, pilotere, parkere eller avslutte

## Ansvarsdeling

### Raven/AI skal gjøre
- holde prosjektregister og rekkefølge
- bryte arbeid ned i små oppgaver
- skrive kode og spesifikasjoner
- kontrollere eksisterende filer før nye versjoner lages
- teste syntaks, koblinger og grunnfunksjoner
- skrive endringslogg og startveiledning
- avslutte hver arbeidsøkt med nøyaktig neste steg
- varsle når et nytt ønske kolliderer med aktiv prioritet
- foreslå sammenslåing i stedet for flere enkeltprogrammer

### Nils skal gjøre
- velge mellom tydelige alternativer når en beslutning faktisk trengs
- teste knapper, maskinvare og innlogging som AI ikke har fysisk tilgang til
- godkjenne sensitive handlinger, publisering, kostnader og deling
- gi korte feilbeskjeder eller skjermbilder når noe stopper

### Fagpersoner må godkjenne
- medisinske vurderinger
- juridiske konklusjoner
- helsedatabehandling og pilotoppsett
- sikkerhet før reelle pasientdata eller offentlige integrasjoner

## Fast daglig arbeidsflyt

1. Åpne RAH Start.
2. Raven viser bare én aktiv hovedoppgave.
3. Arbeid i en blokk på 25–90 minutter.
4. Test resultatet før ny funksjon startes.
5. Lagre og commit til GitHub.
6. Oppdater status: ferdig, blokkert eller neste.
7. Stopp på et punkt som er lett å fortsette fra.

En ny idé registreres i idéinnboksen med navn, mål og verdi. Den får ikke lov til å avbryte dagens oppgave med mindre den gjelder sikkerhet, helse eller en alvorlig feil.

## Prosjektstatuser

Alle prosjekter bruker samme statuser:

- **IDÉ** — bare registrert
- **AVKLARES** — mål og avhengigheter må bestemmes
- **KØ** — godkjent, men ikke aktiv
- **AKTIV** — ett av maks tre aktive spor
- **TESTING** — hovedbyggingen er stoppet mens funksjonen kontrolleres
- **MVP FERDIG** — brukbar førsteversjon
- **PILOT** — testes med faktiske brukere eller realistiske demodata
- **PARKERT** — bevisst utsatt
- **SLÅTT SAMMEN** — inngår i et annet produkt
- **AVSLUTTET** — ideen er dokumentert og ikke prioritert videre

## Fase 1 — Stabiliser fundamentet

Tidsrom: august 2026

### Leveranser

1. Én autoritativ RAH-startfil og én anbefalt launcher.
2. Command Center, Mission Control, Project Brain, Vision og Desktop Bridge åpnes fra samme sted.
3. System Health viser tydelig hva som kjører og hva som mangler.
4. Gamle dubletter flyttes til arkiv, ikke slettes uten kontroll.
5. Hvert aktivt prosjekt får én hovedmappe eller hovedfil.
6. Automatisk prosjektlogg i Raven Chronicle.
7. Alle aktive moduler får enkel test og kjent gjenopprettingspunkt.

### Ferdig når

- systemet starter med ett klikk
- aktivt prosjekt og neste steg gjenopprettes etter omstart
- GitHub er eneste kilde for gjeldende kode
- eldre varianter er tydelig merket som arkiv

## Fase 2 — Fullfør Raven Care MVP

Tidsrom: august–september 2026

### Byggerekkefølge

1. Slå Case Center og Fristvakt sammen i ett Raven Care-dashboard.
2. Legg til Health & Fatigue med manuell registrering.
3. Legg til CSV-import for blodsukker og andre målinger.
4. Lag Fastlegevisning for 7, 30 og 90 dager.
5. Lag utskriftsvennlig PDF-rapport med kilder.
6. Koble lokal dokumentuttrekking gjennom Desktop Bridge.
7. Koble LM Studio til kildebasert forklaring og oppsummering.
8. Bruk syntetiske eller avidentifiserte demodata.
9. Gjennomfør demo med fastlege og registrer konkrete tilbakemeldinger.
10. Oppdater UNN-pitchen etter testen.

### Raven Care MVP er ferdig når

- én startsiden åpner alle Care-modulene
- dokumenter, tidslinje, fatigue, blodsukker, søvn og frister kan registreres
- bruker kan lage et kort møteark
- fastlege kan få en to-minutters utskrift
- alle AI-påstander har kilde eller er merket som brukeropplysning/tolkning/uavklart
- ingen informasjon sendes automatisk

## Fase 3 — Gjør prosjektstyringen selvkjørende

Tidsrom: september–oktober 2026

### Leveranser

- ett prosjektregister for alle RAH-idéer
- automatisk registrering av nye ideer i kø
- WIP-grense på tre aktive spor
- daglig brief med én neste oppgave
- ukentlig rapport: bygget, blokkert, parkert og neste
- «Definition of Done»-sjekkliste i Mission Control
- automatisk changelog fra commits og fullførte missions
- Project DNA for hvert hovedprodukt

### Viktigste effekt

Raven skal fungere som et eksternt arbeidsminne og gjennomføringssystem. Det skal ikke kreve at brukeren husker hvor prosjektet stoppet eller hvilken versjon som var riktig.

## Fase 4 — Raven Browser

Tidsrom: oktober–november 2026

### Minimumsversjon

- faner
- bokmerker
- nedlastinger
- historikk
- gjenoppretting av økt
- prosjektarbeidsrom
- AI-sidepanel med lokal modell
- sikker kobling til Desktop Bridge
- ingen skjult skjermlesing eller kommandoer

Raven Browser skal bruke de samme Project Brain-, Chronicle- og Mission Control-systemene. Det skal ikke bli en ny separat plattform.

## Fase 5 — Første offentlige RAH-utgivelse

Tidsrom: november–desember 2026

### Leveranser

- ryddig nettside på rah-ai.com eller GitHub Pages
- kort presentasjon av RAH Platform og Raven Care
- nedlasting eller demo av godkjente offentlige moduler
- tydelig versjon, lisens, personvern og kontakt
- installer eller enkel lokal startpakke
- ingen sensitive data i offentlig repo eller demo

## Fase 6 — Neste produktkø

Etter at plattformen og Raven Care er stabile, tas prosjektene i denne rekkefølgen:

1. Light-gun arcade og kalibreringsverktøy
2. Raven Browser videreutvikling
3. RAH Gammon
4. RAH Home Control
5. RAH AI Photos / kreative verktøy
6. RAH Pay-konsept og medlemskap, først etter juridisk og betalingsmessig avklaring
7. utvalgte spill med størst demonstrasjonsverdi
8. Raven OS / BIOS / kernel som langsiktig forskningsprosjekt

Raven OS skal ikke være aktiv hovedbygging før de mindre modulene viser at arkitektur, oppdatering, sikkerhet og brukerbehov fungerer.

## Prosjektgrupper som skal slås sammen

### RAH Care-familien
Case Center, Fristvakt, Fatigue Detective, Fastlegevisning, Meeting Companion, Health Audit og Samspill blir moduler i Raven Care.

### RAH Platform-familien
Command Center, Mission Control, Project Brain, Chronicle, Insights, Daily Brief, Vision og Desktop Bridge blir én plattform.

### Raven Browser-familien
Browser, prosjektarbeidsrom, nedlastinger, bokmerker, sidepanel, link finder og webautomatisering samles.

### Gaming-familien
Light-gun, retro, PS6 Console, game builder og småspill samles som RAH Arcade/Labs. Bare ett spill bygges aktivt om gangen.

### OS-familien
BIOS, bootloader, network boot, kernel, grafikkdrivere og Raven OS samles som ett langsiktig forskningsspor.

## Regler mot versjonskaos

- samme prosjekt skal ikke få nye tilfeldige filnavn
- bruk semantiske versjoner: v0.1, v0.2, v1.0
- gjeldende versjon ligger i hovedmappen
- gamle versjoner flyttes til `/archive/<prosjekt>/<dato>`
- hver commit beskriver én forståelig endring
- ingen overskriving før gjeldende fil og SHA er kontrollert
- milepæler publiseres, ikke hver liten mellomversjon

## Regler mot idéavbrudd

Når en ny idé kommer midt i bygging:

1. Raven registrerer ideen på under to minutter.
2. Raven kobler den til riktig hovedprosjekt.
3. Raven vurderer om den er avhengighet, forbedring eller separat idé.
4. Ideen går i kø med foreslått fase.
5. Arbeidet går tilbake til aktiv oppgave.

Unntak: sikkerhetsfeil, tap av data, akutt helsebehov eller blokkering av hovedprosjektet.

## Prioritetsmodell

Hver idé vurderes fra 0–5 på:

- menneskelig nytte
- hvor mye den gjenbruker eksisterende plattform
- hvor nær den er fungerende
- risiko og kostnad
- om den blokkerer andre prosjekter

Høy nytte, mye gjenbruk og kort vei til MVP prioriteres. Høy risiko, store avhengigheter og lav gjenbruk parkeres.

## Realistisk mål

Det er ikke realistisk eller nyttig å gjøre 60–70 ideer til fullverdige kommersielle produkter på én gang. Det realistiske målet er:

- 1 stabil plattform
- 1 ferdig hovedprodukt
- 2–4 mindre ferdige demonstratorer
- resten ryddig dokumentert, slått sammen eller parkert

Da er ikke ideene mislykket. De er behandlet og plassert.

## Første aktive oppgaver

### Aktiv A — Plattform
Stabilisere énklikk-start, statuskontroll, prosjektgjenoppretting og arkivstruktur.

### Aktiv B — Raven Care
Integrere Fristvakt og bygge Health & Fatigue + Fastlegevisning.

### Aktiv C — Prosjektkontroll
Koble masterplanen til Mission Control, Chronicle og Daily Brief.

Ingen andre produkter går til AKTIV før ett av disse tre sporene går til MVP FERDIG eller PARKERT med begrunnelse.

## Begrensning som må være tydelig

AI kan planlegge, kode, teste filer, dokumentere og fortsette fra GitHub når samtalen er aktiv. AI kan ikke fysisk arbeide videre på datamaskinen etter at samtalen er avsluttet uten en avtalt automatisering eller en aktiv koblet arbeidsflyt. Derfor skal hvert stoppunkt lagres slik at neste samtale kan fortsette direkte uten ny forklaring.

## Fast arbeidsavtale

**Én plattform. Maks tre aktive spor. Ett ferdig resultat før neste store start. Alle ideer blir registrert. Ingen idé får lov til å stjele fokus uten en dokumentert grunn.**
