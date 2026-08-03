# ScreenZen — feature mapa (konkurenční analýza pro Breathwave)

Zdroje: web research (App Store, changelogy, recenze, Reddit) + analýza screen
recordingu Jakubova telefonu (2026-08-03, snímek po snímku). Účel: postupné
přebírání vybraných featur do Breathwave.

Kontext: App Store ID 1541027222 · 4.9★ / 46K hodnocení · zcela zdarma
(tip-based) · ~500K MAU · iOS 16.4+ (+ Android, macOS).

---

## A. Intervenční flow (jádro — přímo relevantní pro Breathwave)

### Zen screen — dva režimy (per skupina appek)
- **Mindful pause** — overlay (shield) s pauzou před odemčením:
  - *Pause time:* 0 / 5 / 10 / 20 / 30 / 45 / 60 / 90 / 120 / 180 / 300 s / Custom
  - *Reminder:* přednastavené otázky („Is this important?", „Why am I checking?",
    „Take a deep breath", „Relax your shoulders"…) nebo vlastní text
    (Jakub má: „Co jdes hledat? Na co jdes koukat? Vis to? Uvolni ramena,
    bricho a nadechni se")
  - Tlačítko **„Open (in 5s)"** — pauza je vestavěná do tlačítka (po dobu
    pauzy neaktivní), sekundární „Close"
- **Intervention** — místo pasivního čekání aktivita (redirect do ScreenZen):
  - Typy: **Breathing** (box breathing), Math Problems, Intentional Reason,
    Replacement App, To-do List, Word Guess, Offscreen Activities,
    Password Copy, Step Counter
  - *Breathing Times:* 12s / 30s / 45s / 1m / 1m30s / 2m / 4m / 7m + „Try it"
- **Progresivní delay** — čekání roste s počtem otevření v daný den
  (1. otevření 10 s → 10. otevření 60 s). Nejcitovanější mechanika v recenzích.
- **Odds that app unlocks** — náhodná šance, že se appka vůbec neodemkne.
- **Custom messages / Themes** — vlastní text a vzhled shieldu.

### Shield obsahuje (vše na jedné obrazovce)
- Vlastní reminder text (title/subtitle)
- **„Facebook 4/5 left"** + tečky — zbývající otevření za den
- **„Streak: 2 days"** — streak přímo na shieldu
- „Open (in 5s)" / „Close"

## B. Limity a odemykání

- **Daily Open Goal (opens budget)** — X otevření/den per appka; po vyčerpání
  tvrdý blok do půlnoci (volitelně). Uživatelé preferují před časovými limity.
- **Daily limit** — časový limit per skupina (v UI „5 minutes").
- **Session length** — odemčení na krátkou dobu (viděno: 1 min; notifikace
  „Opening in 5 seconds for 1 minute").
- **Cooldown** — povinná mezera mezi sessions.
- **Quick Unlock** — mini-odemčení „jen na zprávy", počítá se jako poloviční.
- **Warn before time expires** — notifikace před koncem session.
- **Interrupt scrolling** — periodické check-iny během používání.
- **Live Activity / Dynamic Island** — odpočet session + one-tap re-lock.

## C. Struktura a plánování

- **App Groups** — více skupin (Social media, Lifestyle…), každá vlastní
  pravidla (zen screen, limity, schedule). Přejmenování, mazání, přidání.
- **Výběr appek/webů** — kategorie (Social, Games, Entertainment…) + search;
  appky i webové domény zvlášť („Apps: 2 Websites: 0").
- **Scheduling** — presety (All the time / Work days / Week nights / Mornings)
  + custom dny×časy, více časových oken na skupinu („+ Add Time Window").
- **Strict block** — bez „open anyway": (a) časový rozsah, (b) po vyčerpání
  opens, (c) po vyčerpání času.

## D. Gamifikace a statistiky

- **Streak** per skupina, zobrazený na shieldu i v appce; streak freeze;
  skip counter (kolikrát obejito).
- **Stats** — jen pro hlídané appky (ne celkový čas): otevření, čas,
  prevented opens, týdenní trendy. (DeviceActivityReport extension.)
- **Social accountability** — sdílení streaků s přáteli (taby Halo/Friends).

## E. Web blocking

- Domény přes Screen Time API (Safari) + rozšíření pro Brave/Arc/Edge/Opera/
  Firefox. URL rules s výjimkami + tester. Recenze: občas nespolehlivé.

## F. Anti-bypass

- **Lock ScreenZen Settings** — passcode na změny nastavení.
- Prevence odinstalace, zámek změny data/času, parental passcode.
- Skrývání ikon blokovaných appek — **odstraněno kvůli Apple policy**
  (⚠️ neplánovat do Breathwave).

## G. Monetizace

- Vše zdarma; IAP jen dobrovolné tipy ($5/$10/$20/$40) — stejný model jako
  Breathwave tip jar. Hardware upsell „Halo" ($49 BT pebble — blokace podle
  fyzické zóny).

---

## Technické poznámky (ověřeno reverse-engineeringem chování)

- Intercept = čistý Screen Time API shield, ŽÁDNÉ Shortcuts automations
  (ověřeno: prázdná záložka Automations na telefonu s funkčním ScreenZen).
- „Open (in 5s)" → unshield + `.defer` → appka se otevře sama (ověřili jsme
  a převzali — funguje v Breathwave od build 15).
- Mid-foreground re-lock kreslí custom štít přes recyklovanou iOS cache
  (obsah štítu při re-locku je identický s otevřením — důkaz z videa).
  Breathwave: řešíme v build 17 (žádné nil zápisy do shield store).
- Unlock notifikace „Opening in 5 seconds for 1 minute" = lokální notifikace.
- Opens counter a streak na shieldu = dynamický ShieldConfiguration obsah
  (subtitle skládaný z App Group dat + unicode tečky ●●●●○).

## Top 10 dle sentimentu recenzí

1. Zdarma navždy (tip-based)
2. Progresivní delay
3. Opens budget („X left" na shieldu)
4. Streak na shieldu
5. Malé session chunky (3–6 min)
6. Interventions (breathing/math/důvod)
7. Replacement apps (redirect na Duolingo/Kindle)
8. Strict block + settings lock
9. Jednoduchý onboarding (bez Shortcuts)
10. Live Activity re-lock

## Kandidáti pro Breathwave (návrh priorit — k diskusi)

1. **Opens budget + tečky na shieldu** („3/5 dnes") — malý zásah, velký efekt;
   dynamický subtitle už umíme.
2. **Streak na shieldu** — streak logiku máme (SessionStore), jen ji promítnout.
3. **Pause vestavěná do tlačítka** („Otevřít (za 5 s)") — statický text,
   sedí k naší breathe identitě; delay řeší ShieldAction.
4. **Progresivní delay** — roste s počtem otevření za den.
5. **Breathing intervence v appce** (redirect po ťuknutí na notifikaci) —
   naše core kompetence, ScreenZen to má jen jako jednu z možností.
6. **Session countdown notifikace** — už máme („za 2 min zamkne"), rozšířit.
7. **Cooldown mezi sessions** — jednoduchá logika v App Group.
8. Později: schedule (časová okna), strict mode, Live Activity, stats view.

Pozn.: vlastní reminder text na shieldu už Breathwave částečně má
(ShieldPrompts rotace) — přidat možnost vlastního textu uživatele.
