# RAH GOLD GUI R1 — Raven Flash R1.5, visuell kandidat

**Status: kandidat. Ikke installert, ikke promotert og ikke fysisk verifisert.**

Dette er en faktisk, offline HTML-erstatning for Håkøya-siden i RAH OS / Raven Flash R1.5. R1.5-oppstart, Openbox, statusrapport, nettverksverktøy og brukerprofil er bevart. Endringen er isolert til de to GUI-filene `hakoya.html` og `start.html` på en ny GitHub-gren, med draft PR mot R1.5-kandidatgrenen. **Ingen ferdig ISO eller bootloader er skrevet.**

## Start på Windows (kun forhåndsvisning)

Dobbeltklikk `START-HER.cmd` i utpakket mappe. Programmet åpner `candidate-files/hakoya.html` i standard nettleser. Kommandovinduet viser instruksjonene og venter på tastetrykk. Dette er kun HTML-test; Linux-lenker som `file:///opt/raven-flash/start.html` vil ikke fungere på Windows. Det trengs ingen Python, npm, drivere, Ventoy eller Lovable.

## Hva er med?

- RAH Gold/Obsidian grensesnitt med egyptisk øye, pyramider, geometrisk rutenett og tilpasset mobil/stor skjerm.
- Matematiske formler: gylne snitt φ, Pytagoras, pyramidevolum og Fibonacci.
- Interaktiv pyramidekalkulator: `h=(b/2)*tan(α)`, `V=b²*h/3`. Vinkelen α er pyramidens skråflate mot grunnplanet gjennom midtpunktet av en side.
- Lokal Raven Launcher, lokal statusrapport, nettverksinformasjon og idéblokk med samme localStorage-nøkkel som R1.5.
- Eksporter idéblokk til .txt før en live-økt avsluttes.
- Ingen eksterne script, skriftfiler, CDN-er eller nettforespørsler ved oppstart av GUI.

## Sikkerhetsgrense

- Ikke kjør installasjon, ISO-skriving, Ventoy-kopiering eller diskendring.
- Ikke endre Windows, EFI, BCD, RAH GOLD, eksisterende Rainmeter eller oppstartskonfigurasjon.
- Backout: behold den opprinnelige R1.5-grenen urørt; forkast bare den separate Gold GUI-grenen eller reverser de to HTML-endringene før ny ISO eventuelt bygges.
- Visuell godkjenning på 1440p, 4K/Sony 65", USB/Ventoy-boot, VirtualBox og fysisk RAH OS/OMEN/HOVED-PC krever egne bevis. HTML-test er ikke OS-bootbevis.

## Bevis / akseptanse

Se `reports/REPORT.json` og `reports/REPORT.html` for lokale testresultater. Skjermbildene er fra Chromium-test, ikke fra ekte RAH OS-boot. Det kreves separat manuell akseptanse før eventuell promoterering.

GitHub repo: https://github.com/NilsRa73/rah-platform
Eksisterende R1.5 PR: https://github.com/NilsRa73/rah-platform/pull/482