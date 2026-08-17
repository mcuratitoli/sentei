# Checklist di rilascio — Sentèi

> Da eseguire ad ogni **bump di versione in `pubspec.yaml`** (nuova build distribuita ai
> tester), **prima di chiudere la sessione di lavoro**. Copre solo l'allineamento della
> documentazione — per il processo di upload/distribuzione vero e proprio vedi
> `testflight-amici.md` (iOS) e la sezione Android in `docs/`.

## 1. File utente (visibili anche in-app)

- [ ] **`CHANGELOG.md`** — nuova voce in cima, con build/data e novità in linguaggio
  semplice (non un log tecnico).
- [ ] **`lib/ui/release_notes.dart` (`kReleaseNotes`)** — allineato alla voce appena
  aggiunta a `CHANGELOG.md` (stesso contenuto, in forma sintetica per la card "Novità"
  in-app). Vedi `CLAUDE.md` §9.
- [ ] **`kUpcomingHighlights`** (stesso file) — coerente con la sezione P1 di
  `docs/ROADMAP.md` **dopo** averla aggiornata (punto 3 sotto).

## 2. File interni (roadmap e changelog tecnico)

- [ ] **`docs/CHANGELOG-DEV.md`** — nuova voce con dettagli tecnici, causa radice dei bug
  risolti, file coinvolti.
- [ ] **`docs/ROADMAP.md`**:
  - [ ] header `Aggiornato: … · Stato: beta` **`1.0.0+N`** aggiornato a build e data
    correnti (non basta cambiare la data lasciando il numero di build vecchio).
  - [ ] ogni punto risolto in questa build **spuntato `[x]`** con riferimento alla voce di
    `CHANGELOG-DEV.md`, oppure rimosso se il documento lo prevede (il completato vive nel
    changelog tecnico, la roadmap resta "solo punti aperti").
  - [ ] nessun punto ancora `[ ]` che in realtà risulta **già fatto** secondo
    `CHANGELOG.md`/`CHANGELOG-DEV.md` — incrociare prima di spuntare, non fidarsi solo
    dello stato precedente della roadmap.

## 3. File pubblici di stato

- [ ] **`README.md`** — riga "Stato attuale" (data + build) aggiornata.

## 4. Verifica di coerenza finale

- [ ] `grep -rn "1\.0\.0+<build precedente>"` su tutto il repo, **esclusi**
  `CHANGELOG.md`/`docs/CHANGELOG-DEV.md` (sono cronologia, restano invariati): nessun
  riferimento alla build vecchia deve restare in un file "di stato attuale" (`README.md`,
  header di `docs/ROADMAP.md`, ecc.).
- [ ] Se le novità della release toccano §7 (Roadmap a fasi) o §10 (Questioni aperte) di
  `CLAUDE.md`, aggiornarli **nella stessa sessione**.

---

Vedi anche: [`CLAUDE.md`](../CLAUDE.md) §9 (convenzioni), [`ROADMAP.md`](./ROADMAP.md),
[`CHANGELOG-DEV.md`](./CHANGELOG-DEV.md).
