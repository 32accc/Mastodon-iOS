//
//  MastodonPickServerViewModel.swift
//  Mastodon
//
//  Created by BradGao on 2021/2/23.
//

import os.log
import UIKit
import Combine
import GameplayKit
import MastodonSDK
import CoreDataStack
import OrderedCollections
import Tabman
import MastodonCore
import MastodonUI
import MastodonLocalization

class MastodonPickServerViewModel: NSObject {

    enum EmptyStateViewState {
        case none
        case loading
        case badNetwork
    }
    
    var disposeBag = Set<AnyCancellable>()
    
    let serverSectionHeaderView = PickServerServerSectionTableHeaderView()

    // input
    let context: AppContext
    var categoryPickerItems: [CategoryPickerItem] = {
        var items: [CategoryPickerItem] = []
        items.append(.language(language: nil))
        items.append(.signupSpeed(manuallyReviewed: nil))
        items.append(.all)
        items.append(contentsOf: APIService.stubCategories().map { CategoryPickerItem.category(category: $0) })
        return items
    }()
    let selectCategoryItem = CurrentValueSubject<CategoryPickerItem, Never>(.all)
    let searchText = CurrentValueSubject<String, Never>("")
    let selectedLanguage = CurrentValueSubject<String?, Never>(nil)
    let manualApprovalRequired = CurrentValueSubject<Bool?, Never>(nil)
    let allLanguages = CurrentValueSubject<[Mastodon.Entity.Language], Never>([])
    let indexedServers = CurrentValueSubject<[Mastodon.Entity.Server], Never>([])
    let unindexedServers = CurrentValueSubject<[Mastodon.Entity.Server]?, Never>([])    // set nil when loading
    let viewWillAppear = PassthroughSubject<Void, Never>()
    let viewDidAppear = CurrentValueSubject<Void, Never>(Void())
    @Published var additionalTableViewInsets: UIEdgeInsets = .zero
    
    // output
    var diffableDataSource: UITableViewDiffableDataSource<PickServerSection, PickServerItem>?
    private(set) lazy var loadIndexedServerStateMachine: GKStateMachine = {
        // exclude timeline middle fetcher state
        let stateMachine = GKStateMachine(states: [
            LoadIndexedServerState.Initial(viewModel: self),
            LoadIndexedServerState.Loading(viewModel: self),
            LoadIndexedServerState.Fail(viewModel: self),
            LoadIndexedServerState.Idle(viewModel: self),
        ])
        stateMachine.enter(LoadIndexedServerState.Initial.self)
        return stateMachine
    }()
    let filteredIndexedServers = CurrentValueSubject<[Mastodon.Entity.Server], Never>([])
    let servers = CurrentValueSubject<[Mastodon.Entity.Server], Error>([])
    let selectedServer = CurrentValueSubject<Mastodon.Entity.Server?, Never>(nil)
    let error = CurrentValueSubject<Error?, Never>(nil)

    let isLoadingIndexedServers = CurrentValueSubject<Bool, Never>(false)
    let loadingIndexedServersError = CurrentValueSubject<Error?, Never>(nil)
    let emptyStateViewState = CurrentValueSubject<EmptyStateViewState, Never>(.none)
        
    init(context: AppContext) {
        self.context = context
        super.init()

        configure()
    }
    
    deinit {
        os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }
    
}

extension MastodonPickServerViewModel {
    
    private func configure() {

        context.apiService.languages().sink { completion in
            
        } receiveValue: { response in
            self.allLanguages.value = response.value
        }
        .store(in: &disposeBag)

        Publishers.CombineLatest(
            isLoadingIndexedServers,
            loadingIndexedServersError
        )
        .map { isLoadingIndexedServers, loadingIndexedServersError -> EmptyStateViewState in
            if isLoadingIndexedServers {
                if loadingIndexedServersError != nil {
                    return .badNetwork
                } else {
                    return .loading
                }
            } else {
                return .none
            }
        }
        .assign(to: \.value, on: emptyStateViewState)
        .store(in: &disposeBag)

        Publishers.CombineLatest4(
            indexedServers.eraseToAnyPublisher(),
            selectCategoryItem.eraseToAnyPublisher(),
            searchText.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main).removeDuplicates(),
            Publishers.CombineLatest(
                selectedLanguage.eraseToAnyPublisher(),
                manualApprovalRequired.eraseToAnyPublisher()
            ).map { selectedLanguage, manualApprovalRequired -> (selectedLanguage: String?, manualApprovalRequired: Bool?) in
                (selectedLanguage, manualApprovalRequired)
            }
        )
        .map { indexedServers, selectCategoryItem, searchText, filters -> [Mastodon.Entity.Server] in
            // ignore approval required servers when sign-up
            // Note:
            // sort by calculate last week users count
            // and make medium size (~800) server to top
            
            // group by language user preferred language first
            var languageToServersMapping = OrderedDictionary<String, [Mastodon.Entity.Server]>()
            for language in Locale.preferredLanguages {
                let local = Locale(identifier: language)
                guard let languageCode = local.languageCode else { continue }
                // skip if key duplicate
                guard !languageToServersMapping.keys.contains(languageCode) else { continue }
                // append to dict
                languageToServersMapping[languageCode] = indexedServers
                    .filter { $0.language.lowercased() == languageCode.lowercased() }
                    .sorted(by: { lh, rh in
                        let lhValue = abs(log2(800.0) - log2(Double(lh.lastWeekUsers)))
                        let rhValue = abs(log2(800.0) - log2(Double(rh.lastWeekUsers)))
                        return lhValue < rhValue
                    })
            }
            // sort remains servers
            let remainsServers = indexedServers
                .filter { server in
                    return !languageToServersMapping.contains { _, servers in servers.contains(server) }
                }
                .sorted(by: { lh, rh in
                    let lhValue = abs(log2(800.0) - log2(Double(lh.lastWeekUsers)))
                    let rhValue = abs(log2(800.0) - log2(Double(rh.lastWeekUsers)))
                    return lhValue < rhValue
                })
            
            var _indexedServers: [Mastodon.Entity.Server] = []
            for key in languageToServersMapping.keys {
                _indexedServers.append(contentsOf: languageToServersMapping[key] ?? [])
            }
            _indexedServers.append(contentsOf: remainsServers)
            
            if _indexedServers.count == indexedServers.count {
                indexedServers = _indexedServers
            } else {
                assertionFailure("should not change dataset size")
            }
            
            // Filter the indexed servers by category or search text
            switch selectCategoryItem {
            case .all:
                return MastodonPickServerViewModel.filterServers(servers: indexedServers, language: filters.selectedLanguage, manualApprovalRequired: filters.manualApprovalRequired, category: nil, searchText: searchText)
            case .language(_), .signupSpeed(_):
                return MastodonPickServerViewModel.filterServers(servers: indexedServers, language: filters.selectedLanguage, manualApprovalRequired: filters.manualApprovalRequired, category: nil, searchText: searchText)
            case .category(let category):
                return MastodonPickServerViewModel.filterServers(servers: indexedServers, language: filters.selectedLanguage, manualApprovalRequired: filters.manualApprovalRequired, category: category.category.rawValue, searchText: searchText)
            }
        }
        .assign(to: \.value, on: filteredIndexedServers)
        .store(in: &disposeBag)
        
        searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .compactMap { [weak self] searchText -> AnyPublisher<Result<Mastodon.Response.Content<[Mastodon.Entity.Server]>, Error>, Never>? in
                // Check if searchText is a valid mastodon server domain
                guard let self = self else { return nil }
                guard let domain = AuthenticationViewModel.parseDomain(from: searchText) else {
                    return Just(Result.failure(APIService.APIError.implicit(.badRequest))).eraseToAnyPublisher()
                }
                self.unindexedServers.value = nil
                return self.context.apiService.webFinger(domain: domain)
                    .flatMap { domain -> AnyPublisher<Result<Mastodon.Response.Content<[Mastodon.Entity.Server]>, Error>, Never> in
                        return self.context.apiService.instance(domain: domain)
                            .map { response -> Result<Mastodon.Response.Content<[Mastodon.Entity.Server]>, Error>in
                                let newResponse = response.map { [Mastodon.Entity.Server(domain: domain, instance: $0)] }
                                return Result.success(newResponse)
                            }
                            .catch { error in
                                return Just(Result.failure(error))
                            }
                            .eraseToAnyPublisher()
                    }
                    .catch { error in
                        return Just(Result.failure(error))
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink(receiveValue: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let response):
                    self.unindexedServers.send(response.value)
                case .failure(let error):
                    if let error = error as? APIService.APIError,
                       case let .implicit(reason) = error,
                       case .badRequest = reason {
                        self.unindexedServers.send([])
                    } else {
                        self.unindexedServers.send(nil)
                    }
                }
            })
            .store(in: &disposeBag)
    }

}

extension MastodonPickServerViewModel {
    private static func filterServers(servers: [Mastodon.Entity.Server], language: String? = nil, manualApprovalRequired: Bool? = nil, category: String?, searchText: String) -> [Mastodon.Entity.Server] {
        let filteredServers = servers
        // 1. Filter the category
            .filter {
                guard let category = category else  { return true }
                return $0.category.caseInsensitiveCompare(category) == .orderedSame
            }
        // 2. Filter the searchText
            .filter {
                let searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !searchText.isEmpty else {
                    return true
                }
                return $0.domain.lowercased().contains(searchText.lowercased())
            }
            .filter {
                guard let language else { return true }

                return $0.language.lowercased() == language.lowercased()
            }
            .filter {
                guard let manualApprovalRequired else { return true }

                print("\($0.domain) \($0.approvalRequired) < \(manualApprovalRequired)")
                return $0.approvalRequired == manualApprovalRequired
            }
        return filteredServers
    }
}

// MARK: - SignUp methods & structs
extension MastodonPickServerViewModel {
    struct SignUpResponseFirst {
        let instance: Mastodon.Response.Content<Mastodon.Entity.Instance>
        let application: Mastodon.Response.Content<Mastodon.Entity.Application>
    }
    
    struct SignUpResponseSecond {
        let instance: Mastodon.Response.Content<Mastodon.Entity.Instance>
        let authenticateInfo: AuthenticationViewModel.AuthenticateInfo
    }
    
    struct SignUpResponseThird {
        let instance: Mastodon.Response.Content<Mastodon.Entity.Instance>
        let authenticateInfo: AuthenticationViewModel.AuthenticateInfo
        let applicationToken: Mastodon.Response.Content<Mastodon.Entity.Token>
    }
}

// MARK: - TMBarDataSource
extension MastodonPickServerViewModel: TMBarDataSource {
    func barItem(for bar: TMBar, at index: Int) -> TMBarItemable {
        let item = categoryPickerItems[index]
        let barItem = TMBarItem(title: item.title)
        return barItem
    }
}

extension MastodonPickServerViewModel: PickServerCategoryCollectionViewCellDelegate {
    func didPressMenuButton(in cell: PickServerCategoryCollectionViewCell) {

        guard let item = cell.item else { return }

        switch item {
        case .all, .category(_):
            return
        case .language(_):
            guard allLanguages.value.isNotEmpty else { return }

            //FIXME: @zeitschlag localize
            let allLanguagesAction = UIAction(title: "All") { _ in
                self.selectedLanguage.value = nil
                cell.titleLabel.text = L10n.Scene.ServerPicker.Button.language
            }

            let languageActions = allLanguages.value.compactMap { language in
                UIAction(title: language.language ?? language.locale) { action in
                    self.selectedLanguage.value = language.locale
                    cell.titleLabel.text = language.language
                }
            }

            var allActions = [allLanguagesAction]
            allActions.append(contentsOf: languageActions)

            let languageMenu = UIMenu(title: L10n.Scene.ServerPicker.Button.language,
                                      children: allActions)

            cell.menuButton.menu = languageMenu

        case .signupSpeed(_):

            let doesntMatterAction = UIAction(title: L10n.Scene.ServerPicker.SignupSpeed.all) { _ in
                self.manualApprovalRequired.value = nil
                cell.titleLabel.text = L10n.Scene.ServerPicker.Button.signupSpeed
            }

            let manualApprovalAction = UIAction(title: L10n.Scene.ServerPicker.SignupSpeed.manuallyReviewed) { action in
                self.manualApprovalRequired.value = true
                cell.titleLabel.text = action.title
            }

            let instantSignupAction = UIAction(title: L10n.Scene.ServerPicker.SignupSpeed.instant) { action in
                self.manualApprovalRequired.value = false
                cell.titleLabel.text = action.title
            }

            let signupSpeedMenu = UIMenu(title: L10n.Scene.ServerPicker.Button.signupSpeed,
                                         children: [doesntMatterAction, manualApprovalAction, instantSignupAction])

            cell.menuButton.menu = signupSpeedMenu
        }
    }
}
