import Foundation

/// Short welcome lines for the home screen — one per app launch,
/// never the same one twice in a row. Keys are the English source
/// strings; translations live in Localizable.xcstrings.
enum Greetings {
    static let keys: [String] = [
        "Namaste 🙏",
        "Welcome, beautiful soul",
        "Today is a gift",
        "Breathe and be",
        "Calm within you",
        "The light in me greets the light in you",
        "You are exactly where you need to be",
        "Breathe in the present",
        "The universe embraces you",
        "Your journey begins now",
        "Be love",
        "Silence speaks",
        "Heart wide open",
        "Energy flows where attention goes",
        "Welcome home, within yourself",
        "Every breath a new beginning",
        "Trust the flow",
        "You are more than enough",
        "Peace be with you",
        "Let your light shine",
        "Rest in the present",
        "Here and now",
        "Your soul knows the way",
        "Welcome to stillness",
        "The universe is listening",
        "Be the wave, not the drop",
        "Gratitude opens the heart",
        "Today you bloom",
        "Calm begins within",
        "Breathe deeply, live lightly",
        "Your calm is your strength",
        "Let go of what weighs you down",
        "Sunshine in your soul",
        "You are a miracle in motion",
        "Observe, don't judge",
        "Love is your nature",
        "Rest on your breath",
        "Welcome, traveler",
        "Your presence is a gift",
        "Softness is courage",
        "Be the silence between thoughts",
        "Open yourself to the moment",
        "Your heart knows the answer",
        "Flow like water",
        "Take root, and you will bloom",
        "Calm is your home",
        "Today is calling you",
        "Trust your breath",
        "You are part of the whole",
        "Let the light in",
        "Nothing is missing here",
        "Your soul breathes with you",
        "Welcome back to yourself",
        "The universe is in no hurry, neither are you",
        "Be kind to yourself",
        "Everything lives in silence",
        "Your breath holds you",
        "Dissolve into the present",
        "Peace begins with a breath",
    ]

    private static let lastIndexKey = "greeting.lastIndex"

    /// Picks the greeting for this launch — random, but never repeating
    /// the one shown on the previous launch.
    static func pickForLaunch(defaults: UserDefaults = .standard) -> String {
        let lastIndex = defaults.object(forKey: lastIndexKey) as? Int
        var index = Int.random(in: 0..<keys.count)
        while index == lastIndex {
            index = Int.random(in: 0..<keys.count)
        }
        defaults.set(index, forKey: lastIndexKey)
        return keys[index]
    }
}
