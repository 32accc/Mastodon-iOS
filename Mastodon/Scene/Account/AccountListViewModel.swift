//
//  AccountListViewModel.swift
//  Mastodon
//
//  Created by Cirno MainasuK on 2021-9-13.
//

import UIKit
import Combine
import CoreData
import CoreDataStack
import MastodonSDK
import MastodonMeta
import MastodonCore
import MastodonUI

final class AccountListViewModel: NSObject {

    var disposeBag = Set<AnyCancellable>()

    // input
    let context: AppContext
    let authContext: AuthContext

    // output
    @Published var items: [Item] = []
    
    let dataSourceDidUpdate = PassthroughSubject<Void, Never>()
    var diffableDataSource: UITableViewDiffableDataSource<Section, Item>!

    init(context: AppContext, authContext: AuthContext) {
        self.context = context
        self.authContext = authContext

        super.init()
        // end init

        AuthenticationServiceProvider.shared.$authentications
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authentications in
                guard let self = self else { return }
                guard let diffableDataSource = self.diffableDataSource else { return }

                var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
                snapshot.appendSections([.main])
                let authenticationItems: [Item] = authentications.map {
                    Item.authentication(record: $0)
                }
                snapshot.appendItems(authenticationItems, toSection: .main)
                snapshot.appendItems([.addAccount], toSection: .main)
                snapshot.appendItems([.logoutOfAllAccounts], toSection: .main)

                diffableDataSource.apply(snapshot) {
                    self.dataSourceDidUpdate.send()
                }
            }
            .store(in: &disposeBag)
    }

}

extension AccountListViewModel {
    enum Section: Hashable {
        case main
    }

    enum Item: Hashable {
        case authentication(record: MastodonAuthentication)
        case addAccount
        case logoutOfAllAccounts
    }

    func setupDiffableDataSource(
        tableView: UITableView,
        managedObjectContext: NSManagedObjectContext
    ) {
        diffableDataSource = UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .authentication(let record):
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AccountListTableViewCell.self), for: indexPath) as! AccountListTableViewCell
                if let activeAuthentication = AuthenticationServiceProvider.shared.authenticationSortedByActivation().first
                {
                    AccountListViewModel.configure(
                        in: managedObjectContext,
                        cell: cell,
                        authentication: record,
                        activeAuthentication: activeAuthentication
                    )
                }
                return cell
            case .addAccount:
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AddAccountTableViewCell.self), for: indexPath) as! AddAccountTableViewCell
                return cell
            case .logoutOfAllAccounts:
                let cell = tableView.dequeueReusableCell(withIdentifier: LogoutOfAllAccountsCell.reuseIdentifier, for: indexPath) as! LogoutOfAllAccountsCell
                return cell
            }
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.main])
        diffableDataSource?.apply(snapshot)
    }

    static func configure(
        in context: NSManagedObjectContext,
        cell: AccountListTableViewCell,
        authentication: MastodonAuthentication,
        activeAuthentication: MastodonAuthentication
    ) {
        guard let account = authentication.account() else { return }

        // avatar
        cell.avatarButton.avatarImageView.configure(
            configuration: .init(url: account.avatarImageURL())
        )

        // name
        do {
            let content = MastodonContent(content: account.displayNameWithFallback, emojis: account.emojis.asDictionary)
            let metaContent = try MastodonMetaContent.convert(document: content)
            cell.nameLabel.configure(content: metaContent)
        } catch {
            assertionFailure()
            cell.nameLabel.configure(content: PlaintextMetaContent(string: account.displayNameWithFallback))
        }

        // username
        let usernameMetaContent = PlaintextMetaContent(string: "@" + account.acctWithDomain)
        cell.usernameLabel.configure(content: usernameMetaContent)
        
        // badge
        let accessToken = authentication.userAccessToken
        let count = UserDefaults.shared.getNotificationCountWithAccessToken(accessToken: accessToken)
        cell.badgeButton.setBadge(number: count)
        
        // checkmark
        let isActive = activeAuthentication.userID == authentication.userID
        cell.tintColor = .label
        cell.checkmarkImageView.isHidden = !isActive
        if isActive {
            cell.accessibilityTraits.insert(.selected)
        } else {
            cell.accessibilityTraits.remove(.selected)
        }
        
        cell.accessibilityLabel = [
            cell.nameLabel.text,
            cell.usernameLabel.text,
            cell.badgeButton.accessibilityLabel
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }
}
