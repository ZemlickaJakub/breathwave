# Vlna — iOS breathing & meditation app

Minimalistická iOS appka (SwiftUI) na řízené dýchání a meditační timer.
Free, bez analytiky, bez backendu. Solo projekt Jakuba, vyvíjený Claude Code.

Brief a realizační plán (architektura, App Store metadata, review rizika): `docs/`

## Stack
- Swift 6, SwiftUI, min. deployment iOS 17.0
- Zero external dependencies — ŽÁDNÉ SPM balíčky nepřidávat
- AVFoundation (audio), CoreHaptics, HealthKit (jen zápis), StoreKit 2, Swift Charts

## Build, test, run
```bash
xcodebuild -scheme Vlna -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme Vlna -destination 'platform=iOS Simulator,name=iPhone 16' test
xcrun simctl launch booted cz.jakubzemlicka.vlna
```

## Konvence
- Soubor = jeden typ; Views max ~150 řádků, jinak extrahuj komponentu
- Žádné force unwrap (`!`) mimo testy
- Všechny user-facing stringy přes String Catalog (EN klíč, CS překlad) — nikdy hardcoded
- Commit: konvenční prefixy (feat:/fix:/chore:), česky nebo anglicky, krátce

## Architektura — respektuj
- BreathingEngine je jediný zdroj pravdy o stavu session; Views jen renderují
- Timing od CFAbsoluteTimeGetCurrent(), NIKDY kumulativní Timer ticks (drift)
- AVAudioSession aktivní JEN během session, deaktivovat v teardown
- Persistence: SessionStore (JSON v Documents). Žádná CoreData/SwiftData.

## Always / Never
- ALWAYS: po změně enginu spustit unit testy (`xcodebuild test`)
- ALWAYS: nové UI texty rovnou do Localizable.xcstrings v EN i CS
- NEVER: přidávat analytiku, síťové volání, třetí strany SDK
- NEVER: medical claims v UI textech ("léčí", "snižuje krevní tlak", "terapie")
- NEVER: měnit bundle ID, deployment target nebo capabilities bez explicitního OK
