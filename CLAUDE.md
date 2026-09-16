# Breathwave - iOS breathing & meditation app

Minimalistická iOS appka (SwiftUI) na řízené dýchání a meditační timer.
Free, bez analytiky, bez backendu. Solo projekt Jakuba, vyvíjený Claude Code.

Brief a realizační plán (architektura, App Store metadata, review rizika): `docs/`

## Stack
- Swift 6, SwiftUI, min. deployment iOS 17.0
- Zero external dependencies - ŽÁDNÉ SPM balíčky nepřidávat
- AVFoundation (audio), CoreHaptics, HealthKit (jen zápis), StoreKit 2, Swift Charts

## Build, test, run

**Swift kód se mění z Macu, kde jdou spustit testy.** Na Alfě (Linux, bez Xcode)
se dělají docs, App Store metadata a issues. Když z Alfy přesto sáhneš na kód,
commit smí, ale u změny napiš „nebuildováno, Alfa nemá Xcode" - neověřenou
změnu nikdy neohlašuj jako hotovou. (Změřeno 1. 9. 2026: `xcodebuild`, `swift`,
`swiftc` ani `xcrun` na Alfě neexistují.)

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

## Always / Never
- ALWAYS: po změně enginu spustit unit testy (`xcodebuild test`) - z Macu; z Alfy viz Build, test, run
- ALWAYS: nové UI texty rovnou do Localizable.xcstrings v EN i CS
- NEVER: přidávat analytiku, síťové volání, třetí strany SDK
- NEVER: medical claims v UI textech ("léčí", "snižuje krevní tlak", "terapie")
- NEVER: měnit bundle ID, deployment target nebo capabilities bez explicitního OK
