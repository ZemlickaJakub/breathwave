import Foundation

struct ShieldPrompt: Sendable {
    let title: String       // English source string, used as the localization key
    let subtitle: String    // English source string, used as the localization key
}

enum ShieldPrompts {
    static let icons: [String] = [
        "wind",
        "leaf",
        "moon.stars",
        "drop",
        "water.waves",
        "cloud",
        "sparkles",
        "sun.horizon"
    ]

    static let morning: [ShieldPrompt] = [
        ShieldPrompt(title: "Good morning", subtitle: "Let the day begin slowly."),
        ShieldPrompt(title: "One fresh breath", subtitle: "Start with air, not a screen."),
        ShieldPrompt(title: "Still waking up", subtitle: "Give yourself a soft start."),
        ShieldPrompt(title: "Morning is yours", subtitle: "Meet it before the noise."),
        ShieldPrompt(title: "Ease into it", subtitle: "There's no rush this early."),
        ShieldPrompt(title: "First light", subtitle: "Breathe before the scroll."),
        ShieldPrompt(title: "A calm beginning", subtitle: "Set the tone for today."),
        ShieldPrompt(title: "Not yet", subtitle: "Let the morning stay quiet."),
        ShieldPrompt(title: "Feel the morning", subtitle: "Notice the light around you."),
        ShieldPrompt(title: "Slow start", subtitle: "The day can wait a moment."),
        ShieldPrompt(title: "Wake gently", subtitle: "One breath before anything else."),
        ShieldPrompt(title: "Fresh page", subtitle: "Today hasn't been touched yet."),
        ShieldPrompt(title: "Before the rush", subtitle: "Take this quiet minute."),
        ShieldPrompt(title: "Rise softly", subtitle: "Let your mind catch up.")
    ]

    static let day: [ShieldPrompt] = [
        ShieldPrompt(title: "A small pause", subtitle: "Step out of the busy for a breath."),
        ShieldPrompt(title: "Midday reset", subtitle: "One breath to clear your head."),
        ShieldPrompt(title: "Still here?", subtitle: "Check in with yourself first."),
        ShieldPrompt(title: "Is this what you need?", subtitle: "Or just a quiet moment?"),
        ShieldPrompt(title: "Take a breath", subtitle: "The tasks will still be there."),
        ShieldPrompt(title: "Pause the day", subtitle: "Let your shoulders drop."),
        ShieldPrompt(title: "Come back", subtitle: "Notice where you are right now."),
        ShieldPrompt(title: "One clear breath", subtitle: "Reset before you continue."),
        ShieldPrompt(title: "Busy mind?", subtitle: "Give it a moment of quiet."),
        ShieldPrompt(title: "Right now", subtitle: "This moment is enough."),
        ShieldPrompt(title: "Step back", subtitle: "See the day with soft eyes."),
        ShieldPrompt(title: "A breath between", subtitle: "Rest in the space you have."),
        ShieldPrompt(title: "Slow down here", subtitle: "The afternoon can wait."),
        ShieldPrompt(title: "Really, right now?", subtitle: "Maybe this can wait a beat.")
    ]

    static let evening: [ShieldPrompt] = [
        ShieldPrompt(title: "Winding down", subtitle: "Let the day settle."),
        ShieldPrompt(title: "Softer now", subtitle: "The evening asks for less."),
        ShieldPrompt(title: "Set it down", subtitle: "The day is done enough."),
        ShieldPrompt(title: "Evening light", subtitle: "Let it slow you down."),
        ShieldPrompt(title: "Ease off", subtitle: "Give the day a gentle end."),
        ShieldPrompt(title: "Time to slow", subtitle: "Nothing needs solving now."),
        ShieldPrompt(title: "Let go of today", subtitle: "Breathe out what you carried."),
        ShieldPrompt(title: "Quiet evening", subtitle: "Trade the scroll for stillness."),
        ShieldPrompt(title: "Rest your eyes", subtitle: "The screen can dim now."),
        ShieldPrompt(title: "Almost done", subtitle: "Let the evening be soft."),
        ShieldPrompt(title: "Loosen your grip", subtitle: "The day can end gently."),
        ShieldPrompt(title: "Coming home", subtitle: "Return to yourself for a breath."),
        ShieldPrompt(title: "Dusk is here", subtitle: "Move a little slower now."),
        ShieldPrompt(title: "Enough for today", subtitle: "You can rest into the evening.")
    ]

    static let night: [ShieldPrompt] = [
        ShieldPrompt(title: "It's late", subtitle: "Do you really want to scroll?"),
        ShieldPrompt(title: "Still awake?", subtitle: "Let your mind grow quiet."),
        ShieldPrompt(title: "The night is quiet", subtitle: "You can be too."),
        ShieldPrompt(title: "Time to rest", subtitle: "The screen can wait for tomorrow."),
        ShieldPrompt(title: "One last breath", subtitle: "Then let the day go."),
        ShieldPrompt(title: "Late, isn't it?", subtitle: "Maybe sleep is closer than this."),
        ShieldPrompt(title: "Dim the noise", subtitle: "Give your eyes the dark."),
        ShieldPrompt(title: "Nothing new tonight", subtitle: "The feed can wait until light."),
        ShieldPrompt(title: "Toward sleep", subtitle: "Let each breath grow slower."),
        ShieldPrompt(title: "Put it down", subtitle: "Tomorrow will still be there."),
        ShieldPrompt(title: "Wind into night", subtitle: "Let the day close softly."),
        ShieldPrompt(title: "Rest is near", subtitle: "Follow your breath toward it."),
        ShieldPrompt(title: "The dark is kind", subtitle: "Let it hold you for a while."),
        ShieldPrompt(title: "Sleep is calling", subtitle: "Answer it instead.")
    ]

    static let anytime: [ShieldPrompt] = [
        ShieldPrompt(title: "One slow breath", subtitle: "That's all this moment asks."),
        ShieldPrompt(title: "You're here now", subtitle: "Let that be enough."),
        ShieldPrompt(title: "Just breathe", subtitle: "Nothing else to do right now."),
        ShieldPrompt(title: "Pause", subtitle: "Feel the breath you're taking."),
        ShieldPrompt(title: "Notice this moment", subtitle: "It won't come again."),
        ShieldPrompt(title: "Soften", subtitle: "Unclench your jaw and breathe."),
        ShieldPrompt(title: "Come back to now", subtitle: "This breath is the only one."),
        ShieldPrompt(title: "Breathe first", subtitle: "The app will still be here."),
        ShieldPrompt(title: "A quiet moment", subtitle: "Let it be simple."),
        ShieldPrompt(title: "Feel your breath", subtitle: "In, then slowly out."),
        ShieldPrompt(title: "Be where you are", subtitle: "Right here is enough."),
        ShieldPrompt(title: "Let it slow", subtitle: "There's no hurry in this breath."),
        ShieldPrompt(title: "Rest here", subtitle: "You don't have to rush on."),
        ShieldPrompt(title: "Take your time", subtitle: "One breath, then decide.")
    ]

    /// Fallback used only if a pool were somehow empty, so the picker never
    /// force-unwraps and never crashes.
    private static let fallback = ShieldPrompt(
        title: "One slow breath",
        subtitle: "That's all this moment asks."
    )

    private static let fallbackIcon = "wind"

    private static func bucket(forHour hour: Int) -> [ShieldPrompt] {
        switch hour {
        case 5...10:
            return morning
        case 11...16:
            return day
        case 17...21:
            return evening
        default: // 22, 23, 0, 1, 2, 3, 4
            return night
        }
    }

    /// Returns a prompt + icon for the given moment. Buckets by hour, then
    /// draws from that bucket plus the anytime pool. Uses the supplied
    /// generator so callers can make it deterministic in tests.
    static func pick(
        for date: Date,
        calendar: Calendar = .current,
        using generator: inout some RandomNumberGenerator
    ) -> (prompt: ShieldPrompt, icon: String) {
        let hour = calendar.component(.hour, from: date)
        let pool = bucket(forHour: hour) + anytime
        let prompt = pool.randomElement(using: &generator) ?? fallback
        let icon = icons.randomElement(using: &generator) ?? fallbackIcon
        return (prompt, icon)
    }

    /// Convenience using the system RNG.
    static func pick(for date: Date = Date(), calendar: Calendar = .current) -> (prompt: ShieldPrompt, icon: String) {
        var rng = SystemRandomNumberGenerator()
        return pick(for: date, calendar: calendar, using: &rng)
    }
}
