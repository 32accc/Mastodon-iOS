// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import UIKit
import MastodonLocalization

class NotificationSettingTableViewCell: UITableViewCell {
    static let reuseIdentifier = "NotificationSettingTableViewCell"

    func configure(with entry: NotificationSettingEntry, viewModel: NotificationSettingsViewModel, notificationsEnabled: Bool) {

        switch entry {
        case.alert(_):
                // we use toggle cells for these
                break
            case .policy:
                var content = UIListContentConfiguration.valueCell()
                content.text = L10n.Scene.Settings.Notifications.Policy.title
                content.secondaryText = viewModel.selectedPolicy.title
                if notificationsEnabled {
                    content.textProperties.color = .label
                    content.secondaryTextProperties.color = .secondaryLabel
                } else {
                    content.textProperties.color = .secondaryLabel
                    content.secondaryTextProperties.color = .tertiaryLabel
                }

                contentConfiguration = content
        }
    }

}
