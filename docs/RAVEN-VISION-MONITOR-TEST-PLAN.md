# Raven Vision — monitorvalg testplan

Mål: verifisere at Raven Vision kan fange Monitor 1, Monitor 2, aktivt vindu og et eksplisitt område uten vanlig screenshot-copy/paste.

## Forutsetninger

- Start canonical Raven Desktop Bridge / Raven Vision EXE.
- Åpne `http://127.0.0.1:18765/vision/ui`.
- LM Studio er valgfritt for ren fangst; kreves bare for `Fang + analyser`.

## 1. Monitoroppdagelse

1. Trykk `Test Bridge + LM Studio`.
2. Bekreft at Monitorstatus viser alle tilkoblede skjermer med oppløsning og posisjon.
3. Bekreft at Kilde-menyen inneholder `Monitor 1`, `Monitor 2` når to skjermer finnes, pluss `Aktivt vindu` og `Område`.

PASS: riktig antall skjermer og riktige dimensjoner vises.

## 2. Monitor 1

1. Legg et tydelig testvindu kun på Monitor 1.
2. Velg `Monitor 1` og trykk `Bare fang`.
3. Kontroller forhåndsvisningen.
4. Gjenta med `Alt+Shift+1`.

PASS: begge metodene fanger Monitor 1 og ikke Monitor 2.

## 3. Monitor 2

1. Legg et annet tydelig testvindu kun på Monitor 2.
2. Velg `Monitor 2` og trykk `Bare fang`.
3. Gjenta med `Alt+Shift+2`.

PASS: begge metodene fanger Monitor 2 og ikke Monitor 1.

## 4. Aktivt vindu

1. Velg `Aktivt vindu`.
2. Trykk `Bare fang`; bytt til ønsket vindu innen tre sekunder.
3. Gjenta med `Alt+Shift+A`.

PASS: Raven fanger det aktive vinduet etter byttetiden. Watch bruker gjeldende aktive vindu uten tre sekunders forsinkelse.

## 5. Område

1. Velg `Område`.
2. Fyll inn X, Y, bredde og høyde. Start gjerne med koordinatene til Monitor 1 som vises i Monitorstatus.
3. Reduser bredde/høyde slik at området dekker en tydelig del av skjermen.
4. Trykk `Bare fang`.
5. Gjenta med `Alt+Shift+O`.

PASS: bare det valgte rektangelet vises. Negative X/Y skal fungere når en skjerm ligger til venstre/over primærskjermen.

## 6. Avvis ugyldig område

1. Sett bredde eller høyde til `1`.
2. Prøv fangst.
3. Sett deretter et område som går utenfor hele virtuelle skrivebordet.

PASS: Raven avviser begge med en tydelig feil og tar ikke et tilfeldig skjermbilde.

## 7. Watch

For hver av `Monitor 1`, `Monitor 2` og `Område`:

1. Velg kilden.
2. Trykk `Start Watch 10s`.
3. Endre innholdet på den valgte skjermen/området.
4. Kontroller at forhåndsvisning/analyse oppdateres omtrent hvert tiende sekund.
5. Trykk `Stopp Watch`.

PASS: Watch følger valgt kilde og stopper når brukeren ber om det.

## 8. Lokal sikkerhetsgrense

Kjør eksisterende Raven Bridge security-test.

PASS: `/capture/monitor`, `/capture/area`, `/capture/active-window` og øvrige beskyttede endepunkter er utilgjengelige for fremmede browser-origins, mens lokal Vision fortsatt fungerer.

## Godkjenningskrav

Funksjonen er klar for daglig bruk når punkt 1–8 passerer på HOVED-PC og den faktiske Windows-EXE-en består GitHub Actions build/self-test.
