# Mindful Pause — Shield vs. Shortcuts (úvaha k dořešení PO App Review)

**Status:** odloženo. Appka je v review (verze 1.0, build 11). K tomuhle se vracíme
až přijde Apple verdikt — je to velký architektonický zásah do funkce, kterou
Apple zrovna posuzuje. Do té doby NEsahat.

Referenční konkurence: **one sec** (Apple Design Award 2024), a **ScreenZen**.

## Dvě cesty, jak vložit něco mezi tap na ikonu a otevření appky

### Shield API (co používáme teď)
FamilyControls / ManagedSettings. `ManagedSettingsStore.shield.applications = tokeny`
→ systém sám místo appky vykreslí **štít**. Vzhled dodáváme přes
`ShieldConfigurationDataSource`, tap řeší `ShieldActionDelegate`.

**Strop API:** štít NENÍ naše appka a NENÍ obecné SwiftUI. Jen předdefinovaná
šablona — titulek, podtitulek, ikona, barva pozadí, **max. dvě tlačítka**. Žádná
animace, žádný časovač, žádný vynucený nádech. Shield action umí odpovědět jen
`.close` / `.defer` / `.none` — **NEDOKÁŽE otevřít naši appku ani URL**.

### Shortcuts automatizace (co dělá one sec)
Nejede přes FamilyControls. Uživatel si v appce Zkratky vytvoří Personal
Automation „Když otevřu Instagram → spusť zkratku", ta otevře jejich appku
(URL scheme / App Intent). Jejich appka pak běží na celé obrazovce → **plná
kontrola nad UI**: nafukující se kruh, haptika, odpočet „dýchej 8 s", otázka na
náladu. Po projití pošle uživatele zpět do Instagramu. Je to **přesměrování**,
ne systémový zámek.

## Klíčová zjištění (proč se to nedá jednoduše spojit)

1. **Ruční setup Shortcuts NELZE automatizovat.** iOS nemá žádné API na programové
   vytvoření Personal Automation. Neexistuje URL scheme ani App Intent, který by
   automatizaci založil za uživatele — je to tvrdé bezpečnostní omezení Applu.
   Můžeme poslat hotovou zkratku a provést pěkným onboardingem, ale spojení
   „otevření appky → zkratka" udělá vždy uživatel ručně, appku po appce. I one sec
   to tak má.

2. **Ze štítu se nedá předat štafeta do našeho UI.** Shield action neumí otevřít
   parent appku ani URL. Proto NEJDE hybrid „systém zachytí appku štítem → tapneš
   → otevře se naše animace nádechu". Plné UI s vynuceným nádechem jde JEN přes
   Shortcuts cestu.

3. **Obě cesty vedle sebe = nejhorší ze všech světů.** Dvojí UI, dvojí kód (dvě
   extension sady + Shortcuts logika + dva druhy statistik), matoucí onboarding
   („proč mám dva způsoby blokování?"). NEdělat.

## Srovnání

| | Shield (my) | Shortcuts (one sec) |
|---|---|---|
| Setup uživatelem | žádný — vybere appky, hotovo | ručně automatizace **pro každou appku** |
| UI mezi tapem a appkou | jen šablona (text + 2 tlačítka) | cokoliv — animace, časovač, otázky |
| Vynucený nádech | ❌ nejde | ✅ jejich hlavní feature |
| Spolehlivost | systémová, tvrdá | křehčí, dá se obejít |
| „Blokuje" reálně | ano | spíš připomínka |

## Kde jsme oproti one sec slabší
- Žádné **vynucené prodlení/nádech** — jen statický štít, „open" jde tapnout na
  reflex (randomizace pozice tlačítek to jen ztěžuje).
- Žádná reflexe „proč to chceš otevřít".
- Mělčí statistiky (oni: trendy, ušetřený čas, srovnání týdnů).

## Kde jsme silnější (nezahodit v marketingu)
- **Zero setup** — štít naskočí sám, u one sec ruční Shortcuts per-app.
- **Zdarma, bez trackingu, bez sítě** — jejich předplatné je hlavní stížnost.
- **Zasazení do dýchací praxe** (zahrada, cvičení, statistiky) — oni jsou jen blocker.

## Rozhodnutí k učinění po review
Pozicování určuje cestu:
- **„Klidná, zero-setup"** → zůstat u Shieldu, dotáhnout ho (text, „ušetřený čas"
  statistika). Konzistentní se zbytkem appky. — *momentální směr*
- **„Tvrdý friction blocker jako one sec"** → přejít na Shortcuts. Jiná appka,
  jiný onboarding, ztráta zero-setup výhody.

## Kandidáti na doladění (bez změny architektury, poměr dopad/úsilí)
- **B — statistika „ušetřený čas"** (resisted × odhad délky scrollu): vysoký dopad,
  nízké úsilí. Nejlepší první krok. *(favorit)*
- **A — grace jako „reflexní brzda"**: text „otevře se za pár sekund" / sekundární
  potvrzení. Střední dopad, nízké úsilí.
- C — nádech přes Shortcuts: vysoký dopad, velké úsilí, křehké. Zatím ne.
- D — ptát se na důvod otevření: střední, jen po otevření v appce (shield to neumí).
