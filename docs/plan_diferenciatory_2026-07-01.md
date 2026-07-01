# Breathwave — plán diferenciace (odpověď na App Review 4.3 Spam)

Datum: 2026-07-01
Autor: Jakub + Claude Code
Status: schválený směr, čeká na potvrzení timingu resubmitu

---

## 1. Kontext a proč to děláme

Breathwave 1.0 (build 1) byl dvakrát odmítnut App Review. První kolo (2.3.7 subtitle, 2.1b umístění IAP) bylo vyřešeno bez buildu. Druhé kolo:

> **Guideline 4.3(a) — Design: Spam.** „This app duplicates the content and functionality of other apps submitted to the App Store."

Po odpovědi v Resolution Center Apple stanovisko **potvrdil** a odmítl jmenovat konkurenci (standard). Argumentační cesta je vyčerpaná. Jediná cesta, která fakticky mění výsledek, je **reálná koncepční diferenciace appky** — nový mechanik nebo koncept, ne skin ani text.

Kategorie „dýchání + timer + animovaný kruh/vlna" je natolik přesycená, že Apple ji plošně škrtá jako template, i když je kód originální. Kvalita nestačí; musí být vidět **funkční odlišnost**.

### Zvolená strategie
Postavit **tři** diferenciátory, každý nativní / offline / bez nového permissionu, v pořadí od nejlehčího po nejsilnější:

- **Fáze 3** — Screen-free haptic dýchání (nejlevnější, de-risk)
- **Fáze 2** — Breath garden (generativní art z praxe)
- **Fáze 1** — Breath sensing přes pohyb (headline mechanik, nejsilnější proti 4.3)

Pořadí buildu je 3 → 2 → 1. Pořadí síly proti 4.3 je opačné (1 > 2 > 3).

---

## 2. Cíle a non-cíle

### Cíle
- Vytáhnout appku z „generic breathing app" škatulky reálnou funkcionalitou.
- Přidat aspoň jeden mechanik, u kterého Apple těžko obhájí „duplikát" (Fáze 1: appka **měří** dech).
- Zachovat identitu appky: klidná, minimalistická, offline, privacy-first, bez reklam.
- Aktualizovat App Store prezentaci (screenshoty, popis), aby reviewer odlišnost **viděl**.

### Non-cíle
- Žádný pivot pryč od dýchání/meditace. Stavíme nad existující koncept, ne vedle něj.
- Žádná monetizace navíc (tip jar zůstává jak je).
- Žádné medical/terapeutické nároky.

---

## 3. Průřezové konstrainty (závazné, z CLAUDE.md)

- **Zero external dependencies** — žádné SPM balíčky. Jen system frameworks (SwiftUI, CoreMotion, CoreHaptics, AVFoundation, Accelerate, Swift Charts).
- **Žádná síť, žádná analytika, žádné 3rd-party SDK.**
- **Žádné medical claims** v UI ani App Store textech („léčí", „snižuje tlak", „terapie").
- **Všechny user-facing stringy** přes `Localizable.xcstrings` — EN klíč + CS překlad, rovnou při psaní.
- **Po každé změně enginu → `xcodebuild test`.**
- **Views max ~150 řádků**, jinak extrahovat komponentu. Soubor = jeden typ.
- **Žádný force unwrap** mimo testy.
- **Timing od `CFAbsoluteTimeGetCurrent()`**, nikdy kumulativní Timer ticks.
- **AVAudioSession aktivní jen během session**, deaktivovat v teardown.
- **Bez explicitního OK neměnit** bundle ID, deployment target, capabilities/entitlements.

### Capability audit (důležité)
Aktuální stav: entitlements = jen `com.apple.developer.healthkit`; Info.plist = HealthKit usage stringy + `UIBackgroundModes: audio`.

- **Fáze 3 (haptika):** CoreHaptics — už v projektu, žádná změna.
- **Fáze 2 (art):** čistě SwiftUI Canvas — žádná změna.
- **Fáze 1 (motion):** surový `CMMotionManager` deviceMotion/accelerometer **nevyžaduje** usage string ani entitlement. Usage string (`NSMotionUsageDescription`) potřebuje jen `CMMotionActivityManager`/`CMPedometer`, které **nepoužijeme**. → **Žádná capability změna, žádný permission dialog.** (Ověřit on-device před resubmitem.)

Závěr: ani jedna fáze nevyžaduje entitlement ani permission prompt. To je záměr — snižuje review riziko i tvoje obavy z capability změn.

---

## 4. Architektura — na co navazujeme

Relevantní existující kód (potvrzeno čtením):

- `Engine/BreathingEngine.swift` — `@MainActor @Observable`, jediný zdroj pravdy o session. Absolutní čas, nedriftuje. `Snapshot` = { phase, phaseProgress, phaseRemaining, cycleIndex, elapsed, remaining }. Stavy idle/running/paused/finished. Reusable pro všechny fáze.
- `Models/BreathingProtocol.swift` — `BreathPhase` enum (inhale / holdAfterInhale / exhale / holdAfterExhale), `BreathingProtocol` (4 fáze v sekundách, `phases`, `cycleDuration`, `isOmTraining`). Presety: coherent, box, 4-7-8, extended-exhale, + interní meditation, om.
- `Views/BreathingSessionView.swift` — host session: pickery (délka, om length) + `PacerView` v `TimelineView(.animation)` + `SessionControls` + `runPhaseLoop()` (poll 50 ms, tick + 1 haptika/přechod). Om reuse přes `activeProtocol`.
- `Engine/HapticsEngine.swift` — `play(phase, duration)`: inhale = ramp 0.25→0.9, exhale = 0.9→0.25, hold = soft tap. **Foreground only** (komentář v kódu: CoreHaptics nehraje se zhasnutým displejem; audio to pokrývá).
- `Engine/AudioEngine.swift`, `DroneProgram.swift`, `OceanProgram.swift` — procedurální audio, breath-synced surf + om drone.
- `Models/Session.swift` — `Session` { id UUID, completedAt, duration, kind }. `Kind` = `.breathing(protocolID:)` / `.meditation`. Codable.
- `Models/SessionStore.swift` — `@Observable`, JSON v Documents. `add()`, `currentStreak()`, `dailyMinutes()`, `totalDuration`.
- `Models/AppSettings.swift` — UserDefaults toggly (hapticsEnabled, healthSyncEnabled, breathSound, gongSound, hasCompletedOnboarding).
- `Views/HomeView.swift` — NavigationStack, sekce „Breathing" / „Meditation", `navigationDestination(for: BreathingProtocol.self)`, toolbar: Settings (leading) + Stats (trailing).
- `Views/StatsView.swift` — streak + total + 7denní bar chart (Swift Charts).
- `Engine/HealthService.swift` — write-only HealthKit.

---

## 5. Fáze 3 — Screen-free haptic dýchání

### Koncept
Dedikovaný „tmavý" režim dechového cvičení: obrazovka zčerná (jen jemný glow / dýchající tečka), vedení jede primárně **haptikou + zvukem**. Uživatel zavře oči, telefon drží v ruce. Opačný UX než visual-first konkurence.

### Poctivé technické omezení
CoreHaptics **nehraje se zamčeným/zhasnutým displejem**. „Screen off" doslova nejde. Reálný design:
- Displej **zůstane rozsvícený**, ale černý → `UIApplication.shared.isIdleTimerDisabled = true` po dobu režimu (vrátit v teardown).
- Formulace v UI a App Store: „tmavý displej / bez vizuálu", **nikdy** „vypnutá obrazovka".

### UX
- Vstup: toggle `SensoryMode` (visual / dark) v pickerech `BreathingSessionView`, nebo samostatný vstup. Preferováno: toggle v session, aby fungoval pro libovolný protokol.
- Po startu v dark módu: `DarkPacerView` místo `PacerView` — téměř černé pozadí, jemný glow pulzující s fází (nízký jas), skryté ovládání (tap kdekoliv = zobrazí pauzu/end).
- Haptika je hlavní kanál: rozšířit choreografii.

### Kód
- `Engine/HapticsEngine.swift` — rozšířit: dnes 1 continuous ramp/fáze. Přidat jemný „turn-around" transient na vrcholu nádechu a dně výdechu (pomůže orientaci se zavřenýma očima), případně jemnější sharpness pro plynulejší pocit. Zachovat foreground-only chování.
- `Views/Components/DarkPacerView.swift` — nový, minimal glow render (Canvas nebo jednoduchý tvar + opacity/scale z `snapshot.phaseProgress`).
- `Views/BreathingSessionView.swift` — přidat `@State sensoryMode`, přepínat pacer, řídit `isIdleTimerDisabled`.
- `Models/AppSettings.swift` — volitelně `sensoryMode` toggle pro trvalou volbu (default visual).
- Stringy EN+CS: název režimu, krátký popis, instrukce.

### Edge cases
- Zařízení bez haptiky (`isAvailable == false`): dark mód se opře jen o zvuk; zobrazit jemnou vizuální stopu nebo upozornit.
- Příchozí notifikace / App do backgroundu: `isIdleTimerDisabled` resetovat; po návratu obnovit. Session žije dál přes audio session (existující mechanika).
- Teardown vždy vrátí `isIdleTimerDisabled = false`.

### Testy
- Engine se nemění → stávající testy musí projít.
- Pokud vytáhnu výběr haptického patternu do čisté funkce, unit test na mapping fáze → pattern params.

### Síla proti 4.3
Slabá samostatně (haptika v appce už je). Účel: nejlevnější fáze, de-risk haptické cesty, přidaná hodnota. **Není důvod k resubmitu sama o sobě.**

---

## 6. Fáze 2 — Breath garden (generativní art)

### Koncept
Každá dokončená session vygeneruje **unikátní procedurální „květ"**, deterministicky odvozený z dat session. Kolekce květů = tvoje rostoucí zahrada. Přes týdny osobní vyvíjející se dílo. Gamifikace praxe bez tlaku (à la Forest, ale generativní art z dechu, ne strom).

### Determinismus a data
- Seed = stabilní hash z `Session.id` (UUID) + `duration` + `kind` + `completedAt`. Stejná session → vždy stejný květ.
- **Žádná nová persistence** — zahrada se dopočítá z existujícího `SessionStore`. Reprodukovatelná, nulové migrace.
- Mapování seedu na vizuál: počet okvětních lístků / větví z délky session, barevná paleta z typu protokolu, jemné variace z hashe. (Po Fázi 1 lze obohatit o „steadiness" → pravidelnost/čistota květu.)

### UX
- `GardenView.swift` — mřížka/koláž blooms, řazeno dle data. Prázdný stav (ContentUnavailableView) jako ve StatsView.
- Detail bloomu: datum, délka, protokol.
- Vstup: ikona v Home toolbaru vedle Stats, nebo karta. (Rozhodnout při implementaci — toolbar je čistší.)

### Kód
- `Views/Garden/BreathBloom.swift` — čistá funkce `seed → BloomParameters`, render přes SwiftUI `Canvas`. Žádné assety, žádné deps.
- `Views/Garden/GardenView.swift` — galerie + detail.
- Volitelně `Models/BreathGarden.swift` — layout/agregace, pokud GardenView přeroste ~150 řádků.
- Stringy EN+CS: název „Garden", prázdný stav, detail labely.

### Edge cases
- Hodně sessions → líné vykreslování v `LazyVGrid`, Canvas je levný.
- Deterministický seed nesmí záviset na lokálním čase renderu, jen na datech session.

### Testy
- Čistá funkce seed → parametry: stejný seed = stejné parametry (stabilita), různé seedy = různé parametry (rozptyl). Testovat parametry, ne piksely.

### Síla proti 4.3
Silná — celá obrazovka vypadá jinak než cokoli v kategorii, jasná vlastní vizuální identita.

---

## 7. Fáze 1 — Breath sensing přes pohyb (headline)

### Koncept
Telefon položený na břicho/hruď. Appka přes **CoreMotion** snímá reálné stoupání a klesání při dýchání. Vlna na displeji **je tvůj skutečný dech**, ne přednastavená animace. K tomu „steadiness" skóre a volitelný target overlay (dýchej podle vodítka). Mění tvrzení appky z „ukazuju animaci" na **„měřím, jak dýcháš"**.

### Signál a DSP
- `CMMotionManager` deviceMotion (nebo raw accelerometer) ~30–50 Hz.
- Dýchání je nízkofrekvenční: ~0,1–0,4 Hz (6–24 dechů/min). Band-pass / low-pass filtr na dýchací pásmo, vstup = vhodná osa (gravitace/attitude komponenta při telefonu naplocho na břiše, nebo vertikální akcelerace).
- Detekce turning pointů (vrchol = konec nádechu, dno = konec výdechu) přes peak/zero-cross detekci vyhlazeného signálu.
- Rate = z period mezi turning pointy. Steadiness = konzistence period + amplitud (nižší rozptyl = vyšší skóre).
- Případně `Accelerate` (vDSP) pro filtr, pokud IIR ručně nestačí. Bez deps.

### Permissions
Surový accelerometer/deviceMotion **nevyžaduje** usage string ani entitlement. **Žádná capability změna, žádný dialog.** Ověřit on-device.

### UX
- `BreathSensingView.swift` — nová obrazovka:
  1. Onboarding krok: „Lehni si a polož telefon na břicho" (ilustrace).
  2. Krátká kalibrace (baseline klidové polohy, pár sekund).
  3. Live vlna = detekovaný dech; volitelný target rytmus k dýchání podle.
  4. Po skončení: detekovaný průměrný rate + steadiness skóre.
- Vstup z Home: nová karta v sekci „Breathing", např. „Breath Sensor" / „Guided by your breath".

### Datový model
- `Session.Kind` rozšířit o `.breathSensing` (nebo speciální protocol id + flag). Uložit steadiness (nové volitelné pole nebo separátní metadata). Zpětná kompatibilita Codable: nové pole optional s defaultem.
- Steadiness feeduje i Fázi 2 (bohatší bloomy).

### Kód
- `Engine/MotionBreathDetector.swift` — **čistá DSP** (filtr + turning pointy + rate + steadiness). Bez CoreMotion importu v jádře logiky → testovatelné synthetic signálem. `@MainActor` není nutné pro čistou část.
- `Engine/BreathMotionSensor.swift` — `@MainActor @Observable`, obaluje `CMMotionManager`, feeduje detektor, exposuje `amplitude`, `rate`, `steadiness`, `phase`.
- `Views/BreathSensingView.swift` (+ případně extrahované komponenty pro <150 řádků).
- `Models/Session.swift` — rozšíření Kind + steadiness.
- Stringy EN+CS: název, instrukce, kalibrace, výsledek.

### Poctivá omezení
- Nejlepší **vleže, telefon naplocho na břiše**. Vsedě zašuměné → napsat jasné instrukce, případně omezit na doporučenou polohu.
- Ne medical-grade. Popisovat jako praxi/zpětnou vazbu, ne měření zdraví.

### Edge cases
- Telefon v pohybu / chůze: detektor nesmí falešně „vidět dech" — práh amplitudy + sanity check rate.
- Zařízení bez potřebných senzorů (nереálné na iPhonu, ale ošetřit `isDeviceMotionAvailable`).
- Teardown: zastavit motion updates vždy (šetří baterii).

### Testy
- `MotionBreathDetector`: synthetic sine (různé frekvence/amplitudy/šum) → očekávaný rate, správné turning pointy, monotónní steadiness (čistší signál = vyšší skóre).

### Síla proti 4.3
Nejsilnější. Appka fyzicky snímá dech — kategoricky jiná funkce než preset animace. Tohle je hlavní „ne-duplikát" argument pro reviewera i pro případné odvolání.

---

## 8. App Store resubmit balíček

Nový build je nutný (mění se binárka). K němu:

- **Screenshoty** — přidat/nahradit tak, aby nový mechanik byl **vidět** (zejména Breath Sensor obrazovka a Garden). U 4.3 hrají screenshoty velkou roli — reviewer musí odlišnost poznat z galerie.
- **Popis + promo text** — vyzdvihnout: „measures your actual breath", „your own breath garden", „guided by touch in the dark". Bez cenové reference (2.3.7 hlídat), bez medical claims.
- **App Review Notes** — krátce popsat nové unikátní funkce a jak je najít.
- **Verze/build** — buď nový build pod 1.0, nebo bump 1.1 (rozhodnout; nový build tak jako tak).

---

## 9. Kdy resubmitnout (DECISION — čeká na potvrzení)

Doporučení Claude:
- **Neposílat po Fázi 3.** Haptika už v appce je, 4.3 reviewer rozdíl neuvidí; opakovaný reject může zhoršit pozici.
- **Ideál: resubmit až po Fázi 1** (motion = reálný důkaz odlišnosti). Fáze 3 + 2 mezitím přidávají hodnotu a polish.
- **Minimum: po Fázi 2** (garden = silná vizuální identita).

Jakubovo rozhodnutí: _(doplnit)_

---

## 10. Rizika

- **Fáze 1 přesnost:** accelerometer detekce dechu je zašuměná vsedě. Mitigace: doporučená poloha vleže + kalibrace + prahy. I „hrubý" ale funkční mechanik stačí pro odlišení; nemusí být přesný na dech.
- **Review riziko:** i po diferenciaci může Apple držet 4.3. Mitigace: screenshoty + popis, které odlišnost jasně ukážou; v krajním případě odvolání k App Review Board už s reálnými změnami v ruce.
- **Rozsah:** tři fáze = několik nových souborů + testy. Mitigace: fázování, TodoWrite, testy po každé fázi enginu.
- **Baterie (Fáze 1):** motion updates + rozsvícený displej. Mitigace: updates jen během session, teardown vždy zastaví.

---

## 11. Sekvence / milníky

1. **M0** — potvrzení timingu resubmitu (sekce 9). _(blokuje jen resubmit, ne build)_
2. **M1 — Fáze 3:** haptická choreografie + DarkPacerView + toggle + idleTimer handling + stringy. Test build.
3. **M2 — Fáze 2:** BreathBloom (čistá funkce + testy) + GardenView + vstup + stringy. Test build.
4. **M3 — Fáze 1:** MotionBreathDetector (+ testy) + BreathMotionSensor + BreathSensingView + Session.Kind rozšíření + stringy. `xcodebuild test`.
5. **M4 — Resubmit balíček:** screenshoty + popis + review notes + build. Upload, resubmit.

Každý milník: samostatný commit(y), konvenční prefix, po zásahu do enginu spustit testy.

---

## 12. Otevřené otázky

- Timing resubmitu (sekce 9) — **čeká na Jakuba**.
- Verze: nový build pod 1.0 vs. bump 1.1 — rozhodnout před uploadem.
- Fáze 2 vstup: Home toolbar vs. karta — rozhodnout při implementaci.
- Fáze 1: samostatný `Session.Kind` vs. protocol id + flag — rozhodnout při implementaci (preferováno samostatný Kind kvůli čistotě statistik).
