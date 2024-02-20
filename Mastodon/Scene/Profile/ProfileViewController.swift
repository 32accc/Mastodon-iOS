//
//  ProfileViewController.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-2-23.
//

import UIKit
import Combine
import MastodonMeta
import MetaTextKit
import MastodonAsset
import MastodonCore
import MastodonUI
import MastodonLocalization
import CoreDataStack
import TabBarPager
import XLPagerTabStrip
import MastodonSDK

protocol ProfileViewModelEditable {
    var isEdited: Bool { get }
}

final class ProfileViewController: UIViewController, NeedsDependency, MediaPreviewableViewController {
    
    public static let containerViewMarginForRegularHorizontalSizeClass: CGFloat = 64
    public static let containerViewMarginForCompactHorizontalSizeClass: CGFloat = 16
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    var disposeBag = Set<AnyCancellable>()
    var viewModel: ProfileViewModel!
    
    let mediaPreviewTransitionController = MediaPreviewTransitionController()
    
    private(set) lazy var cancelEditingBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: L10n.Common.Controls.Actions.cancel, style: .plain, target: self, action: #selector(ProfileViewController.cancelEditingBarButtonItemPressed(_:)))
        barButtonItem.tintColor = .white
        return barButtonItem
    }()

    private(set) lazy var settingBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(
            image: Asset.ObjectsAndTools.gear.image.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(ProfileViewController.settingBarButtonItemPressed(_:))
        )
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Common.Controls.Actions.settings
        return barButtonItem
    }()

    private(set) lazy var shareBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(
            image: Asset.Arrow.squareAndArrowUp.image.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(ProfileViewController.shareBarButtonItemPressed(_:))
        )
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Common.Controls.Actions.share
        return barButtonItem
    }()

    private(set) lazy var favoriteBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(
            image: Asset.ObjectsAndTools.star.image.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(ProfileViewController.favoriteBarButtonItemPressed(_:))
        )
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Scene.Favorite.title
        return barButtonItem
    }()
    
    private(set) lazy var bookmarkBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(
            image: Asset.ObjectsAndTools.bookmark.image.withRenderingMode(.alwaysTemplate),
            style: .plain,
            target: self,
            action: #selector(ProfileViewController.bookmarkBarButtonItemPressed(_:))
        )
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Scene.Bookmark.title
        return barButtonItem
    }()

    private(set) lazy var replyBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrowshape.turn.up.left"), style: .plain, target: self, action: #selector(ProfileViewController.replyBarButtonItemPressed(_:)))
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Common.Controls.Actions.reply
        return barButtonItem
    }()

    let moreMenuBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), style: .plain, target: nil, action: nil)
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Common.Controls.Actions.seeMore
        return barButtonItem
    }()
    
    private(set) lazy var followedTagsBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(image: UIImage(systemName: "number"), style: .plain, target: self, action: #selector(ProfileViewController.followedTagsItemPressed(_:)))
        barButtonItem.tintColor = .white
        barButtonItem.accessibilityLabel = L10n.Scene.FollowedTags.title
        return barButtonItem
    }()

    let refreshControl: RefreshControl = {
        let refreshControl = RefreshControl()
        refreshControl.tintColor = .white
        return refreshControl
    }()
    
    private(set) lazy var tabBarPagerController = TabBarPagerController()

    private(set) lazy var profileHeaderViewController: ProfileHeaderViewController = {
        let viewController = ProfileHeaderViewController(context: context, authContext: authContext, coordinator: coordinator, profileViewModel: viewModel)
        return viewController
    }()
    
    private(set) lazy var profilePagingViewController: ProfilePagingViewController = {
        let profilePagingViewController = ProfilePagingViewController()
        profilePagingViewController.viewModel = {
            let profilePagingViewModel = ProfilePagingViewModel(
                postsUserTimelineViewModel: viewModel.postsUserTimelineViewModel,
                repliesUserTimelineViewModel: viewModel.repliesUserTimelineViewModel,
                mediaUserTimelineViewModel: viewModel.mediaUserTimelineViewModel,
                profileAboutViewModel: viewModel.profileAboutViewModel
            )
            profilePagingViewModel.viewControllers.forEach { viewController in
                if let viewController = viewController as? NeedsDependency {
                    viewController.context = context
                    viewController.coordinator = coordinator
                }
            }
            return profilePagingViewModel
        }()
        return profilePagingViewController
    }()

    // title view nested in header
    var titleView: DoubleTitleLabelNavigationBarTitleView {
        profileHeaderViewController.titleView
    }
    

}

extension ProfileViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        profileHeaderViewController.updateHeaderContainerSafeAreaInset(view.safeAreaInsets)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(ProfileViewController.relationshipChanged(_:)), name: .relationshipChanged, object: nil)

        view.backgroundColor = .secondarySystemBackground
        let barAppearance = UINavigationBarAppearance()
        if isModal {
            barAppearance.configureWithDefaultBackground()
        } else {
            barAppearance.configureWithTransparentBackground()
        }
        navigationItem.standardAppearance = barAppearance
        navigationItem.compactAppearance = barAppearance
        navigationItem.scrollEdgeAppearance = barAppearance

        navigationItem.titleView = titleView

        let editingAndUpdatingPublisher = Publishers.CombineLatest(
            viewModel.$isEditing,
            viewModel.$isUpdating
        )
        // note: not add .share() here

        let barButtonItemHiddenPublisher = Publishers.CombineLatest3(
            viewModel.$isMeBarButtonItemsHidden,
            viewModel.$isReplyBarButtonItemHidden,
            viewModel.$isMoreMenuBarButtonItemHidden
        )

        editingAndUpdatingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEditing, isUpdating in
                guard let self = self else { return }
                self.cancelEditingBarButtonItem.isEnabled = !isUpdating
            }
            .store(in: &disposeBag)

        // build items
        Publishers.CombineLatest4(
            viewModel.$relationship,
            profileHeaderViewController.viewModel.$isTitleViewDisplaying,
            editingAndUpdatingPublisher,
            barButtonItemHiddenPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] account, isTitleViewDisplaying, tuple1, tuple2 in
            guard let self else { return }
            let (isEditing, _) = tuple1
            let (isMeBarButtonItemsHidden, isReplyBarButtonItemHidden, isMoreMenuBarButtonItemHidden) = tuple2

            var items: [UIBarButtonItem] = []
            defer {
                if items.isNotEmpty {
                    self.navigationItem.rightBarButtonItems = items
                } else {
                    self.navigationItem.rightBarButtonItems = nil
                }
            }

            if let suspended = self.viewModel.account.suspended, suspended == true {
                return
            }

            guard isEditing == false else {
                items.append(self.cancelEditingBarButtonItem)
                return
            }

            guard isTitleViewDisplaying == false else {
                return
            }

            guard isMeBarButtonItemsHidden else {
                items.append(self.settingBarButtonItem)
                items.append(self.shareBarButtonItem)
                items.append(self.favoriteBarButtonItem)
                items.append(self.bookmarkBarButtonItem)
                
                if self.currentInstance?.canFollowTags == true {
                    items.append(self.followedTagsBarButtonItem)
                }
                
                return
            }

            if !isMoreMenuBarButtonItemHidden {
                items.append(self.moreMenuBarButtonItem)
            }
            if !isReplyBarButtonItemHidden {
                items.append(self.replyBarButtonItem)
            }
        }
        .store(in: &disposeBag)
        
        context.publisherService.statusPublishResult.sink { [weak self] result in
            if case .success(.edit(let status)) = result {
                self?.updateViewModelsWithDataControllers(status: .fromEntity(status.value), intent: .edit)
            }
        }.store(in: &disposeBag)
        
        addChild(tabBarPagerController)
        tabBarPagerController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBarPagerController.view)
        tabBarPagerController.didMove(toParent: self)
        tabBarPagerController.view.pinToParent()

        tabBarPagerController.delegate = self
        tabBarPagerController.dataSource = self
        
        tabBarPagerController.relayScrollView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(ProfileViewController.refreshControlValueChanged(_:)), for: .valueChanged)
                
        // setup delegate
        profileHeaderViewController.delegate = self
        profilePagingViewController.viewModel.profileAboutViewController.delegate = self
                
        bindViewModel()
        bindTitleView()
        bindMoreBarButtonItem()
        bindPager()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.navigationBar.prefersLargeTitles = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear.send()

        setNeedsStatusBarAppearanceUpdate()
    }

}

extension ProfileViewController {
    
    private func bindViewModel() {
        // header
        let headerViewModel = profileHeaderViewController.viewModel
        viewModel.$account
            .assign(to: \.account, on: headerViewModel)
            .store(in: &disposeBag)
        viewModel.$isEditing
            .assign(to: \.isEditing, on: headerViewModel)
            .store(in: &disposeBag)
        viewModel.$isUpdating
            .assign(to: \.isUpdating, on: headerViewModel)
            .store(in: &disposeBag)
        viewModel.$relationship
            .assign(to: \.relationship, on: headerViewModel)
            .store(in: &disposeBag)
        viewModel.$accountForEdit
            .assign(to: \.accountForEdit, on: headerViewModel)
            .store(in: &disposeBag)

        [
            viewModel.postsUserTimelineViewModel,
            viewModel.repliesUserTimelineViewModel,
            viewModel.mediaUserTimelineViewModel,
        ].forEach { userTimelineViewModel in

            viewModel.relationship.publisher
                .map { $0.blocking }
                .assign(to: \UserTimelineViewModel.isBlocking, on: userTimelineViewModel)
                .store(in: &disposeBag)

            viewModel.relationship.publisher
                .compactMap { $0.blockedBy }
                .assign(to: \UserTimelineViewModel.isBlockedBy, on: userTimelineViewModel)
                .store(in: &disposeBag)

            viewModel.$account
                .compactMap { $0.suspended }
                .assign(to: \UserTimelineViewModel.isSuspended, on: userTimelineViewModel)
                .store(in: &disposeBag)
        }
    
        // about
        let aboutViewModel = viewModel.profileAboutViewModel
        viewModel.$account
            .assign(to: \.account, on: aboutViewModel)
            .store(in: &disposeBag)
        viewModel.$isEditing
            .assign(to: \.isEditing, on: aboutViewModel)
            .store(in: &disposeBag)
        viewModel.$accountForEdit
            .assign(to: \.accountForEdit, on: aboutViewModel)
            .store(in: &disposeBag)
    }

    private func bindTitleView() {
        Publishers.CombineLatest3(
            profileHeaderViewController.profileHeaderView.viewModel.$name,
            profileHeaderViewController.profileHeaderView.viewModel.$emojiMeta,
            profileHeaderViewController.profileHeaderView.viewModel.$statusesCount
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] name, emojiMeta, statusesCount in
            guard let self = self else { return }
            guard let title = name, let statusesCount = statusesCount,
                  let formattedStatusCount = MastodonMetricFormatter().string(from: statusesCount) else {
                self.titleView.isHidden = true
                return
            }
            self.titleView.isHidden = false
            let subtitle = L10n.Plural.Count.MetricFormatted.post(formattedStatusCount, statusesCount)
            let mastodonContent = MastodonContent(content: title, emojis: emojiMeta)
            do {
                let metaContent = try MastodonMetaContent.convert(document: mastodonContent)
                self.titleView.update(titleMetaContent: metaContent, subtitle: subtitle)
            } catch {

            }
        }
        .store(in: &disposeBag)
        profileHeaderViewController.profileHeaderView.viewModel.$name
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard let self = self, self.isModal == false else { return }
                self.navigationItem.title = name
            }
            .store(in: &disposeBag)

        profileHeaderViewController.profileHeaderView.viewModel.viewDidAppear
            .sink(receiveValue: { [weak self] _ in

                guard let self else { return }
                let account = self.viewModel.account
                guard let domain = account.domainFromAcct else { return }
                Task {
                    let account = try await self.context.apiService.fetchUser(
                        username: account.username,
                        domain: domain,
                        authenticationBox: self.authContext.mastodonAuthenticationBox
                    )

                    guard let account else { return }

                    let relationship = try await self.context.apiService.relationship(forAccounts: [account], authenticationBox: self.authContext.mastodonAuthenticationBox).value.first

                    guard let relationship else { return }

                    self.viewModel.relationship = relationship
                    self.viewModel.account  = account
                }
            })
            .store(in: &disposeBag)
    }

    private func bindMoreBarButtonItem() {
        Publishers.CombineLatest(
            viewModel.$account,
            viewModel.$relationship
        )
        .asyncMap { [weak self] user, relationship -> UIMenu? in
            guard let self, let relationship, let domain = user.domainFromAcct else { return nil }

            let name = user.displayNameWithFallback

            var menuActions: [MastodonMenu.Action] = [
                .muteUser(.init(name: name, isMuting: relationship.muting)),
                .blockUser(.init(name: name, isBlocking: relationship.blocking)),
                .blockDomain(.init(domain: domain, isBlocking: relationship.domainBlocking)),
                .reportUser(.init(name: name)),
                .shareUser(.init(name: name)),
            ]

            if relationship.following {
                let showReblogs = relationship.showingReblogs// me.showingReblogsBy.contains(user)
                let context = MastodonMenu.HideReblogsActionContext(showReblogs: showReblogs)
                menuActions.insert(.hideReblogs(context), at: 1)
            }

            let menu = MastodonMenu.setupMenu(
                actions: [menuActions],
                delegate: self
            )
            return menu
        }
        .sink { [weak self] completion in
            guard let self = self else { return }
            switch completion {
            case .failure:
                self.moreMenuBarButtonItem.menu = nil
            case .finished:
                break
            }
        } receiveValue: { [weak self] menu in
            guard let self = self else { return }
            DispatchQueue.main.async {
              self.moreMenuBarButtonItem.menu = menu
            }
        }
        .store(in: &disposeBag)
    }
    
    private func bindPager() {
        viewModel.$isPagingEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPagingEnabled in
                guard let self = self else { return }
                self.profilePagingViewController.containerView.isScrollEnabled = isPagingEnabled
                self.profilePagingViewController.buttonBarView.isUserInteractionEnabled = isPagingEnabled
            }
            .store(in: &disposeBag)
        
        viewModel.$isEditing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEditing in
                guard let self = self else { return }
                // set first responder for key command
                if !isEditing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.profilePagingViewController.becomeFirstResponder()
                    }
                }

                // dismiss keyboard if needs
                if !isEditing { self.view.endEditing(true) }
                
                if isEditing,
                   let index = self.profilePagingViewController.viewControllers.firstIndex(where: { type(of: $0) is ProfileAboutViewController.Type }),
                   self.profilePagingViewController.canMoveTo(index: index)
                {
                    self.profilePagingViewController.moveToViewController(at: index)
                }
            }
            .store(in: &disposeBag)
    }

    private func handleMetaPress(_ meta: Meta) {
        switch meta {
        case .url(_, _, let url, _):
            guard let url = URL(string: url) else { return }
            _ = coordinator.present(scene: .safari(url: url), from: nil, transition: .safariPresent(animated: true, completion: nil))
        case .mention(_, _, let userInfo):
            guard let href = userInfo?["href"] as? String,
                  let url = URL(string: href) else { return }
            _ = coordinator.present(scene: .safari(url: url), from: nil, transition: .safariPresent(animated: true, completion: nil))
        case .hashtag(_, let hashtag, _):
            let hashtagTimelineViewModel = HashtagTimelineViewModel(context: context, authContext: viewModel.authContext, hashtag: hashtag)
            _ = coordinator.present(scene: .hashtagTimeline(viewModel: hashtagTimelineViewModel), from: nil, transition: .show)
        case .email, .emoji:
            break
        }
    }

}

extension ProfileViewController {

    @objc private func cancelEditingBarButtonItemPressed(_ sender: UIBarButtonItem) {
        viewModel.isEditing = false
    }

    @objc private func settingBarButtonItemPressed(_ sender: UIBarButtonItem) {
        guard let setting = context.settingService.currentSetting.value else { return }

        _ = coordinator.present(scene: .settings(setting: setting), from: self, transition: .none)
    }

    @objc private func shareBarButtonItemPressed(_ sender: UIBarButtonItem) {
        let activityViewController = DataSourceFacade.createActivityViewController(
            dependency: self,
            account: viewModel.account
        )
        _ = self.coordinator.present(
            scene: .activityViewController(
                activityViewController: activityViewController,
                sourceView: nil,
                barButtonItem: sender
            ),
            from: self,
            transition: .activityViewControllerPresent(animated: true, completion: nil)
        )
    }

    @objc private func favoriteBarButtonItemPressed(_ sender: UIBarButtonItem) {
        let favoriteViewModel = FavoriteViewModel(context: context, authContext: viewModel.authContext)
        _ = coordinator.present(scene: .favorite(viewModel: favoriteViewModel), from: self, transition: .show)
    }
    
    @objc private func bookmarkBarButtonItemPressed(_ sender: UIBarButtonItem) {
        let bookmarkViewModel = BookmarkViewModel(context: context, authContext: viewModel.authContext)
        _ = coordinator.present(scene: .bookmark(viewModel: bookmarkViewModel), from: self, transition: .show)
    }

    @objc private func replyBarButtonItemPressed(_ sender: UIBarButtonItem) {

        let mention = "@" + viewModel.account.acct
        UITextChecker.learnWord(mention)
        let composeViewModel = ComposeViewModel(
            context: context,
            authContext: viewModel.authContext,
            composeContext: .composeStatus,
            destination: .topLevel,
            initialContent: mention
        )
        _ = coordinator.present(scene: .compose(viewModel: composeViewModel), from: self, transition: .modal(animated: true, completion: nil))
    }
    
    @objc private func followedTagsItemPressed(_ sender: UIBarButtonItem) {
        let followedTagsViewModel = FollowedTagsViewModel(context: context, authContext: viewModel.authContext)
        _ = coordinator.present(scene: .followedTags(viewModel: followedTagsViewModel), from: self, transition: .show)
    }

    @objc private func refreshControlValueChanged(_ sender: RefreshControl) {
        if let userTimelineViewController = profilePagingViewController.currentViewController as? UserTimelineViewController {
            userTimelineViewController.viewModel.stateMachine.enter(UserTimelineViewModel.State.Reloading.self)
        }

        Task {
            let account = viewModel.account
            if let domain = account.domain,
               let updatedAccount = try? await context.apiService.fetchUser(username: account.acct, domain: domain, authenticationBox: authContext.mastodonAuthenticationBox),
               let updatedRelationship = try? await context.apiService.relationship(forAccounts: [updatedAccount], authenticationBox: authContext.mastodonAuthenticationBox).value.first
            {
                viewModel.account = updatedAccount
                viewModel.relationship = updatedRelationship
            }

            if let updatedMe = try? await context.apiService.authenticatedUserInfo(authenticationBox: authContext.mastodonAuthenticationBox).value {
                viewModel.me = updatedMe
                FileManager.default.store(account: updatedMe, forUserID: authContext.mastodonAuthenticationBox.authentication.userIdentifier())
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sender.endRefreshing()
            }
        }
    }

}

// MARK: - TabBarPagerDelegate
extension ProfileViewController: TabBarPagerDelegate {
    
    func tabBarMinimalHeight() -> CGFloat {
        return ProfileHeaderViewController.headerMinHeight
    }
    
    func resetPageContentOffset(_ tabBarPagerController: TabBarPagerController) {
        for viewController in profilePagingViewController.viewModel.viewControllers {
            viewController.pageScrollView.contentOffset = .zero
        }
    }
    
    func tabBarPagerController(_ tabBarPagerController: TabBarPagerController, didScroll scrollView: UIScrollView) {
        // try to find some patterns:
        // print("""
        // -----
        // headerMinHeight: \(ProfileHeaderViewController.headerMinHeight)
        // scrollView.contentOffset.y: \(scrollView.contentOffset.y)
        // scrollView.contentSize.height: \(scrollView.contentSize.height)
        // scrollView.frame: \(scrollView.frame)
        // scrollView.adjustedContentInset.top: \(scrollView.adjustedContentInset.top)
        // scrollView.adjustedContentInset.bottom: \(scrollView.adjustedContentInset.bottom)
        // """
        // )

        
        // elastically banner

        // make banner top snap to window top
        // do not rely on the view frame becase the header frame is .zero during the initial call
        profileHeaderViewController.profileHeaderView.bannerImageViewTopLayoutConstraint.constant = min(0, scrollView.contentOffset.y)
        
        if profileHeaderViewController.profileHeaderView.frame != .zero {
            // make banner bottom not higher than navigation bar bottom
            let bannerContainerInWindow = profileHeaderViewController.profileHeaderView.convert(
                profileHeaderViewController.profileHeaderView.bannerContainerView.frame,
                to: nil
            )
            let bannerContainerBottomOffset = bannerContainerInWindow.origin.y + bannerContainerInWindow.height
            // print("bannerContainerBottomOffset: \(bannerContainerBottomOffset)")
            
            let height = profileHeaderViewController.view.frame.height - bannerContainerInWindow.height
            // make avata hidden when scroll 0.5x avatar height 
            let throttle = height != .zero ? 0.5 * ProfileHeaderView.avatarImageViewSize.height / height : 0
            let progress: CGFloat
            
            if bannerContainerBottomOffset < tabBarPagerController.containerScrollView.safeAreaInsets.top {
                let offset = bannerContainerBottomOffset - tabBarPagerController.containerScrollView.safeAreaInsets.top
                profileHeaderViewController.profileHeaderView.bannerImageViewBottomLayoutConstraint.constant = offset
                // the progress for header move from banner bottom to header bottom (from 0 to 1)
                progress = height != .zero ? abs(offset) / height : 0
            } else {
                profileHeaderViewController.profileHeaderView.bannerImageViewBottomLayoutConstraint.constant = 0
                progress = 0
            }
            
            // setup follows you mask
            // 1. set mask size
            profileHeaderViewController.profileHeaderView.followsYouMaskView.frame = profileHeaderViewController.profileHeaderView.followsYouBlurEffectView.bounds
            // 2. check follows you view overflow navigation bar or not
            let followsYouBlurEffectViewInWindow = profileHeaderViewController.profileHeaderView.convert(
                profileHeaderViewController.profileHeaderView.followsYouBlurEffectView.frame,
                to: nil
            )
            if followsYouBlurEffectViewInWindow.minY < tabBarPagerController.containerScrollView.safeAreaInsets.top {
                let offestY = tabBarPagerController.containerScrollView.safeAreaInsets.top - followsYouBlurEffectViewInWindow.minY
                let height = profileHeaderViewController.profileHeaderView.followsYouMaskView.frame.height
                profileHeaderViewController.profileHeaderView.followsYouMaskView.frame.origin.y = min(offestY, height)
            } else {
                profileHeaderViewController.profileHeaderView.followsYouMaskView.frame.origin.y = .zero
            }
            
            // setup titleView offset and fade avatar
            profileHeaderViewController.updateHeaderScrollProgress(progress, throttle: throttle)
            
            // setup buttonBar shadow
            profilePagingViewController.updateButtonBarShadow(progress: progress)
        }
    }
    
}

// MARK: - TabBarPagerDataSource
extension ProfileViewController: TabBarPagerDataSource {
    func headerViewController() -> UIViewController & TabBarPagerHeader {
        return profileHeaderViewController
    }
    
    func pageViewController() -> UIViewController & TabBarPageViewController {
        return profilePagingViewController
    }
}

// MARK: - AuthContextProvider
extension ProfileViewController: AuthContextProvider {
    var authContext: AuthContext { viewModel.authContext }
}

// MARK: - ProfileHeaderViewControllerDelegate
extension ProfileViewController: ProfileHeaderViewControllerDelegate {
    func profileHeaderViewController(
        _ profileHeaderViewController: ProfileHeaderViewController,
        profileHeaderView: ProfileHeaderView,
        relationshipButtonDidPressed button: ProfileRelationshipActionButton
    ) {
        if viewModel.me == viewModel.account {
            editProfile()
        } else {
            editRelationship()
        }
    }


    private func editProfile() {
        // do nothing when updating
        guard !viewModel.isUpdating else { return }

        let profileHeaderViewModel = profileHeaderViewController.viewModel
        guard let profileAboutViewModel = profilePagingViewController.viewModel.profileAboutViewController.viewModel else { return }

        let isEdited = profileHeaderViewModel.isEdited || profileAboutViewModel.isEdited

        if isEdited {
            // update profile when edited
            viewModel.isUpdating = true
            Task { @MainActor in
                do {
                    // TODO: handle error
                    let updatedAccount = try await viewModel.updateProfileInfo(
                        headerProfileInfo: profileHeaderViewModel.profileInfoEditing,
                        aboutProfileInfo: profileAboutViewModel.profileInfoEditing
                    ).value
                    self.viewModel.isEditing = false
                    self.viewModel.account = updatedAccount

                } catch {
                    let alertController = UIAlertController(
                        for: error,
                        title: L10n.Common.Alerts.EditProfileFailure.title,
                        preferredStyle: .alert
                    )
                    let okAction = UIAlertAction(title: L10n.Common.Controls.Actions.ok, style: .default)
                    alertController.addAction(okAction)
                    self.present(alertController, animated: true)
                }

                // finish updating
                self.viewModel.isUpdating = false
            }
        } else {
            // set `updating` then toggle `edit` state
            viewModel.isUpdating = true
            viewModel.fetchEditProfileInfo()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] completion in
                    guard let self = self else { return }
                    defer {
                        // finish updating
                        self.viewModel.isUpdating = false
                    }
                    switch completion {
                        case .failure(let error):
                            let alertController = UIAlertController(for: error, title: L10n.Common.Alerts.EditProfileFailure.title, preferredStyle: .alert)
                            let okAction = UIAlertAction(title: L10n.Common.Controls.Actions.ok, style: .default)
                            alertController.addAction(okAction)
                            _ = self.coordinator.present(
                                scene: .alertController(alertController: alertController),
                                from: nil,
                                transition: .alertController(animated: true, completion: nil)
                            )
                        case .finished:
                            // enter editing mode
                            self.viewModel.isEditing.toggle()
                    }
                } receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    self.viewModel.accountForEdit = response.value
                }
                .store(in: &disposeBag)
        }
    }

    private func editRelationship() {
        guard let relationship = viewModel.relationship else { return }

        let account = viewModel.account

        viewModel.isUpdating = true

        if relationship.blocking {
            let name = account.displayNameWithFallback

            let alertController = UIAlertController(
                title: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnblockUser.title,
                message: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnblockUser.message(name),
                preferredStyle: .alert
            )
            let unblockAction = UIAlertAction(title: L10n.Common.Controls.Friendship.unblock, style: .default) { [weak self] _ in
                guard let self else { return }
                Task {
                    _ = try await DataSourceFacade.responseToUserBlockAction(
                        dependency: self,
                        account: account
                    )
                }
            }
            alertController.addAction(unblockAction)
            let cancelAction = UIAlertAction(title: L10n.Common.Controls.Actions.cancel, style: .cancel)
            alertController.addAction(cancelAction)
            coordinator.present(scene: .alertController(alertController: alertController), transition: .alertController(animated: true))
        } else if relationship.domainBlocking {
            guard let domain = account.domain else { return }

            let alertController = UIAlertController(
                title: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnblockDomain.title,
                message: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnblockDomain.message(domain),
                preferredStyle: .alert
            )

            let unblockAction = UIAlertAction(title: L10n.Common.Controls.Actions.unblockDomain(domain), style: .default) { [weak self] _ in
                guard let self else { return }
                Task {
                    _ = try await DataSourceFacade.responseToDomainBlockAction(dependency: self, account: account)

                    guard let newRelationship = try await self.context.apiService.relationship(forAccounts: [account], authenticationBox: self.authContext.mastodonAuthenticationBox).value.first else { return }

                    self.viewModel.isUpdating = false

                    // we need to trigger this here as domain block doesn't return a relationship
                    let userInfo = [
                        UserInfoKey.relationship: newRelationship,
                    ]

                    NotificationCenter.default.post(name: .relationshipChanged, object: self, userInfo: userInfo)
                }
            }
            alertController.addAction(unblockAction)
            let cancelAction = UIAlertAction(title: L10n.Common.Controls.Actions.cancel, style: .cancel)
            alertController.addAction(cancelAction)
            coordinator.present(scene: .alertController(alertController: alertController), transition: .alertController(animated: true))

        } else if relationship.muting {
            let name = account.displayNameWithFallback

            let alertController = UIAlertController(
                title: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnmuteUser.title,
                message: L10n.Scene.Profile.RelationshipActionAlert.ConfirmUnmuteUser.message(name),
                preferredStyle: .alert
            )

            let unmuteAction = UIAlertAction(title: L10n.Common.Controls.Friendship.unmute, style: .default) { [weak self] _ in
                guard let self else { return }
                Task {
                    _ = try await DataSourceFacade.responseToUserMuteAction(dependency: self, account: account)
                }
            }
            alertController.addAction(unmuteAction)
            let cancelAction = UIAlertAction(title: L10n.Common.Controls.Actions.cancel, style: .cancel)
            alertController.addAction(cancelAction)
            coordinator.present(scene: .alertController(alertController: alertController), transition: .alertController(animated: true))
        } else {
            Task { [weak self] in
                guard let self else { return }

                _ = try await DataSourceFacade.responseToUserFollowAction(
                    dependency: self,
                    account: viewModel.account
                )
            }
        }
    }

    func profileHeaderViewController(
        _ profileHeaderViewController: ProfileHeaderViewController,
        profileHeaderView: ProfileHeaderView,
        metaTextView: MetaTextView,
        metaDidPressed meta: Meta
    ) {
        handleMetaPress(meta)
    }
}

// MARK: - ProfileAboutViewControllerDelegate
extension ProfileViewController: ProfileAboutViewControllerDelegate {
    func profileAboutViewController(
        _ viewController: ProfileAboutViewController,
        profileFieldCollectionViewCell: ProfileFieldCollectionViewCell,
        metaLabel: MetaLabel,
        didSelectMeta meta: Meta
    ) {
        handleMetaPress(meta)
    }
}

// MARK: - MastodonMenuDelegate
extension ProfileViewController: MastodonMenuDelegate {
    func menuAction(_ action: MastodonMenu.Action) {
        switch action {
            case .muteUser(_),
                    .blockUser(_),
                    .blockDomain(_),
                    .hideReblogs(_):
                Task {
                    try await DataSourceFacade.responseToMenuAction(
                        dependency: self,
                        action: action,
                        menuContext: DataSourceFacade.MenuContext(
                            author: viewModel.account,
                            statusViewModel: nil,
                            button: nil,
                            barButtonItem: self.moreMenuBarButtonItem
                        ))
                }
            case .reportUser(_), .shareUser(_):
                Task {
                    try await DataSourceFacade.responseToMenuAction(
                        dependency: self,
                        action: action,
                        menuContext: DataSourceFacade.MenuContext(
                            author: viewModel.account,
                            statusViewModel: nil,
                            button: nil,
                            barButtonItem: self.moreMenuBarButtonItem
                        ))
                }

            case .translateStatus(_),
                    .showOriginal,
                    .bookmarkStatus(_),
                    .shareStatus,
                    .deleteStatus,
                    .editStatus,
                    .followUser(_):
                break
        }
    }
}

// MARK: - ScrollViewContainer
extension ProfileViewController: ScrollViewContainer {
    var scrollView: UIScrollView {
        return tabBarPagerController.relayScrollView
    }
}

extension ProfileViewController {

    override var keyCommands: [UIKeyCommand]? {
        if !viewModel.isEditing {
            return pagerTabStripNavigateKeyCommands
        }

        return nil
    }

}

// MARK: - PagerTabStripNavigateable
extension ProfileViewController: PagerTabStripNavigateable {

    var navigateablePageViewController: PagerTabStripViewController {
        return profilePagingViewController
    }

    @objc func pagerTabStripNavigateKeyCommandHandlerRelay(_ sender: UIKeyCommand) {
        pagerTabStripNavigateKeyCommandHandler(sender)
    }

}

private extension ProfileViewController {
    var currentInstance: Instance? {
        authContext.mastodonAuthenticationBox.authentication.instance(in: context.managedObjectContext)
    }
}

extension ProfileViewController: DataSourceProvider {
    func item(from source: DataSourceItem.Source) async -> DataSourceItem? {
        assertionFailure("Not required")
        return nil
    }
    
    func update(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
        updateViewModelsWithDataControllers(status: status, intent: intent)
    }
    
    func updateViewModelsWithDataControllers(status: MastodonStatus, intent: MastodonStatus.UpdateIntent) {
        viewModel.postsUserTimelineViewModel.dataController.update(status: status, intent: intent)
        viewModel.repliesUserTimelineViewModel.dataController.update(status: status, intent: intent)
        viewModel.mediaUserTimelineViewModel.dataController.update(status: status, intent: intent)
    }
}

//MARK: - Notifications

extension ProfileViewController {
    @objc
    func relationshipChanged(_ notification: Notification) {

        guard let userInfo = notification.userInfo, let relationship = userInfo[UserInfoKey.relationship] as? Mastodon.Entity.Relationship else {
            return
        }

        viewModel.isUpdating = true
        if viewModel.account.id == relationship.id {
            // if relationship belongs to an other account
            Task {
                let account = viewModel.account
                if let domain = account.domain,
                   let updatedAccount = try? await context.apiService.fetchUser(username: account.acct, domain: domain, authenticationBox: authContext.mastodonAuthenticationBox) {
                    viewModel.account = updatedAccount

                    viewModel.relationship = relationship
                    self.profileHeaderViewController.viewModel.relationship = relationship
                    self.profileHeaderViewController.profileHeaderView.viewModel.relationship = relationship
                }

                viewModel.isUpdating = false
            }
        } else if viewModel.account == viewModel.me {
            // update my profile
            Task {
                if let updatedMe = try? await context.apiService.authenticatedUserInfo(authenticationBox: authContext.mastodonAuthenticationBox).value {
                    viewModel.me = updatedMe
                    viewModel.account = updatedMe
                    FileManager.default.store(account: updatedMe, forUserID: authContext.mastodonAuthenticationBox.authentication.userIdentifier())
                }

                viewModel.isUpdating = false
            }
        }
    }
}
