import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Renders the calm "take a breath" screen shown in place of the system's
/// generic restriction screen when a guarded app is opened. The prompt rotates
/// with the time of day, the icon varies, and the two buttons swap sides at
/// random so tapping "open" never becomes a reflex.
final class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        breatheShield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        breatheShield()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        breatheShield()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        breatheShield()
    }

    private func breatheShield() -> ShieldConfiguration {
        let picked = ShieldPrompts.pick(for: Date())

        // Swap which physical button opens the app so it can't be tapped on
        // autopilot; record the choice so the action extension knows which
        // button the user actually pressed.
        let openIsPrimary = Bool.random()
        FocusShared.defaults.set(openIsPrimary, forKey: FocusShared.Keys.openIsPrimary)

        let open = ShieldConfiguration.Label(
            text: NSLocalizedString("Open for a while", comment: ""),
            color: UIColor(white: 1, alpha: 0.9)
        )
        let notNow = ShieldConfiguration.Label(
            text: NSLocalizedString("Not now", comment: ""),
            color: UIColor(white: 1, alpha: 0.9)
        )

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.4),
            icon: UIImage(systemName: picked.icon),
            title: ShieldConfiguration.Label(
                text: NSLocalizedString(picked.prompt.title, comment: ""),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: NSLocalizedString(picked.prompt.subtitle, comment: ""),
                color: UIColor(white: 1, alpha: 0.75)
            ),
            primaryButtonLabel: openIsPrimary ? open : notNow,
            primaryButtonBackgroundColor: nil,
            secondaryButtonLabel: openIsPrimary ? notNow : open
        )
    }
}
