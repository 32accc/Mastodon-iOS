// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import CoreData
import CoreDataStack
import MastodonCore
import MastodonSDK

public final class MastodonEditStatusPublisher: NSObject, ProgressReporting {

    // Input
    public let statusID: Status.ID
    public let author: ManagedObjectRecord<MastodonUser>

    // content warning
    public let isContentWarningComposing: Bool
    public let contentWarning: String
    // status content
    public let content: String
    // media
    public let isMediaSensitive: Bool
    public let attachmentViewModels: [AttachmentViewModel]
    // poll
    public let isPollComposing: Bool
    public let pollOptions: [PollComposeItem.Option]
    public let pollExpireConfigurationOption: PollComposeItem.ExpireConfiguration.Option
    public let pollMultipleConfigurationOption: PollComposeItem.MultipleConfiguration.Option
    // visibility
    public let visibility: Mastodon.Entity.Status.Visibility
    // language
    public let language: String

    // Output
    let _progress = Progress()
    public var progress: Progress { _progress }
    @Published var _state: StatusPublisherState = .pending
    public var state: Published<StatusPublisherState>.Publisher { $_state }

    public var reactor: StatusPublisherReactor?

    public init(
        statusID: Status.ID,
        author: ManagedObjectRecord<MastodonUser>,
        isContentWarningComposing: Bool,
        contentWarning: String,
        content: String,
        isMediaSensitive: Bool,
        attachmentViewModels: [AttachmentViewModel],
        isPollComposing: Bool,
        pollOptions: [PollComposeItem.Option],
        pollExpireConfigurationOption: PollComposeItem.ExpireConfiguration.Option,
        pollMultipleConfigurationOption: PollComposeItem.MultipleConfiguration.Option,
        visibility: Mastodon.Entity.Status.Visibility,
        language: String
    ) {
        self.author = author
        self.statusID = statusID
        self.isContentWarningComposing = isContentWarningComposing
        self.contentWarning = contentWarning
        self.content = content
        self.isMediaSensitive = isMediaSensitive
        self.attachmentViewModels = attachmentViewModels
        self.isPollComposing = isPollComposing
        self.pollOptions = pollOptions
        self.pollExpireConfigurationOption = pollExpireConfigurationOption
        self.pollMultipleConfigurationOption = pollMultipleConfigurationOption
        self.visibility = visibility
        self.language = language
    }

}

// MARK: - StatusPublisher
extension MastodonEditStatusPublisher: StatusPublisher {

    public func publish(
        api: APIService,
        authContext: AuthContext
    ) async throws -> StatusPublishResult {
        let idempotencyKey = UUID().uuidString

        let publishStatusTaskStartDelayWeight: Int64 = 20
        let publishStatusTaskStartDelayCount: Int64 = publishStatusTaskStartDelayWeight

        let publishAttachmentTaskWeight: Int64 = 100
        let publishAttachmentTaskCount: Int64 = Int64(attachmentViewModels.count) * publishAttachmentTaskWeight

        let publishStatusTaskWeight: Int64 = 20
        let publishStatusTaskCount: Int64 = publishStatusTaskWeight

        let taskCount = [
            publishStatusTaskStartDelayCount,
            publishAttachmentTaskCount,
            publishStatusTaskCount
        ].reduce(0, +)
        progress.totalUnitCount = taskCount
        progress.completedUnitCount = 0

        // start delay
        try? await Task.sleep(nanoseconds: 1 * .second)
        progress.completedUnitCount += publishStatusTaskStartDelayWeight

        // Task: attachment

        var attachmentIDs: [Mastodon.Entity.Attachment.ID] = []
        for attachmentViewModel in attachmentViewModels {
            // set progress
            progress.addChild(attachmentViewModel.progress, withPendingUnitCount: publishAttachmentTaskWeight)
            // upload media
            do {
                switch attachmentViewModel.uploadResult {
                case .none:
                    // precondition: all media uploaded
                    throw AppError.badRequest
                case .exists:
                    guard case let AttachmentViewModel.Input.mastodonAssetUrl(_, attachmentId) = attachmentViewModel.input else {
                        throw AppError.badRequest
                    }
                    attachmentIDs.append(attachmentId)
                    break
                case let .uploadedMastodonAttachment(attachment):
                    attachmentIDs.append(attachment.id)

                    let caption = attachmentViewModel.caption
                    guard !caption.isEmpty else { continue }

                    _ = try await api.updateMedia(
                        domain: authContext.mastodonAuthenticationBox.domain,
                        attachmentID: attachment.id,
                        query: .init(
                            file: nil,
                            thumbnail: nil,
                            description: caption,
                            focus: nil
                        ),
                        mastodonAuthenticationBox: authContext.mastodonAuthenticationBox
                    ).singleOutput()

                    // TODO: allow background upload
                    // let attachment = try await attachmentViewModel.upload(context: uploadContext)
                    // let attachmentID = attachment.id
                    // attachmentIDs.append(attachmentID)
                }
            } catch {
                _state = .failure(error)
                throw error
            }
        }

        let pollOptions: [String]? = {
            guard self.isPollComposing else { return nil }
            let options = self.pollOptions.compactMap { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            return options.isEmpty ? nil : options
        }()
        let pollExpiresIn: Int? = {
            guard self.isPollComposing else { return nil }
            guard pollOptions != nil else { return nil }
            return self.pollExpireConfigurationOption.seconds
        }()

        let query = Mastodon.API.Statuses.EditStatusQuery(
            status: content,
            mediaIDs: attachmentIDs.isEmpty ? nil : attachmentIDs,
            pollOptions: pollOptions,
            pollExpiresIn: pollExpiresIn,
            pollMultipleAnswers: pollMultipleConfigurationOption,
            sensitive: isMediaSensitive,
            spoilerText: isContentWarningComposing ? contentWarning : nil,
            visibility: visibility,
            language: language
        )

        let editStatusResponse = try await api.publishStatusEdit(forStatusID: statusID,
                                                                 editStatusQuery: query,
                                                                 authenticationBox: authContext.mastodonAuthenticationBox)

        progress.completedUnitCount += publishStatusTaskCount
        _state = .success

        return .edit(editStatusResponse)
    }

}
