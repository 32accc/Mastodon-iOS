//
//  NotificationTimelineViewController.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-21.
//

import os.log
import UIKit
import Combine
import CoreDataStack
import MastodonCore
import MastodonLocalization

final class NotificationTimelineViewController: UIViewController, NeedsDependency, MediaPreviewableViewController {
    
    let logger = Logger(subsystem: "NotificationTimelineViewController", category: "ViewController")
    
    weak var context: AppContext! { willSet { precondition(!isViewLoaded) } }
    weak var coordinator: SceneCoordinator! { willSet { precondition(!isViewLoaded) } }
    
    let mediaPreviewTransitionController = MediaPreviewTransitionController()

    var disposeBag = Set<AnyCancellable>()
    var observations = Set<NSKeyValueObservation>()

    var viewModel: NotificationTimelineViewModel!
    
    private(set) lazy var refreshControl: RefreshControl = {
        let refreshControl = RefreshControl()
        refreshControl.addTarget(self, action: #selector(NotificationTimelineViewController.refreshControlValueChanged(_:)), for: .valueChanged)
        return refreshControl
    }()
    
    private(set) lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        return tableView
    }()
    
    let cellFrameCache = NSCache<NSNumber, NSValue>()

    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension NotificationTimelineViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.pinToParent()
        
        tableView.delegate = self
        viewModel.setupDiffableDataSource(
            tableView: tableView,
            notificationTableViewCellDelegate: self
        )
        
        // setup batch fetch
        viewModel.listBatchFetchViewModel.setup(scrollView: tableView)
        viewModel.listBatchFetchViewModel.shouldFetch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.viewModel.loadOldestStateMachine.enter(NotificationTimelineViewModel.LoadOldestState.Loading.self)
            }
            .store(in: &disposeBag)
        
        // setup refresh control
        tableView.refreshControl = refreshControl
        viewModel.didLoadLatest
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self = self else { return }
                UIView.animate(withDuration: 0.5) { [weak self] in
                    guard let self = self else { return }
                    self.refreshControl.endRefreshing()
                }
            }
            .store(in: &disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshControl.endRefreshing()
        tableView.deselectRow(with: transitionCoordinator, animated: animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !viewModel.isLoadingLatest {
            let now = Date()
            if let timestamp = viewModel.lastAutomaticFetchTimestamp {
                if now.timeIntervalSince(timestamp) > 60 {
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): auto fetch latest timeline…")
                    Task {
                        await viewModel.loadLatest()
                    }
                    viewModel.lastAutomaticFetchTimestamp = now
                } else {
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): auto fetch latest timeline skip. Reason: updated in recent 60s")
                }
            } else {
                Task {
                    await viewModel.loadLatest()
                }
                viewModel.lastAutomaticFetchTimestamp = now
            }
        }
    }
    
}

// MARK: - CellFrameCacheContainer
extension NotificationTimelineViewController: CellFrameCacheContainer {
    func keyForCache(tableView: UITableView, indexPath: IndexPath) -> NSNumber? {
        guard let diffableDataSource = viewModel.diffableDataSource else { return nil }
        guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }
        let key = NSNumber(value: item.hashValue)
        return key
    }
}

extension NotificationTimelineViewController {

    @objc private func refreshControlValueChanged(_ sender: RefreshControl) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")
        
        Task {
            await viewModel.loadLatest()
        }
    }

}

// MARK: - AuthContextProvider
extension NotificationTimelineViewController: AuthContextProvider {
    var authContext: AuthContext { viewModel.authContext }
}

// MARK: - UITableViewDelegate
extension NotificationTimelineViewController: UITableViewDelegate, AutoGenerateTableViewDelegate {
    // sourcery:inline:NotificationTimelineViewController.AutoGenerateTableViewDelegate

    // Generated using Sourcery
    // DO NOT EDIT
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        aspectTableView(tableView, didSelectRowAt: indexPath)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return aspectTableView(tableView, contextMenuConfigurationForRowAt: indexPath, point: point)
    }

    func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return aspectTableView(tableView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }

    func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        return aspectTableView(tableView, previewForDismissingContextMenuWithConfiguration: configuration)
    }

    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        aspectTableView(tableView, willPerformPreviewActionForMenuWith: configuration, animator: animator)
    }

    // sourcery:end
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let frame = retrieveCellFrame(tableView: tableView, indexPath: indexPath) else {
            return 300
        }
        return ceil(frame.height)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let item = viewModel.diffableDataSource?.itemIdentifier(for: indexPath) else {
            return
        }
        
        // check item type inside `loadMore`
        Task {
            await viewModel.loadMore(item: item)
        }
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cacheCellFrame(tableView: tableView, didEndDisplaying: cell, forRowAt: indexPath)
    }
    
}

// MARK: - NotificationTableViewCellDelegate
extension NotificationTimelineViewController: NotificationTableViewCellDelegate { }

// MARK: - ScrollViewContainer
extension NotificationTimelineViewController: ScrollViewContainer {
    var scrollView: UIScrollView { tableView }
}

extension NotificationTimelineViewController {
    override var keyCommands: [UIKeyCommand]? {
        return navigationKeyCommands
    }
}

extension NotificationTimelineViewController: TableViewControllerNavigateable {
    
    func navigate(direction: TableViewNavigationDirection) {
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            // navigate up/down on the current selected item
            navigateToStatus(direction: direction, indexPath: indexPathForSelectedRow)
        } else {
            // set first visible item selected
            navigateToFirstVisibleStatus()
        }
    }
    
    private func navigateToStatus(direction: TableViewNavigationDirection, indexPath: IndexPath) {
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        let items = diffableDataSource.snapshot().itemIdentifiers
        guard let selectedItem = diffableDataSource.itemIdentifier(for: indexPath),
              let selectedItemIndex = items.firstIndex(of: selectedItem) else {
            return
        }

        let _navigateToItem: NotificationItem? = {
            var index = selectedItemIndex
            while 0..<items.count ~= index {
                index = {
                    switch direction {
                    case .up:   return index - 1
                    case .down: return index + 1
                    }
                }()
                guard 0..<items.count ~= index else { return nil }
                let item = items[index]
                
                guard Self.validNavigateableItem(item) else { continue }
                return item
            }
            return nil
        }()
        
        guard let item = _navigateToItem, let indexPath = diffableDataSource.indexPath(for: item) else { return }
        let scrollPosition: UITableView.ScrollPosition = overrideNavigationScrollPosition ?? Self.navigateScrollPosition(tableView: tableView, indexPath: indexPath)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: scrollPosition)
    }
    
    private func navigateToFirstVisibleStatus() {
        guard let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows else { return }
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        
        var visibleItems: [NotificationItem] = indexPathsForVisibleRows.sorted().compactMap { indexPath in
            guard let item = diffableDataSource.itemIdentifier(for: indexPath) else { return nil }
            guard Self.validNavigateableItem(item) else { return nil }
            return item
        }
        if indexPathsForVisibleRows.first?.row != 0, visibleItems.count > 1 {
            // drop first when visible not the first cell of table
            visibleItems.removeFirst()
        }
        guard let item = visibleItems.first, let indexPath = diffableDataSource.indexPath(for: item) else { return }
        let scrollPosition: UITableView.ScrollPosition = overrideNavigationScrollPosition ?? Self.navigateScrollPosition(tableView: tableView, indexPath: indexPath)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: scrollPosition)
    }
    
    static func validNavigateableItem(_ item: NotificationItem) -> Bool {
        switch item {
        case .feed:
            return true
        default:
            return false
        }
    }
    
    func open() {
        guard let indexPathForSelectedRow = tableView.indexPathForSelectedRow else { return }
        guard let diffableDataSource = viewModel.diffableDataSource else { return }
        guard let item = diffableDataSource.itemIdentifier(for: indexPathForSelectedRow) else { return }
        
        Task { @MainActor in
            switch item {
            case .feed(let record):
                guard let feed = record.object(in: self.context.managedObjectContext) else { return }
                guard let notification = feed.notification else { return }
                
                if let stauts = notification.status {
                    let threadViewModel = ThreadViewModel(
                        context: self.context,
                        authContext: self.viewModel.authContext,
                        optionalRoot: .root(context: .init(status: .init(objectID: stauts.objectID)))
                    )
                    _ = self.coordinator.present(
                        scene: .thread(viewModel: threadViewModel),
                        from: self,
                        transition: .show
                    )
                } else {
                    let profileViewModel = ProfileViewModel(
                        context: self.context,
                        authContext: self.viewModel.authContext,
                        optionalMastodonUser: notification.account
                    )
                    _ = self.coordinator.present(
                        scene: .profile(viewModel: profileViewModel),
                        from: self,
                        transition: .show
                    )
                }
            default:
                break
            }
        }   // end Task
    }
    
    func navigateKeyCommandHandlerRelay(_ sender: UIKeyCommand) {
        navigateKeyCommandHandler(sender)
    }

}
