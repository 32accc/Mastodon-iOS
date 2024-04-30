//
//  MastodonLoginViewController.swift
//  Mastodon
//
//  Created by Nathan Mattes on 09.11.22.
//

import UIKit
import MastodonSDK
import MastodonCore
import MastodonAsset
import Combine
import AuthenticationServices
import MastodonLocalization

protocol MastodonLoginViewControllerDelegate: AnyObject {
    func backButtonPressed(_ viewController: MastodonLoginViewController)
}

enum MastodonLoginViewSection: Hashable {
    case servers
}

class MastodonLoginViewController: UIViewController, NeedsDependency {
    
    enum RightBarButtonState {
        case normal, disabled, loading
    }
    
    weak var delegate: MastodonLoginViewControllerDelegate?
    var dataSource: UITableViewDiffableDataSource<MastodonLoginViewSection, Mastodon.Entity.Server>?
    let viewModel: MastodonLoginViewModel
    let authenticationViewModel: AuthenticationViewModel
    var mastodonAuthenticationController: MastodonAuthenticationController?
    
    weak var context: AppContext!
    weak var coordinator: SceneCoordinator!
    
    var disposeBag = Set<AnyCancellable>()
    
    var contentView: MastodonLoginView {
        view as! MastodonLoginView
    }
    
    init(appContext: AppContext, authenticationViewModel: AuthenticationViewModel, sceneCoordinator: SceneCoordinator) {
        
        viewModel = MastodonLoginViewModel(appContext: appContext)
        self.authenticationViewModel = authenticationViewModel
        self.context = appContext
        self.coordinator = sceneCoordinator
        
        super.init(nibName: nil, bundle: nil)
        viewModel.delegate = self
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func loadView() {
        let loginView = MastodonLoginView()
        
        navigationItem.leftBarButtonItem?.target = self
        navigationItem.leftBarButtonItem?.action = #selector(backButtonPressed(_:))
        
        loginView.searchTextField.addTarget(self, action: #selector(MastodonLoginViewController.textfieldDidChange(_:)), for: .editingChanged)
        loginView.tableView.delegate = self
        loginView.tableView.register(MastodonLoginServerTableViewCell.self, forCellReuseIdentifier: MastodonLoginServerTableViewCell.reuseIdentifier)

        view = loginView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowNotification(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHideNotification(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let dataSource = UITableViewDiffableDataSource<MastodonLoginViewSection, Mastodon.Entity.Server>(tableView: contentView.tableView) { [weak self] tableView, indexPath, itemIdentifier in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MastodonLoginServerTableViewCell.reuseIdentifier, for: indexPath) as? MastodonLoginServerTableViewCell,
                  let self else {
                fatalError("Wrong cell")
            }
            
            let server = self.viewModel.filteredServers[indexPath.row]
            var configuration = cell.defaultContentConfiguration()
            configuration.text = server.domain
            configuration.textProperties.color = Asset.Colors.Brand.blurple.color

            cell.contentConfiguration = configuration
            cell.backgroundColor = Asset.Scene.Onboarding.textFieldBackground.color
            
            return cell
        }
        
        contentView.tableView.dataSource = dataSource
        self.dataSource = dataSource
        
        contentView.updateCorners()
        
        defer { setupNavigationBarBackgroundView() }
        setupOnboardingAppearance()
        
        title = L10n.Scene.Login.title
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel.updateServers()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        contentView.searchTextField.becomeFirstResponder()
    }
    
    //MARK: - Actions
    
    @objc func backButtonPressed(_ sender: Any) {
        contentView.searchTextField.resignFirstResponder()
        delegate?.backButtonPressed(self)
    }
    
    func login(on server: Mastodon.Entity.Server) {
        authenticationViewModel
            .authenticated.sink { (domain, account) in
                Task { @MainActor in
                    do {
                        _ = try await self.context.authenticationService.activeMastodonUser(domain: domain, userID: account.id)
                        FileManager.default.store(account: account, forUserID: MastodonUserIdentifier(domain: domain, userID: account.id))

                        self.coordinator.setup()
                    } catch {
                        assertionFailure(error.localizedDescription)
                    }
                }
            }
            .store(in: &disposeBag)

        authenticationViewModel.isAuthenticating.send(true)
        context.apiService.createApplication(domain: server.domain)
            .tryMap { response -> AuthenticationViewModel.AuthenticateInfo in
                let application = response.value
                guard let info = AuthenticationViewModel.AuthenticateInfo(
                    domain: server.domain,
                    application: application,
                    redirectURI: response.value.redirectURI ?? APIService.oauthCallbackURL
                ) else {
                    throw APIService.APIError.explicit(.badResponse)
                }
                return info
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self = self else { return }
                self.authenticationViewModel.isAuthenticating.send(false)
                
                switch completion {
                case .failure(let error):
                    let alert = UIAlertController.standardAlert(of: error)
                    self.present(alert, animated: true)
                case .finished:
                    break
                }
            } receiveValue: { [weak self] info in
                guard let self else { return }
                let authenticationController = MastodonAuthenticationController(
                    context: self.context,
                    authenticateURL: info.authorizeURL
                )
                
                self.mastodonAuthenticationController = authenticationController
                authenticationController.authenticationSession?.presentationContextProvider = self
                authenticationController.authenticationSession?.start()
                
                self.authenticationViewModel.authenticate(
                    info: info,
                    pinCodePublisher: authenticationController.pinCodePublisher
                )
            }
            .store(in: &disposeBag)
    }
    
    @objc func textfieldDidChange(_ textField: UITextField) {
        viewModel.filterServers(withText: textField.text)

        if let text = textField.text,
           let domain = AuthenticationViewModel.parseDomain(from: text) {
            let selectedServer = Mastodon.Entity.Server(domain: domain, instance: .init(domain: domain))
            if viewModel.filteredServers.contains(where: { $0 == selectedServer }) == false {
                viewModel.filteredServers.insert(selectedServer, at: 0)
            }
        }

        serversUpdated(viewModel)
    }
    
    // MARK: - Notifications
    @objc func keyboardWillShowNotification(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
        else { return }
        
        // inspired by https://stackoverflow.com/a/30245044
        UIView.animate(withDuration: duration.doubleValue, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHideNotification(_ notification: Notification) {
        
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
        else { return }
        
        UIView.animate(withDuration: duration.doubleValue, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - OnboardingViewControllerAppearance
extension MastodonLoginViewController: OnboardingViewControllerAppearance { }

// MARK: - UITableViewDelegate
extension MastodonLoginViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let selectedServer = viewModel.filteredServers[indexPath.row]
        login(on: selectedServer)
    }
}

// MARK: - MastodonLoginViewModelDelegate
extension MastodonLoginViewController: MastodonLoginViewModelDelegate {
    func serversUpdated(_ viewModel: MastodonLoginViewModel) {
        var snapshot = NSDiffableDataSourceSnapshot<MastodonLoginViewSection, Mastodon.Entity.Server>()
        
        snapshot.appendSections([MastodonLoginViewSection.servers])
        snapshot.appendItems(viewModel.filteredServers)

        DispatchQueue.main.async {
            self.dataSource?.apply(snapshot, animatingDifferences: false)
            let numberOfResults = viewModel.filteredServers.count
            self.contentView.updateCorners(numberOfResults: numberOfResults)
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension MastodonLoginViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}
