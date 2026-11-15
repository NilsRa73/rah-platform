# Raven Flash: trippelboot og kort vei til nettleser

31. oktober 2026. Dette er en konkret gjennomfoeringsplan, ikke en installert
oppstartsmeny. Faktiske EFI-partisjoner, firmwaremodus og de to andre OS-ene er
ikke kartlagt fra denne sesjonen. Ingen disknummer eller EFI-GUID gjettes.

Maal: en meny for Windows / RAH OS / Raven Flash, med kort automatisk valg,
og en lokal nettleserside som er brukbar foer nettet er klart.

## Rekkefolge

1. Kjor `windows/START-HER.cmd` paa riktig PC. Det samler bare eksisterende BCD,
   firmwareoppfoeringer, disk-/volumlister og Windows-status i en lokal rapport.
   Rapporten kan inneholde utilgjengelige seksjoner; disse er ikke godkjente tester.
2. Identifiser eksisterende Windows-loader, RAH OS-medium og en godkjent
   Raven Flash-ISO. Kontroller SHA-256 og UEFI kontra legacy BIOS.
3. Bruk en separat USB eller SSD til en foerste menytest. For UEFI er rEFInd
   en kandidat med eksplisitte, validerte loaderoppfoeringer. En ISO-fil er ikke
   i seg selv en EFI-loader; den maa ha en kompatibel oppstartskjede eller et
   klargjort live-medium. Ventoy er et alternativ for ISO-medier, men kan gi
   ekstra menytrinn og maa testes med de konkrete ISO-ene.
4. Sett kort tidsavbrudd (maal 2 sekunder) foerst naar alle tre valg fungerer.
   Behold en tilgjengelig meny og et dokumentert Windows-valg.
5. Konfigurer firmware til aa starte menyverten automatisk, en gang. Dette er
   den delen som fjerner behovet for F12 hver gang. Test Windows med USB fjernet.
   Intern EFI og Secure Boot endres ikke automatisk fra startpakken.

En meny kan ikke fjerne hovedkortets POST, initialisering av skjermer eller
USB-kontrollere. Mye tilkoblet skjermutstyr kan paavirke total kaldstart.
To etterfoelgende menyer skal unngaas eller maales med i sluttiden.

## R1.3 sitt innhold

Kritisk sti: firmware -> loader -> Linux -> grafisk oekt -> Chromium -> lokal side.
NetworkManager kobler opp i parallell; wait-online er maskert kun i denne lokale
live-kandidaten. Det er ikke en netboot-/NFS-root-oppskrift.

Startbildet inneholder egen CSS og JavaScript, systemfonter og ingen eksterne
ressurser. Lokale/serverbaserte/nettbaserte nettapper aapnes i nye faner etter
brukerens valg. Det lastes eller kjoeres ingen native programmer automatisk.
Klienter kan senere bruke en autentisert nettjeneste eller fjernskrivebord.

SquashFS bygges med zstd nivaa 3 som en kandidat for rask dekomprimering.
Storre ISO kan gi mer USB-lesing; fysisk A/B-test maa avgjoere om dette er bedre.
`toram` er ikke standard: kopiering av hele systemet maa ikke skjules i boottiden.
Lokal NVMe er en senere test, ikke dokumentert raskere paa brukerens maskin.

## Maaling

Fem like kalde starter. Rapporter median, beste og alle maaltider:
- av/paa -> lokal side synlig OG klikkbar (video);
- av/paa -> faktisk nettjeneste tilgjengelig;
- kernel/userspace/critical-chain fra oppstartsrapport som delmaal;
- ISO-hash, maskin, firmwareinnstillinger og lagringsmedium.

Nettlesersiden viser sin egen lastetid, aldri en paastatt OS-boottid.
Det finnes ingen bekreftet verdensrekord i denne leveransen.

## Kilder kontrollert 31.10.2026

- https://www.rodsbooks.com/refind/configfile.html
- https://www.ventoy.net/en/plugin_control.html
- https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/bcdedit--enum
- https://networkmanager.pages.freedesktop.org/NetworkManager/NetworkManager/NetworkManager-wait-online.service.html
- https://manpages.debian.org/trixie/live-build/lb_config.1.en.html
