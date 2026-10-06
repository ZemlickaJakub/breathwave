# Breathwave - iOS breathing & meditation app

Minimalistická iOS appka (SwiftUI) na řízené dýchání a meditační timer.
Free, bez analytiky, bez backendu. Solo projekt Jakuba, vyvíjený Claude Code.

Brief a realizační plán (architektura, App Store metadata, review rizika): `docs/`

## Stack
- Swift 6, SwiftUI, min. deployment iOS 17.0
- Zero external dependencies - ŽÁDNÉ SPM balíčky nepřidávat
- AVFoundation (audio), CoreHaptics, HealthKit (jen zápis), StoreKit 2, Swift Charts

## Build, test, run

**Swift kód ověřuje CI, ne stroj, na kterém vznikl** (rozhodl Jakub 6. 10. 2026).
`.github/workflows/test.yml` pouští `xcodebuild test` na macOS runneru u každého PR
a pushe na `main`; výsledky (`TestResults.xcresult`, log) jsou artefakt běhu.
Na Alfě (Linux) Xcode není, takže změna Swift kódu je ověřená až zeleným během
CI k hlavě PR - do té doby ji neohlašuj jako hotovou. Ruční průchod na zařízení
dělá Jakub, CI ho nenahrazuje. Příkazy níž platí na Jakubově Macu.

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # xcode-select míří na CLT
xcodebuild -scheme Breathwave -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -scheme Breathwave -destination 'platform=iOS Simulator,name=iPhone 17' test
xcrun simctl launch booted cz.jakubzemlicka.breathwave
```

## Konvence
- Soubor = jeden typ; Views max ~150 řádků, jinak extrahuj komponentu
- Žádné force unwrap (`!`) mimo testy
- Všechny user-facing stringy přes String Catalog (EN klíč, CS překlad) - nikdy hardcoded
- Commit: konvenční prefixy (feat:/fix:/chore:), česky nebo anglicky, krátce

## Architektura - respektuj
- BreathingEngine je jediný zdroj pravdy o stavu session; Views jen renderují
- Timing od CFAbsoluteTimeGetCurrent(), NIKDY kumulativní Timer ticks (drift)
- AVAudioSession aktivní JEN během session, deaktivovat v teardown
- Persistence: SessionStore (JSON v Documents). Žádná CoreData/SwiftData.

## Kdo tu rozhoduje

**Zadavatelem Breathwave je session ve `~/Work/personal/meditation-app`**
(v `ListAgents` `meditation-app-fb`), ne Boss-MA - rozhodl Jakub 6. 10. 2026:
„chci tebe pro tento projekt". Pravomoc Boss-MA z globálního `CLAUDE.md` se na
tenhle projekt nevztahuje. Zadavatel píše do issue „Hotovo =" včetně negativních
případů, merguje přes `gh pr merge --match-head-commit <hash>` a zavírá issue.
Stavitel píše kód a PR s testem, který na `main` padá a na PR projde; Tester
ověřuje výsledek a dává verdikt k hashi (model převzatý od Boss-MA, 6. 10. 2026).
Na Jakubovi zůstává ruční test na zařízení, App Store, peníze a pravidla agentů.

**Předávky a Jakubova rozhodnutí patří do `ZemlickaJakub/Alfa-Infra#79`** (soukromé),
rozhodnutí doslova a dřív, než se pošlou dál - zpráva do session s `/clear` zmizí.
Zadavatel dává `/clear` Staviteli a Testerovi, jen když je jejich předávka
v Alfa-Infra#79 novější než jejich poslední práce a agent nic nedělá (rozhodl Jakub
6. 10. 2026). Svůj `/clear` zadavatel nechává Jakubovi.

**Repo `ZemlickaJakub/breathwave` je PUBLIC** (ověř `gh repo view --json visibility`):
nic interního do `docs/`, commit messages, PR ani issues. Interní záležitosti
projektu patří do Alfa-Infra.

## Always / Never
- ALWAYS: po změně enginu musí projít unit testy - zelený běh CI k hlavě PR, viz Build, test, run
- ALWAYS: nové UI texty rovnou do Localizable.xcstrings v EN i CS
- NEVER: přidávat analytiku, síťové volání, třetí strany SDK
- NEVER: medical claims v UI textech ("léčí", "snižuje krevní tlak", "terapie")
- NEVER: měnit bundle ID, deployment target nebo capabilities bez explicitního OK
