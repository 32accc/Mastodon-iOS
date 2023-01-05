//
//  MastodonLoginView.swift
//  Mastodon
//
//  Created by Nathan Mattes on 10.11.22.
//

import UIKit
import MastodonAsset
import MastodonLocalization

class MastodonLoginView: UIView {

  // List with (filtered) domains

  let titleLabel: UILabel
  let subtitleLabel: UILabel
  private let headerStackView: UIStackView

  let searchTextField: UITextField
  private let searchTextFieldLeftView: UIView
  private let searchTextFieldMagnifyingGlass: UIImageView
  private let searchContainerLeftPaddingView: UIView

  let tableView: UITableView
  let navigationActionView: NavigationActionView
  var bottomConstraint: NSLayoutConstraint?

  override init(frame: CGRect) {

    titleLabel = UILabel()
    titleLabel.font = MastodonLoginViewController.largeTitleFont
    titleLabel.textColor = MastodonLoginViewController.largeTitleTextColor
    titleLabel.text = L10n.Scene.Login.title
    titleLabel.numberOfLines = 0

    subtitleLabel = UILabel()
    subtitleLabel.font = MastodonLoginViewController.subTitleFont
    subtitleLabel.textColor = MastodonLoginViewController.subTitleTextColor
    subtitleLabel.text = L10n.Scene.Login.subtitle
    subtitleLabel.numberOfLines = 0

    headerStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    headerStackView.axis = .vertical
    headerStackView.spacing = 16
    headerStackView.translatesAutoresizingMaskIntoConstraints = false

    searchTextFieldMagnifyingGlass = UIImageView(image: UIImage(
      systemName: "magnifyingglass",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
    ))
    searchTextFieldMagnifyingGlass.tintColor = Asset.Colors.Label.secondary.color.withAlphaComponent(0.6)
    searchTextFieldMagnifyingGlass.translatesAutoresizingMaskIntoConstraints = false

    searchContainerLeftPaddingView = UIView()
    searchContainerLeftPaddingView.translatesAutoresizingMaskIntoConstraints = false

    searchTextFieldLeftView = UIView()
    searchTextFieldLeftView.addSubview(searchTextFieldMagnifyingGlass)
    searchTextFieldLeftView.addSubview(searchContainerLeftPaddingView)

    searchTextField = UITextField()
    searchTextField.translatesAutoresizingMaskIntoConstraints = false
    searchTextField.backgroundColor = Asset.Scene.Onboarding.searchBarBackground.color
    searchTextField.placeholder = L10n.Scene.Login.ServerSearchField.placeholder
    searchTextField.leftView = searchTextFieldLeftView
    searchTextField.leftViewMode = .always
    searchTextField.layer.cornerRadius = 10
    searchTextField.keyboardType = .URL
    searchTextField.autocorrectionType = .no
    searchTextField.autocapitalizationType = .none

    tableView = ContentSizedTableView()
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.backgroundColor = Asset.Scene.Onboarding.textFieldBackground.color
    tableView.keyboardDismissMode = .onDrag
    tableView.layer.cornerRadius = 10

    navigationActionView = NavigationActionView()
    navigationActionView.translatesAutoresizingMaskIntoConstraints = false

    super.init(frame: frame)

    addSubview(headerStackView)
    addSubview(searchTextField)
    addSubview(tableView)
    addSubview(navigationActionView)
    backgroundColor = Asset.Scene.Onboarding.background.color

    setupConstraints()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupConstraints() {

    let bottomConstraint = safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: navigationActionView.bottomAnchor)

    let constraints = [

      headerStackView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
      headerStackView.leadingAnchor.constraint(equalTo: readableContentGuide.leadingAnchor),
      headerStackView.trailingAnchor.constraint(equalTo: readableContentGuide.trailingAnchor),

      searchTextField.topAnchor.constraint(equalTo: headerStackView.bottomAnchor, constant: 32),
      searchTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      searchTextField.heightAnchor.constraint(equalToConstant: 55),
      trailingAnchor.constraint(equalTo: searchTextField.trailingAnchor, constant: 16),

      searchTextFieldMagnifyingGlass.topAnchor.constraint(equalTo: searchTextFieldLeftView.topAnchor),
      searchTextFieldMagnifyingGlass.leadingAnchor.constraint(equalTo: searchTextFieldLeftView.leadingAnchor, constant: 8),
      searchTextFieldMagnifyingGlass.bottomAnchor.constraint(equalTo: searchTextFieldLeftView.bottomAnchor),

      searchContainerLeftPaddingView.topAnchor.constraint(equalTo: searchTextFieldLeftView.topAnchor),
      searchContainerLeftPaddingView.leadingAnchor.constraint(equalTo: searchTextFieldMagnifyingGlass.trailingAnchor),
      searchContainerLeftPaddingView.trailingAnchor.constraint(equalTo: searchTextFieldLeftView.trailingAnchor),
      searchContainerLeftPaddingView.bottomAnchor.constraint(equalTo: searchTextFieldLeftView.bottomAnchor),
      searchContainerLeftPaddingView.widthAnchor.constraint(equalToConstant: 4).priority(.defaultHigh),

      tableView.topAnchor.constraint(equalTo: searchTextField.bottomAnchor, constant: 2),
      tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      trailingAnchor.constraint(equalTo: tableView.trailingAnchor, constant: 16),
      tableView.bottomAnchor.constraint(lessThanOrEqualTo: navigationActionView.topAnchor),

      navigationActionView.leadingAnchor.constraint(equalTo: leadingAnchor),
      navigationActionView.trailingAnchor.constraint(equalTo: trailingAnchor),
      bottomConstraint,
    ]

    self.bottomConstraint = bottomConstraint
    NSLayoutConstraint.activate(constraints)
  }

  func updateCorners(numberOfResults: Int = 0) {

    tableView.isHidden = (numberOfResults == 0)
    tableView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

    let maskedCorners: CACornerMask

    if numberOfResults == 0 {
      maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
    } else {
      maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    searchTextField.layer.maskedCorners = maskedCorners
  }
}
