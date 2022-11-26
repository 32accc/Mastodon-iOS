//
//  DataSourceProvider+UITableViewDelegate.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-17.
//

import os.log
import UIKit
import CoreDataStack
import MastodonCore
import MastodonUI
import MastodonLocalization

extension UITableViewDelegate where Self: DataSourceProvider & AuthContextProvider {

    func aspectTableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): indexPath: \(indexPath.debugDescription)")
        Task {
            let source = DataSourceItem.Source(tableViewCell: nil, indexPath: indexPath)
            guard let item = await item(from: source) else {
                return
            }
            switch item {
            case .status(let status):
                await DataSourceFacade.coordinateToStatusThreadScene(
                    provider: self,
                    target: .status,    // remove reblog wrapper
                    status: status
                )
            case .user(let user):
                await DataSourceFacade.coordinateToProfileScene(
                    provider: self,
                    user: user
                )
            case .hashtag(let tag):
                await DataSourceFacade.coordinateToHashtagScene(
                    provider: self,
                    tag: tag
                )
            case .notification(let notification):
                let managedObjectContext = context.managedObjectContext
                
                let _status: ManagedObjectRecord<Status>? = try await managedObjectContext.perform {
                    guard let notification = notification.object(in: managedObjectContext) else { return nil }
                    guard let status = notification.status else { return nil }
                    return .init(objectID: status.objectID)
                }
                if let status = _status {
                    await DataSourceFacade.coordinateToStatusThreadScene(
                        provider: self,
                        target: .status,        // remove reblog wrapper
                        status: status
                    )
                } else {
                    let _author: ManagedObjectRecord<MastodonUser>? = try await managedObjectContext.perform {
                        guard let notification = notification.object(in: managedObjectContext) else { return nil }
                        return .init(objectID: notification.account.objectID)
                    }
                    if let author = _author {
                        await DataSourceFacade.coordinateToProfileScene(
                            provider: self,
                            user: author
                        )
                    }
                }
            }
        }   // end Task
    }   // end func
    
}

extension UITableViewDelegate where Self: DataSourceProvider & MediaPreviewableViewController {

    func aspectTableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt
        indexPath: IndexPath, point: CGPoint
    ) -> UIContextMenuConfiguration? {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")

        guard let cell = tableView.cellForRow(at: indexPath) as? StatusViewContainerTableViewCell else { return nil }

        let mediaViews = cell.statusView.mediaGridContainerView.mediaViews
        
//        if cell.statusView.mediaGridContainerView.viewModel.isContentWarningOverlayDisplay == true {
//           return nil
//        }
        
        for (i, mediaView) in mediaViews.enumerated() {
            let pointInMediaView = mediaView.convert(point, from: tableView)
            guard mediaView.point(inside: pointInMediaView, with: nil) else {
                continue
            }
            guard let image = mediaView.thumbnail(),
                  let assetURLString = mediaView.configuration?.assetURL,
                  let assetURL = URL(string: assetURLString),
                  let _ = mediaView.configuration?.resourceType
            else {
                // not provide preview unless thumbnail ready
                return nil
            }
            
            let contextMenuImagePreviewViewModel = ContextMenuImagePreviewViewModel(
                assetURL: assetURL,
                thumbnail: image,
                aspectRatio: image.size
            )
            
            let configuration = TimelineTableViewCellContextMenuConfiguration(identifier: nil) { () -> UIViewController? in
                if UIDevice.current.userInterfaceIdiom == .pad && mediaViews.count == 1 {
                    return nil
                }
                let previewProvider = ContextMenuImagePreviewViewController()
                previewProvider.viewModel = contextMenuImagePreviewViewModel
                return previewProvider
                
            } actionProvider: { _ -> UIMenu? in
                return UIMenu(
                    title: "",
                    image: nil,
                    identifier: nil,
                    options: [],
                    children: [
                        UIAction(
                            title: L10n.Common.Controls.Actions.savePhoto,
                            image: UIImage(systemName: "square.and.arrow.down"),
                            attributes: [],
                            state: .off
                        ) { [weak self] _ in
                            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: save photo", ((#file as NSString).lastPathComponent), #line, #function)
                            guard let self = self else { return }
                            Task { @MainActor in
                                do {
                                    try await self.context.photoLibraryService.save(
                                        imageSource: .url(assetURL)
                                    ).singleOutput()
                                } catch {
                                    guard let error = error as? PhotoLibraryService.PhotoLibraryError,
                                          case .noPermission = error
                                    else { return }
                                    let alertController = SettingService.openSettingsAlertController(
                                        title: L10n.Common.Alerts.SavePhotoFailure.title,
                                        message: L10n.Common.Alerts.SavePhotoFailure.message
                                    )
                                    _ = self.coordinator.present(
                                        scene: .alertController(alertController: alertController),
                                        from: self,
                                        transition: .alertController(animated: true, completion: nil)
                                    )
                                }
                            }   // end Task
                        },
                        UIAction(
                            title: L10n.Common.Controls.Actions.copyPhoto,
                            image: UIImage(systemName: "doc.on.doc"),
                            identifier: nil,
                            discoverabilityTitle: nil,
                            attributes: [],
                            state: .off
                        ) { [weak self] _ in
                            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: copy photo", ((#file as NSString).lastPathComponent), #line, #function)
                            guard let self = self else { return }
                            Task {
                                try await self.context.photoLibraryService.copy(
                                    imageSource: .url(assetURL)
                                ).singleOutput()
                            }
                        },
                        UIAction(
                            title: L10n.Common.Controls.Actions.share,
                            image: UIImage(systemName: "square.and.arrow.up")!,
                            identifier: nil,
                            discoverabilityTitle: nil,
                            attributes: [],
                            state: .off
                        ) { [weak self] _ in
                            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: share", ((#file as NSString).lastPathComponent), #line, #function)
                            guard let self = self else { return }
                            Task {
                                let applicationActivities: [UIActivity] = [
                                    SafariActivity(sceneCoordinator: self.coordinator)
                                ]
                                let activityViewController = UIActivityViewController(
                                    activityItems: [assetURL],
                                    applicationActivities: applicationActivities
                                )
                                activityViewController.popoverPresentationController?.sourceView = mediaView
                                self.present(activityViewController, animated: true, completion: nil)
                            }
                        }
                    ]
                )
            }
            configuration.indexPath = indexPath
            configuration.index = i
            return configuration
        }   // end for … in …
                
        return nil
    }
    
    func aspectTableView(
        _ tableView: UITableView,
        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        return aspectTableView(tableView, configuration: configuration)
    }

    func aspectTableView(
        _ tableView: UITableView,
        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        return aspectTableView(tableView, configuration: configuration)
    }
    
    private func aspectTableView(
        _ tableView: UITableView,
        configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        guard let configuration = configuration as? TimelineTableViewCellContextMenuConfiguration else { return nil }
        guard let indexPath = configuration.indexPath, let index = configuration.index else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? StatusViewContainerTableViewCell {
            let mediaViews = cell.statusView.mediaGridContainerView.mediaViews
            guard index < mediaViews.count else { return nil }
            let mediaView = mediaViews[index]
            let parameters = UIPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: mediaView.bounds, cornerRadius: MediaView.cornerRadius)
            return UITargetedPreview(view: mediaView, parameters: parameters)
        } else {
            return nil
        }
    }

    func aspectTableView(
        _ tableView: UITableView,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public)")

        guard let configuration = configuration as? TimelineTableViewCellContextMenuConfiguration else { return }
        guard let indexPath = configuration.indexPath, let index = configuration.index else { return }
        guard let cell = tableView.cellForRow(at: indexPath) as? StatusViewContainerTableViewCell else { return }
        let mediaGridContainerView = cell.statusView.mediaGridContainerView
        let mediaViews = mediaGridContainerView.mediaViews
        guard index < mediaViews.count else { return }
        let mediaView = mediaViews[index]
        
        animator.addCompletion {
            Task { [weak self] in
                guard let self = self else { return }
                let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
                guard let item = await self.item(from: source) else {
                    assertionFailure()
                    return
                }
                guard case let .status(status) = item else {
                    assertionFailure("only works for status data provider")
                    return
                }
                try await DataSourceFacade.coordinateToMediaPreviewScene(
                    dependency: self,
                    status: status,
                    previewContext: DataSourceFacade.AttachmentPreviewContext(
                        containerView: .mediaGridContainerView(mediaGridContainerView),
                        mediaView: mediaView,
                        index: index
                    )
                )
            }   // end Task
        }   // end animator.addCompletion { … }

    }
}
