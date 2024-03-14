//
//  NotificationViewModel.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/4/12.
//

import UIKit
import Combine
import Pageboy
import MastodonAsset
import MastodonCore
import MastodonLocalization

final class NotificationViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    // input
    let context: AppContext
    let authContext: AuthContext
    let viewDidLoad = PassthroughSubject<Void, Never>()
    
    // output
    @Published var viewControllers: [UIViewController] = []
    @Published var currentPageIndex = 0 {
        didSet {
            lastPageIndex = currentPageIndex
        }
    }
    
    private var lastPageIndex: Int {
        get {
            guard let selectedTabName = UserDefaults.shared.getLastSelectedNotificationsTabName(
                accessToken: authContext.mastodonAuthenticationBox.userAuthorization.accessToken
            ), let scope = APIService.MastodonNotificationScope(rawValue: selectedTabName) else {
                return 0
            }
            
            return APIService.MastodonNotificationScope.allCases.firstIndex(of: scope) ?? 0
        }
        set {
            UserDefaults.shared.setLastSelectedNotificationsTabName(
                accessToken: authContext.mastodonAuthenticationBox.userAuthorization.accessToken,
                value: APIService.MastodonNotificationScope.allCases[newValue].rawValue
            )
        }
    }

    init(context: AppContext, authContext: AuthContext) {
        self.context = context
        self.authContext = authContext
        // end init
    }
}
    
extension NotificationTimelineViewModel.Scope {
    var title: String {
        switch self {
        case .everything:
            return L10n.Scene.Notification.Title.everything
        case .mentions:
            return L10n.Scene.Notification.Title.mentions
        }
    }
}

// MARK: - PageboyViewControllerDataSource
extension NotificationViewModel: PageboyViewControllerDataSource {
    
    func numberOfViewControllers(in pageboyViewController: PageboyViewController) -> Int {
        return viewControllers.count
    }
    
    func viewController(for pageboyViewController: PageboyViewController, at index: PageboyViewController.PageIndex) -> UIViewController? {
        return viewControllers[index]
    }
    
    func defaultPage(for pageboyViewController: PageboyViewController) -> PageboyViewController.Page? {
        guard
            let pageCount = pageboyViewController.pageCount,
            pageCount > 1,
            (0...(pageCount - 1)).contains(lastPageIndex)
        else {
            return .first /// this should never happen, but in case we somehow manage to acquire invalid data in `lastPageIndex` let's make sure not to crash the app.
        }
        return .at(index: lastPageIndex)
    }
    
}

