import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Renders the calm "take a breath" screen shown in place of the system's
/// generic restriction screen when a guarded app is opened.
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
        ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: nil,
            icon: UIImage(systemName: "wind"),
            title: ShieldConfiguration.Label(
                text: String(localized: "Take a breath"),
                color: .label
            ),
            subtitle: ShieldConfiguration.Label(
                text: String(localized: "Pause here for a moment before you continue."),
                color: .secondaryLabel
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: String(localized: "Not now"),
                color: .label
            )
        )
    }
}
