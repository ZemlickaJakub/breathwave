import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Renders the calm "take a breath" screen shown in place of the system's
/// generic restriction screen when a guarded app is opened. The prompt rotates
/// with the time of day, the icon varies, and the two buttons swap sides so
/// tapping "open" never becomes a reflex.
/// IMPORTANT: this extension must stay free of ANY file or defaults I/O.
/// Writes from this sandbox fail, and instrumentation added in builds 17-18
/// coincided with the custom shield intermittently falling back to the
/// system's generic "Restricted" screen even on fresh opens — a crashed or
/// slow data source makes iOS draw the default. Render fast, touch nothing.
final class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        breatheShield(tokenData: ShieldButtons.tokenData(application.token))
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        breatheShield(tokenData: ShieldButtons.tokenData(application.token))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        breatheShield(tokenData: ShieldButtons.tokenData(webDomain.token))
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        breatheShield(tokenData: ShieldButtons.tokenData(webDomain.token))
    }

    private func breatheShield(tokenData: Data?) -> ShieldConfiguration {
        let picked = ShieldPrompts.pick(for: Date())

        // Which button opens the app is derived from the token + hour, the same
        // way the action extension derives it — no shared value to fall out of sync.
        let openIsPrimary = ShieldButtons.openIsPrimary(tokenData: tokenData)

        let open = ShieldConfiguration.Label(
            text: NSLocalizedString("Open (in 5 s)", comment: ""),
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
