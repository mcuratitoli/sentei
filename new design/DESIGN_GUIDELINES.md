# Sentèi — Linee guida grafiche

Riferimento di design per l'app Flutter "Sentèi" (escursionismo). Nasce dalla revisione grafica del prototipo `Sentei Redesign.dc.html` (HTML, solo riferimento visivo — non va copiato come codice, va **ricreato in Flutter** con i widget e i pattern già presenti nel progetto).

Obiettivo della revisione: coerenza tra icone, bottoni, badge e pannelli modali, oggi disomogenei nell'app esistente. Queste regole valgono sia per sistemare le schermate già costruite sia per ogni nuova schermata futura.

## 1. Principi

- **Un solo stile di bottone, ovunque.** Niente varianti ad-hoc per singola schermata.
- **Ogni pannello modale è una bottom sheet**, con la stessa struttura (handle → titolo + chiusura × → contenuto). Niente dialog centrati, niente popover.
- **Le icone sono tutte lineari** (stroke, non filled), stesso spessore, stesso set di stati.
- **I badge di difficoltà mantengono la distinzione di significato ma condividono la stessa forma.**
- Ispirazione funzionale: Gaia GPS. Ispirazione grafica: Apple Maps (pulizia, poco testo, gerarchia chiara).

## 2. Colori

| Token | oklch | Hex | Uso |
|---|---|---|---|
| `bg.app` | oklch(96.5% 0.006 95) | `#F5F3EF` | sfondo schermate (liste, impostazioni) |
| `bg.surface` | — | `#FFFFFF` | card, bottom sheet, list container |
| `border.divider` | oklch(91% 0.006 95) | `#E2E1DD` | separatori, contorni pill sentiero |
| `text.primary` | oklch(20% 0.02 260) | `#11161F` | titoli, testo principale |
| `text.secondary` | oklch(50% 0.015 260) | `#5E646C` | sottotitoli, metadati |
| `text.tertiary` | oklch(68% 0.011 260) | `#94999F` | chevron, icone disabilitate |
| `accent.blue` (primario) | oklch(56% 0.19 255) | `#0071E0` | bottone primario, link, stato attivo, FAB |
| `accent.blue.pressed` | oklch(48% 0.19 255) | `#0058C4` | stato pressed del primario |
| `accent.blue.tint` | oklch(94% 0.035 255) | `#DCEDFF` | sfondo icona attiva/selezionata |
| `difficulty.T` (verde) | oklch(58% 0.13 150) | `#348F4F` | badge/dislivello positivo |
| `difficulty.E` (teal) | oklch(58% 0.13 195) | `#009192` | badge |
| `difficulty.EE` (arancio) | oklch(68% 0.15 55) | `#DD7B2B` | badge |
| `difficulty.EEA` (rosso) | oklch(56% 0.19 25) | `#CC3336` | badge, dislivello negativo, distruttivo |
| `track.purple` (extra) | oklch(58% 0.14 315) | `#995EB3` | colore tracciato aggiuntivo |
| `icon.bg.neutral` | oklch(95.5% 0.005 95) | `#F1F0EC` | sfondo icon-button di default |

Massimo due colori neutri di sfondo nell'intera app (`bg.app` e bianco). Il blu è l'unico colore "di brand/azione"; gli altri quattro colori (verde/teal/arancio/rosso) sono riservati **esclusivamente** alla scala difficoltà e ai relativi dati (dislivello +/-). Non introdurre nuovi colori senza necessità — se serve un'altra tinta per un tracciato, restare nella stessa famiglia (chroma ~0.13–0.15, lightness ~56–58%, variare solo la hue).

## 3. Tipografia

Font di sistema: `-apple-system / San Francisco` su iOS, `Roboto`/font di sistema su Android (nessun font custom).

| Ruolo | Peso | Size | Note |
|---|---|---|---|
| Titolo schermata | 700 | 20px | header di Tracciati, Impostazioni, bottom sheet |
| Titolo grande (opzionale) | 700 | 28–34px | non usato nelle schermate attuali, riservato a eventuali landing/onboarding |
| Corpo / nome elemento lista | 600 | 16–17px | nome tracciato, riga impostazioni |
| Corpo secondario | 400–500 | 14–15px | metadati (km, D+, email, sottotitoli) |
| Caption/etichetta sezione | 600 | 13px, uppercase, letter-spacing 0.03em | intestazioni "Mappa", "Aspetto", "Informazioni" |
| Badge/tag | 600–700 | 13px | badge difficoltà, tag numero sentiero |

## 4. Bottoni — sistema unico

Quattro varianti, stessa altezza (48–50px) e stesso raggio (pill, radius = altezza/2):

1. **Primario** — sfondo `accent.blue`, testo bianco 700. Azione principale della schermata (Salva).
2. **Secondario** — sfondo trasparente/bianco, bordo 1.5px `accent.blue`, testo `accent.blue` 600. Azione alternativa positiva (Modifica titolo).
3. **Testo (terziario)** — nessuno sfondo/bordo, testo `text.secondary` 600. Azione a bassa enfasi (Annulla).
4. **Distruttivo** — bordo 1.5px `difficulty.EEA` (rosso), testo rosso 600. Cancellazioni/scollegamenti (Scollega).

Nessun'altra combinazione (niente bottoni pieni rossi/verdi, niente bordi grigi neutri). Icona opzionale a sinistra del testo, stesso colore del testo.

## 5. Icone

- Stile **outline**, `stroke-width` 1.8–2px, `stroke-linecap`/`linejoin: round`. Mai filled, tranne il pallino di stato (dot colore tracciato) e piccoli glifi pieni <8px.
- Target di tocco minimo **44×44px**, anche quando il glifo visivo è più piccolo (18–22px).
- **Icon-button di default**: cerchio, sfondo `icon.bg.neutral`, icona `text.secondary`/`text.primary`.
- **Icon-button attivo/selezionato**: sfondo `accent.blue.tint`, icona `accent.blue`.
- Nessuna icona filled mescolata a icone outline nella stessa riga di azioni (era il problema principale nell'app attuale: waveform/foto/matita/download con stili diversi).
- Le voci di "Impostazioni" hanno tutte un contenitore icona uniforme: quadrato arrotondato 30×30px, radius 8px, sfondo tinta (`accent.blue.tint` di default, tinta rossa solo per l'icona di "Disconnetti").

## 6. Badge & tag

- **Badge difficoltà** (T/E/EE/EEA): stessa forma per tutti — rettangolo arrotondato (radius 9px, non pill), padding 6×14px, font 700 13px. Colore di sfondo pieno = colore del livello, testo bianco. *(Variante alternativa "contorno": sfondo bianco, bordo e testo colorati — usata se si preferisce meno peso visivo; scegliere una sola variante per tutta l'app, non mischiarle.)*
- **Tag numero sentiero** (203, GTA, U09…): pill completamente arrotondata (radius 999px), sfondo bianco, bordo 1px `border.divider`, testo `text.primary` 600 13px. Sempre distinti dai badge difficoltà per forma (pill vs rettangolo arrotondato), mai per colore casuale.
- **Pallino colore tracciato**: cerchio pieno 12–13px, colore = colore assegnato al tracciato (palette di 6: blu, verde, rosso, arancio, viola, teal — stessa chroma/lightness, hue diversa).

## 7. Bottom sheet — struttura obbligatoria

Ogni pannello modale (dettaglio tracciato, foto, modifica titolo, modifica tracciato, impostazioni avanzate, selezione tema) usa **la stessa struttura**:

1. Handle: barra 36×5px, grigio chiaro (`#E2E1DD`), centrata, margine inferiore 14–16px.
2. Header: titolo a sinistra (700, 18–20px) + pulsante chiusura × a destra (cerchio 32–36px, sfondo `icon.bg.neutral`). Il pannello "dettaglio tracciato" ha anche un chevron per espandere/collassare, prima della ×.
3. Contenuto specifico della sheet.
4. Padding interno: 20px laterale, ~34px inferiore (safe area).
5. Angoli superiori arrotondati (radius 20–24px), ombra verso l'alto.
6. Sfondo di backdrop semi-trasparente nero (~45% opacità) quando la sheet è sovrapposta alla mappa/altra sheet sottostante.

Non usare mai un `AlertDialog`/dialog centrato per queste azioni (es. "Modifica titolo" oggi è un dialog centrato: va convertito in bottom sheet).

## 8. Toggle/switch

Switch iOS-style, larghezza 50px, altezza 30px, thumb bianco 24px. **Stato ON = blu (`accent.blue`)**, non verde: mantenere coerenza con l'unico colore di brand/azione (oggi "Segui i sentieri" usa il verde di sistema, va allineato al blu).

## 9. Schermate coperte da questa revisione

Mappa · Elenco tracciati · Dettaglio tracciato (collassato ed esteso con altimetria) · Modifica tracciato · Foto (dettaglio) · Modifica titolo foto · Impostazioni avanzate (colore tracciato + "segui sentieri") · Impostazioni · Selezione tema.

Riferimento visivo interattivo: `Sentei Redesign.dc.html` (apri nel browser, i chip in alto saltano a ognuna delle 10 schermate).

## 10. Cosa NON fare

- Non mescolare stili di bottone diversi nella stessa schermata.
- Non usare dialog centrati per conferme: sempre bottom sheet.
- Non introdurre nuove tinte fuori dalla palette sopra.
- Non usare icone filled insieme a icone outline nella stessa riga/gruppo.
- Non applicare un colore diverso dal blu a uno stato "attivo/selezionato".
