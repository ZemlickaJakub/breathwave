# Breathwave — „Nádech před appkou" (Focus / Mindful Pause)

Datum: 2026-07-09
Status: **čeká na schválení Family Controls entitlementu** (žádost podána 2026-07-09).
Náhrada za zrušený Breath Sensor. Nový headline diferenciátor proti App Review 4.3.

---

## 1. Koncept
Než uživatel otevře jím vybranou rozptylující appku (IG, FB, TikTok…), Breathwave
vloží krátkou **vědomou dechovou pauzu**. Otevřeš appku → objeví se štít s výzvou
„nadechni se" → teprve pak pokračuješ. Fúze existujícího dýchání s focus mechanikou.

**Proč to sedí (a proč to Apple pustí):** spadá do povoleného účelu Family Controls
č. 2 — *focus/productivity, personal device usage management*. NENÍ to ad blocking
ani správa cizího zařízení (to podmínky zakazují). Individual authorization na
vlastním zařízení uživatele.

**Proč proti 4.3:** appka vyžadující Screen Time entitlement a schovávající appky
za dech se těžko označí za „duplikát template". Silnější než Breath Sensor kdy byl.

---

## 2. Frameworky (vše system, zero-dep — drží CLAUDE.md)
- **FamilyControls** — `AuthorizationCenter.requestAuthorization(for: .individual)`, `FamilyActivityPicker`.
- **ManagedSettings** — `ManagedSettingsStore().shield.applications = tokens`.
- **DeviceActivity** — rozvrh / re-aplikace štítu po grace okně (extension).

Deployment target 17.0 stačí (FamilyControls individual + Shield jsou iOS 16+). Žádná změna targetu.

---

## 3. Capability / entitlement
- `com.apple.developer.family-controls` — **žádost podána 2026-07-09** (self-service formulář).
- **Distribuční entitlement je nutný i pro TestFlight**, nejen App Store. Dokud není
  schválen, blokovací část nejde testovat přes TestFlight.
  - Development build na zařízení jde, ale naráží na Developer Mode (Jakubovi nešel zapnout) — vyřešit až bude potřeba.
- Ověřit, zda account-level grant pokrývá i extension targety, nebo je nutná žádost per target.
- **POZOR:** přidání entitlementu = změna capabilities → mění se App Store review surface.

---

## 4. Xcode targety (nutný Xcode GUI, ne CLI — pbxproj target surgery je křehká)
1. **App** — hlavní flow, autorizace, výběr appek, aplikace štítu.
2. **ShieldConfiguration extension** — vzhled štítu (titulek, podtitulek, ikona, 2 tlačítka). NE plné SwiftUI, NE živá animace.
3. **ShieldAction extension** — obsluha tlačítek štítu (breathe / not now).
4. **DeviceActivityMonitor extension** — grace okno: po „nadechl jsem se" sundat štít na X min, pak zas nasadit.
(DeviceActivityReport pro statistiky usage — až v2, teď vynechat.)

---

## 5. UX flow
1. **Onboarding:** zapnout feature → Screen Time autorizace (systémový prompt, Face ID/passcode).
2. **Výběr appek:** `FamilyActivityPicker` → `ActivitySelection` (jen anonymní tokeny, appka nikdy nevidí které appky to jsou).
3. **Aktivní štít:** na vybrané appky se aplikuje shield.
4. **Otevření blokované appky:** systém ukáže náš štít — „Take a breath before you continue".
5. **Tlačítko na štítu:**
   - **v1 (jednoduché):** „I'll breathe · continue for 5 min" → ShieldAction sundá štít na 5 min (DeviceActivity schedule ho vrátí). Dech vede text na štítu.
   - **v2 (cílové):** „Breathe" → otevře Breathwave → krátká vedená 30–60s session → automatické dočasné odemčení → uživatel se vrátí do appky.

**Omezení štítu (poctivě):** uvnitř štítu NEJDE spustit session. Elegantní „nadech se
naplno, pak odemkni" vyžaduje otevřít appku a manuální návrat (takhle to řeší one sec).

---

## 6. Persistence
- `ActivitySelection` je Codable → uložit do `AppSettings`/UserDefaults (tokeny jsou perzistentní, opaque).
- Nové settingy: `focusEnabled`, grace délka, vybraná selekce.
- **Žádná změna `Session`** ve v1 — pauza není „session". (v2 možnost logovat „pauzy" pro Garden/statistiky.)
- Privacy labels zůstávají **Data Not Collected** (tokeny neopouštějí zařízení, žádná síť).

---

## 7. Build sekvence (po schválení entitlementu)
1. Xcode: přidat Family Controls capability + entitlement soubor k appce.
2. Autorizační flow + settings obrazovka (zapnout, vybrat appky).
3. Aplikace štítu na selekci.
4. ShieldConfiguration extension — brandovaná pauza.
5. ShieldAction + DeviceActivityMonitor — grace okno (odemknout na X min, pak vrátit).
6. v2: „Breathe" → otevře appku → vedený dech → auto-unlock.
7. App Store: screenshoty focus flow, popis, review notes (framovat jako focus/mindfulness).
Po každém zásahu do modelu/enginu: `xcodebuild test`.

---

## 8. Rizika
- **Schválení entitlementu** — nejisté, může trvat týdny (2026 hlášení vývojářů). Blokuje celý build i testing.
- **Štít je omezený** — v1 UX bude kompromis; „breathe fully then unlock" je fiddly.
- **Testing** — TestFlight potřebuje distribuční entitlement; dev build potřebuje Developer Mode.
- **App Review** — Family Controls appky jsou uznávaná kategorie, ale texty musí sedět na povolený účel (focus, ne ad blocking).

---

## 9. Otevřené otázky
- v1 (text na štítu) vs. rovnou v2 (otevřít appku + vedený dech)? Doporučení: v1 ship, v2 iterace.
- Grace okno: pevných 5 min vs. nastavitelné?

## 10. Rozhodnutí a postup
- **2026-07-09:** ŽÁDNÝ interim resubmit 1.1. Počkáme na entitlement, postavíme focus a
  pošleme vše najednou jako **1.2**. Build 2 v TestFlightu (obsahuje ještě Breath Sensor)
  se nikam neposílá; příští build do review bude až focus 1.2.
- **Entitlement schválen 2026-07-09.**

### Stav buildu
- **M1 hotové** (commit): family-controls entitlement, FocusGuardService, FocusView, HomeView vstup.
- **M2 hotové** (commit): BreathwaveShield extension (branded štít). Target přidán přes `xcodeproj` gem (user-install).
- **Build 3 (1.2) nahraný do TestFlightu 2026-07-09** — M1+M2, k ověření foundation na zařízení.
- **M3 čeká** na výsledek testu foundation na zařízení (rozhodnutí: neověřovat naslepo).

### Stav M3+ (2026-07-09, build/testy zelené na simulátoru, neověřeno na zařízení)
- **ShieldAction extension** (BreathwaveShieldAction) — obsluha tlačítek: odolal → záznam, otevřel → sundá štít + záznam + naplánuje DeviceActivity návrat.
- **DeviceActivityMonitor** (BreathwaveMonitor) — `intervalDidEnd` vrátí štít po grace okně.
- **App Group** `group.cz.jakubzemlicka.breathwave` sdílí selekci, grace, mapping tlačítek a události mezi appkou a extensiony.
- **Rotující prompty** (70×2 EN+CS, denní doba, střídání ikon), **tmavý štít**, **náhodné prohození tlačítek** (anti-svalová paměť).
- **Nastavitelné grace okno** (1–30 min) v FocusView.
- **Statistiky + odznaky** (FocusStats/FocusBadges + FocusStatsView): odolal/otevřel dnes, streak, celkem; 7 bloom odznaků.
- **RIZIKO k ověření na zařízení:** DeviceActivity grace timing (krátká okna ~1 min můžou být nespolehlivá); mapping tlačítek přes App Group; zda shield config extension potřebuje family-controls entitlement.

### Gotchas (ať se neopakuje ladění)
- **Export/upload:** distribuční profil s novým entitlementem se přegeneruje jen když má
  exportOptions.plist `signingStyle = automatic`. Bez toho export selže na „profile doesn't
  include com.apple.developer.family-controls".
- **Extension Info.plist** (když GENERATE_INFOPLIST_FILE=NO): musí obsahovat `CFBundleExecutable
  = $(EXECUTABLE_NAME)`, jinak install padá na „missing CFBundleExecutable".
- Přidání targetu skriptem: soubory přidávat basename (cesta je na PBXGroup), ne s prefixem — jinak zdvojená cesta.
