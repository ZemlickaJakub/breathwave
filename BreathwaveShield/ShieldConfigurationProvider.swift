import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Renders the calm "take a breath" screen shown in place of the system's
/// generic restriction screen when a guarded app is opened. The prompt rotates
/// with the time of day, the icon varies, and the two buttons swap sides so
/// tapping "open" never becomes a reflex.
final class ShieldConfigurationProvider: ShieldConfigurationDataSource {
    override init() {
        super.init()
        // Diagnostics: prove the extension process launches at all. Written to
        // shared defaults — a separate channel from the file-based debug log,
        // in case file writes from this sandbox fail silently.
        FocusShared.defaults.set(Date().timeIntervalSince1970, forKey: FocusShared.Keys.diagConfigInitAt)
    }

    /// Diagnostics: count every invocation in shared defaults. If the custom
    /// shield renders but this count does not move, iOS drew it from its own
    /// cache without asking us — the key unknown behind the re-lock fallback.
    private func markInvoked(_ what: String) {
        let defaults = FocusShared.defaults
        defaults.set(defaults.integer(forKey: FocusShared.Keys.diagConfigInvokeCount) + 1,
                     forKey: FocusShared.Keys.diagConfigInvokeCount)
        defaults.set(Date().timeIntervalSince1970, forKey: FocusShared.Keys.diagConfigLastInvoked)
        FocusShared.debugLog("shieldConfig", what)
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        markInvoked("configuration(app)")
        return breatheShield(tokenData: ShieldButtons.tokenData(application.token))
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        markInvoked("configuration(app in category)")
        return breatheShield(tokenData: ShieldButtons.tokenData(application.token))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        markInvoked("configuration(web)")
        return breatheShield(tokenData: ShieldButtons.tokenData(webDomain.token))
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        markInvoked("configuration(web in category)")
        return breatheShield(tokenData: ShieldButtons.tokenData(webDomain.token))
    }

    private func breatheShield(tokenData: Data?) -> ShieldConfiguration {
        let picked = ShieldPrompts.pick(for: Date())

        // Which button opens the app is derived from the token + hour, the same
        // way the action extension derives it — no shared value to fall out of sync.
        let openIsPrimary = ShieldButtons.openIsPrimary(tokenData: tokenData)

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
