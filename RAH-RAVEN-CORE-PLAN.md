# RAH Raven Core — fullfør før Lovable

Dato: 6. august 2026

## Beslutning

Før nye produktbygg i Lovable skal RAH-plattformens lokale AI-kjerne gjøres ferdig nok til å koordinere, huske, kontrollere og fortsette arbeid.

Riktig rekkefølge:

1. Raven Vision
2. Lokal AI via LM Studio
3. Raven Council
4. Agent Runner / Mission Control
5. Project Brain + Chronicle
6. Deretter Lovable og produktmoduler

## 1. Raven Vision — øyne

Eksisterende grunnlag:
- nettleserfangst
- aktivt vindu via Desktop Bridge
- felles skjermbildestatus
- lokal vision-analyse via LM Studio
- diagnostikk, historikk og eksport

Må ferdigstilles med:
- én tydelig startknapp
- stabil status for Bridge og modell
- valg mellom skjerm, vindu og opplastet bilde
- markering av hva som faktisk ble analysert
- klikkveiledning med bekreftelse
- ingen skjult skjermfangst
- test på hoved-PC og laptop

Ferdig når Raven kan se valgt skjerm/vindu, forklare innholdet, foreslå neste klikk og lagre resultatet i aktiv mission.

## 2. Lokal AI — hjerne

LM Studio skal være standard lokal leverandør.

Må ha:
- automatisk modelloppdagelse
- valg av tekstmodell og vision-modell
- enkel helsesjekk
- tidsavbrudd og avbryt
- logg over forespørsler uten å lagre sensitive bilder unødvendig
- provider-abstraksjon slik at annen lokal eller skybasert modell kan legges til senere
- tydelig offline/online-status

Ferdig når Raven kan bruke lokal tekst- og bildemodell fra samme kontrollpanel, med feilmeldinger som en vanlig bruker forstår.

## 3. Raven Council — flere fagroller

Council finnes ikke som ferdig modul i repoet ennå.

Første versjon skal bruke samme lokale modell med ulike roller:

- **Planner** — bryter målet ned i rekkefølge og avhengigheter
- **Builder** — foreslår eller skriver implementasjon
- **Reviewer** — finner feil, mangler og duplikater
- **Safety** — kontrollerer personvern, risiko og handlingstillatelser
- **Archivist** — finner eksisterende filer, versjoner og tidligere beslutninger
- **Chair/Raven** — samler rådene og lager ett anbefalt neste steg

Council skal ikke late som rollene er uavhengige eksperter. I første versjon er de ulike strukturerte gjennomganger fra samme modell.

Ferdig når én mission kan sendes til Council, alle roller leverer korte svar, uenighet vises, og Chair lager én beslutning med begrunnelse og kilde til prosjektdata.

## 4. Agent Runner — hender

Agentene skal ikke få fri, skjult tilgang til PC-en. De skal jobbe gjennom en kø med tillatte verktøy og godkjenninger.

Agent Runner må ha:
- oppgavekø
- statusene PENDING, RUNNING, WAITING, COMPLETED og FAILED
- eksplisitt verktøyliste per agent
- tillatte lokale handlinger gjennom Desktop Bridge
- godkjenning før sletting, publisering, installasjon, betaling eller sending
- forsøksteller, tidsstempel og feillogg
- pause, stopp, prøv igjen og gjenoppta
- automatisk lagring av resultat og neste steg

Trygge tidlige handlinger:
- lese Git-status
- åpne prosjektmappe
- åpne fil i VS Code
- kjøre godkjente tester
- starte godkjent lokal utviklingsserver
- lage rapport og forslag til commit

Ferdig når en mission kan gjennomføres fra plan til test og rapport, mens risikable steg stopper for menneskelig godkjenning.

## 5. Project Brain og Chronicle — hukommelse

Alle agentsvar skal knyttes til:
- aktivt prosjekt
- mission
- filer og versjoner
- beslutninger
- blokkeringer
- testresultater
- nøyaktig neste steg

Project Brain lagrer gjeldende tilstand. Chronicle lagrer historikken. GitHub er kilden for kode.

Ferdig når en ny samtale eller omstart kan gjenoppta arbeidet uten at Nils må forklare alt på nytt.

## 6. Lovable etter Raven Core

Når kjernen virker, brukes Lovable som en rask produktbygger, ikke som prosjektets hukommelse eller overordnede leder.

Raven Council skal da kunne:
- lese produktkrav
- lage én låst MVP-spesifikasjon
- generere Lovable-prompt
- kontrollere Lovable-resultatet
- finne mangler og sikkerhetsproblemer
- oppdatere GitHub og prosjektstatus
- lage neste forbedringsoppgave

Første produkt etter kjernen er Raven Care.

## Minimumsversjon som må være ferdig før vi går videre

- Vision ser valgt skjerm eller vindu stabilt
- lokal tekst- og vision-modell svarer
- Council med minst Planner, Builder, Reviewer, Safety og Chair
- Mission Control kan kjøre og gjenoppta en agentoppgave
- Desktop Bridge har allowlist og godkjenningsport
- Project Brain og Chronicle lagrer resultatet
- én komplett demo-mission er testet

## Første komplette demo-mission

Mål: «Forbedre Raven Care-dashboardet.»

1. Archivist finner gjeldende Care-filer.
2. Vision analyserer skjermbildet av dagens app.
3. Planner lager maksimalt fem trinn.
4. Builder lager kodeforslag.
5. Reviewer kontrollerer feil og duplikater.
6. Safety kontrollerer helsedata og automatisk deling.
7. Agent Runner kjører godkjent test.
8. Chair lager resultat, endringslogg og neste steg.
9. Mennesket godkjenner eventuell commit eller publisering.

## Realistisk autonomi

Etter dette kan agentene utføre mye mer av forarbeidet og enkelte trygge lokale oppgaver. De kan ikke garantere at alle prosjekter blir ferdige uten tilsyn, og de skal ikke få ubegrenset tilgang til maskinen. Målet er kontrollert autonomi: mest mulig arbeid automatisk, minst mulig risiko, og tydelige stopp når menneskelig beslutning trengs.

## Aktiv prioritet

### Prioritet 1
Stabilisere Vision + Desktop Bridge + LM Studio.

### Prioritet 2
Bygge Raven Council v0.1.

### Prioritet 3
Koble Council til Mission Control, Project Brain og Chronicle.

### Prioritet 4
Kjøre én komplett demo-mission.

### Prioritet 5
Bruke Council til å bygge Raven Care i Lovable.

## Arbeidsregel

**Raven skal først få øyne, hjerne, råd, hender og hukommelse. Deretter får agentene bygge produktene.**
