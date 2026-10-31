# Raven Flash R1.4 — liten klient, nettbaserte verktøy

31. oktober 2026. Ny kildekandidat basert på R1.3. Faktisk ISO-størrelse,
firmwaretester og brukerøkt testes av egen CI. Fysisk oppstartstid er ikke målt.

## Menyen på det nye mediet

- **Raven Flash – nettleser:** standardvalg, to sekunders menyfrist. Lokal
  startside først; nettverk kobles opp parallelt. Nettverktøy åpnes ved behov.
- **Installerte OS (UEFI):** søk etter eksisterende Windows EFI-loader.
  RAH OS og andre installerte systemer får egne, kontrollerte loaderoppføringer
  i `/boot/raven/installed.cfg`. De faktiske EFI-stiene må kartlegges først.
- **ISO-bibliotek (UEFI):** `/ISO/raven-flash.iso` og `/ISO/rah-os.iso` på et
  tilgjengelig filsystem. ISO-en må inneholde kompatibel `boot/grub/loopback.cfg`.
  Filnavnet alene beviser ikke kompatibilitet. Andre oppskrifter legges i
  `/boot/raven/iso-extra.cfg`. Bredt ISO-utvalg: bruk separat Ventoy-medium.
- **Nettverksoppstart:** lokal nettleserstart, iPXE, og kort forklaring.
- **Feilsøking:** lokal start med `nomodeset` for grafikkproblemer.

Legacy BIOS har direkte Raven-start og en ekte iPXE-undermeny. Biblioteket for
andre BIOS-ISO-er og installerte OS krever Ventoy eller separate oppskrifter;
BIOS-menyen peker ikke blindt på en disk eller oppstartssektor.

Ingen automatisk installasjon til intern disk, ingen BCD-/EFI-endringer og ingen
endring av firmware-rekkefølge. Først testes menyen fra separat USB/SSD.
Å velge en eksisterende loader starter det systemet på vanlig måte.
Ved flere Windows-installasjoner finner søket den første matchen; bruk eksplisitt
filssystem-UUID etter inventarrapport for å velge en bestemt installasjon.

## Hva blir mindre?

Minbase i stedet for full standardbase, ingen APT-indekser på live-mediet,
utvalgte Xorg-komponenter fremfor hele Xorg-samlingen, og fjerning av lokal
manual-/dokumentasjonstekst. Opphavsrettstekster beholdes. Chromium, sandkasse,
sertifikater, Wi-Fi-fastvare, kernelmoduler, norsk tastatur, Openbox og nettpanel
beholdes. NVIDIA/Intel/AMD på de fysiske PC-ene trenger fortsatt grafikkakseptanse.

`package-sizes.tsv` viser installerte pakker. `image-metrics.json` viser faktiske
ISO-bytes og SHA-256. CI sammenligner med den bestemte R1.3-ISO-en fra kjøring
41172609767 når den er tilgjengelig og kontrollsummen stemmer. Hvis den har utløpt,
vises bare ny størrelse. Ingen antatt besparelse presenteres som målt.

Zstd nivå 3 beholdes. Minste nedlasting og raskest oppstart kan kreve forskjellige
komprimeringsvalg. En senere XZ/Zstd A/B-test må måle både lesing og utpakking.
Det kopieres ikke automatisk et helt lokalt ISO til RAM ved normal oppstart.

## PXE / iPXE: konkret første oppsett

Egen netboot-pakke fra samme bygg inneholder `vmlinuz`, `initrd.img`,
`filesystem.squashfs`, `menu.ipxe`, iPXE for BIOS/UEFI og `SHA256SUMS`.
Den starter ingen server og endrer ikke ruter eller DHCP automatisk.

1. Kontroller SHA-256 og legg filene på en betrodd lokal HTTP-server, for eksempel
   `http://192.168.1.20/rah/`. Dette er en eksempeladresse, ikke brukerens adresse.
2. Første test bruker kablet Ethernet. Start iPXE fra undermenyen. Trykk Ctrl+B,
   kjør `dhcp`, og deretter `chain http://SERVER-IP/rah/menu.ipxe` med faktisk IP.
3. Velg Raven Flash. iPXE henter kernel/initrd; live-boot henter SquashFS til RAM.
   Denne hentingens tid skal regnes med. Debian sin dokumenterte `fetch=`-rute
   krever her HTTP med IPv4-adresse, ikke DNS-navn/HTTPS. Bruk eget betrodd LAN
   for denne kandidaten. HTTPS hos iPXE alene sikrer ikke etterfølgende root-henting.
4. Andre systemer kan få hver sin `os/custom.ipxe` med OS-spesifikk oppskrift.
   Windows PE bruker eksempelvis wimboot og en WIM-fil. Det er ikke vanlig
   Windows-skrivebord eller universell ISO-boot.
5. Automatisk PXE uten USB krever DHCP/TFTP/UEFI HTTP Boot som passer ruteren og
   firmware. Unngå å starte en ekstra konkurrerende DHCP-server på hjemmenettet.

4 GiB RAM brukes i CI-fetch-testen. Praktisk minnebehov avhenger av SquashFS-
størrelse og nettleserlast; 8 GiB er et fornuftig første fysisk testoppsett.
PXE-firmware, iPXE-nettdrivere, fysisk Wi-Fi og Secure Boot er egne akseptansepunkter.
Usignert iPXE/egendefinert ISO kan bli avvist når Secure Boot håndheves.

## Direkte til internett og hva som er et OS

Bootmenyen er en loader, ikke en full nettleser. For en moderne nettleser trengs
kjerne, minne-/prosesshåndtering, grafikk/input, filsystem, nettverk og TLS.
Raven Flash leverer denne lokale grunnmuren og nettleseren; andre verktøy kan
være nettapper eller kjøre på HOVED-PC, OMEN eller server. Det er fortsatt et
Linux-basert operativsystem selv med få lokale programmer. En helt egen kjerne
er ikke nødvendig for denne OS-betegnelsen. Ingen Guinness-godkjenning følger av det.

Lavest forventet venting: lite lokalt system på raskt medium, lokal startside,
nett i parallell. PXE er et alternativ for sentral drift, ikke dokumentert raskere.

## Måling og rekordambisjon

Film fem kalde starter fra av/på til siden både er synlig og reagerer på klikk.
Mål nettjeneste tilgjengelig separat. Oppgi alle tider, median, beste, maskin,
firmware, tilkoblet utstyr, medium, ISO-hash og menyfrist. Varmstart, suspend og
kernelmålinger rapporteres separat. CI-tid i QEMU er ingen fysisk boottid.

«Utviklet på Håkøya ved Tromsø» kan dokumenteres som opphav. «Verdens nordligste
nedlastbare OS» og «verdens raskeste» er ikke verifisert. Guinness krever en
målbar, repeterbar, standardiserbar og etterprøvbar kategori; få kategorien og
reglene avklart før et formelt rekordforsøk.

## Kilder kontrollert 31.10.2026

- https://ipxe.org/cmd/chain
- https://ipxe.org/wimboot
- https://ipxe.org/crypto
- https://manpages.debian.org/trixie/live-boot-doc/live-boot.7.en.html
- https://www.gnu.org/software/grub/manual/grub/grub.html
- https://www.ventoy.net/en/doc_memdisk.html
- https://www.guinnessworldrecords.com/records/what-makes-a-guinness-world-records-record-title/index
