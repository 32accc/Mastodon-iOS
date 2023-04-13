//
//  ComposeContentToolbarView.swift
//  
//
//  Created by MainasuK on 22/10/18.
//

import os.log
import SwiftUI
import MastodonAsset
import MastodonLocalization
import MastodonSDK

protocol ComposeContentToolbarViewDelegate: AnyObject {
    func composeContentToolbarView(_ viewModel: ComposeContentToolbarView.ViewModel, toolbarItemDidPressed action: ComposeContentToolbarView.ViewModel.Action)
    func composeContentToolbarView(_ viewModel: ComposeContentToolbarView.ViewModel, attachmentMenuDidPressed action: ComposeContentToolbarView.ViewModel.AttachmentAction)
}

struct ComposeContentToolbarView: View {
    
    static var toolbarHeight: CGFloat { 48 }
    
    @ObservedObject var viewModel: ViewModel
    let isZoomed = (UIScreen.main.scale != UIScreen.main.nativeScale)
    
    @State private var showingLanguagePicker = false
    @State private var didChangeLanguage = false
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var body: some View {
        HStack(spacing: .zero) {
            ScrollView(isZoomed ? .horizontal : []) {
                HStack(spacing: .zero) {
                    ForEach(ComposeContentToolbarView.ViewModel.Action.allCases, id: \.self) { action in
                        switch action {
                            case .attachment:
                                Menu {
                                    ForEach(ComposeContentToolbarView.ViewModel.AttachmentAction.allCases, id: \.self) { attachmentAction in
                                        Button {
                                            viewModel.delegate?.composeContentToolbarView(viewModel, attachmentMenuDidPressed: attachmentAction)
                                        } label: {
                                            Label {
                                                Text(attachmentAction.title)
                                            } icon: {
                                                Image(uiImage: attachmentAction.image)
                                            }
                                        }
                                    }
                                } label: {
                                    label(for: action)
                                        .opacity(viewModel.isAttachmentButtonEnabled ? 1.0 : 0.5)
                                }
                                .disabled(!viewModel.isAttachmentButtonEnabled)
                                .frame(width: 48, height: 48)
                            case .visibility:
                                Menu {
                                    Picker(selection: $viewModel.visibility) {
                                        ForEach(viewModel.allVisibilities, id: \.self) { visibility in
                                            Label {
                                                Text(visibility.title)
                                            } icon: {
                                                Image(uiImage: visibility.image)
                                            }
                                        }
                                    } label: {
                                        Text(viewModel.visibility.title)
                                    }
                                } label: {
                                    label(for: viewModel.visibility.image)
                                        .accessibilityLabel(L10n.Scene.Compose.Keyboard.selectVisibilityEntry(viewModel.visibility.title))
                                        .opacity(viewModel.isVisibilityButtonEnabled ? 1.0 : 0.5)
                                }
                                .disabled(!viewModel.isVisibilityButtonEnabled)
                                .frame(width: 48, height: 48)
                            case .poll:
                                Button {
                                    viewModel.delegate?.composeContentToolbarView(viewModel, toolbarItemDidPressed: action)
                                } label: {
                                    label(for: action)
                                        .opacity(viewModel.isPollButtonEnabled ? 1.0 : 0.5)
                                }
                                .disabled(!viewModel.isPollButtonEnabled)
                                .frame(width: 48, height: 48)
                            case .language:
                                Menu {
                                    Section {} // workaround a bug where the “Suggested” section doesn’t appear
                                    if !viewModel.suggestedLanguages.isEmpty {
                                        Section(L10n.Scene.Compose.Language.suggested) {
                                            ForEach(viewModel.suggestedLanguages.compactMap(Language.init(id:))) { lang in
                                                Toggle(isOn: languageBinding(for: lang.id)) {
                                                    Text(lang.label)
                                                }
                                            }
                                        }
                                    }
                                    let recent = viewModel.recentLanguages.filter { !viewModel.suggestedLanguages.contains($0) }
                                    if !recent.isEmpty {
                                        Section(L10n.Scene.Compose.Language.recent) {
                                            ForEach(recent.compactMap(Language.init(id:))) { lang in
                                                Toggle(isOn: languageBinding(for: lang.id)) {
                                                    Text(lang.label)
                                                }
                                            }
                                        }
                                    }
                                    if !(recent + viewModel.suggestedLanguages).contains(viewModel.language) {
                                        Toggle(isOn: languageBinding(for: viewModel.language)) {
                                            Text(Language(id: viewModel.language)?.label ?? AttributedString("\(viewModel.language)"))
                                        }
                                    }
                                    Button(L10n.Scene.Compose.Language.other) {
                                        showingLanguagePicker = true
                                    }
                                } label: {
                                    let font: SwiftUI.Font = {
                                        if #available(iOS 16, *) {
                                            return .system(size: 11, weight: .semibold).width(viewModel.language.count == 3 ? .compressed : .standard)
                                        } else {
                                            return .system(size: 11, weight: .semibold)
                                        }
                                    }()
                                    
                                    Text(viewModel.language)
                                        .font(font)
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 4)
                                        .minimumScaleFactor(0.5)
                                        .frame(width: 24, height: 24, alignment: .center)
                                        .overlay { RoundedRectangle(cornerRadius: 7).inset(by: 3).stroke(lineWidth: 1.5) }
                                        .accessibilityLabel(L10n.Scene.Compose.Language.title)
                                        .accessibilityValue(Text(Language(id: viewModel.language)?.label ?? AttributedString("\(viewModel.language)")))
                                        .foregroundColor(Color(Asset.Scene.Compose.buttonTint.color))
                                        .overlay(alignment: .topTrailing) {
                                            Group {
                                                if let suggested = viewModel.highConfidenceSuggestedLanguage,
                                                   suggested != viewModel.language,
                                                   !didChangeLanguage {
                                                    Circle().fill(.blue)
                                                        .frame(width: 8, height: 8)
                                                }
                                            }
                                            .transition(.opacity)
                                            .animation(.default, value: [viewModel.highConfidenceSuggestedLanguage, viewModel.language])
                                        }
                                    // fixes weird appearance when drawing at low opacity (eg when pressed)
                                        .drawingGroup()
                                }
                                .frame(width: 48, height: 48)
                                .popover(isPresented: $showingLanguagePicker) {
                                    let picker = LanguagePicker { newLanguage in
                                        viewModel.language = newLanguage
                                        didChangeLanguage = true
                                        showingLanguagePicker = false
                                    }
                                    if verticalSizeClass == .regular && horizontalSizeClass == .regular {
                                        // explicitly size picker when it’s a popover
                                        picker.frame(width: 400, height: 500)
                                    } else {
                                        picker
                                    }
                                }
                            default:
                                Button {
                                    viewModel.delegate?.composeContentToolbarView(viewModel, toolbarItemDidPressed: action)
                                } label: {
                                    label(for: action)
                                }
                                .frame(width: 48, height: 48)
                        }
                    }
                }
            }

            Spacer()
            let count: Int = {
                if viewModel.isContentWarningActive {
                    return viewModel.contentWeightedLength + viewModel.contentWarningWeightedLength
                } else {
                    return viewModel.contentWeightedLength
                }
            }()
            let remains = viewModel.maxTextInputLimit - count
            let isOverflow = remains < 0
            Text("\(remains)")
                .foregroundColor(Color(isOverflow ? UIColor.systemRed : UIColor.secondaryLabel))
                .font(.system(size: isOverflow ? 18 : 16, weight: isOverflow ? .medium : .regular))
                .accessibilityLabel(L10n.A11y.Plural.Count.charactersLeft(remains))

        }
        .padding(.leading, 4)       // 4 + 12 = 16
        .padding(.trailing, 16)
        .frame(height: ComposeContentToolbarView.toolbarHeight)
        .background(Color(viewModel.backgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Scene.Compose.Accessibility.postOptions)
    }
    
}

extension ComposeContentToolbarView {
    func label(for action: ComposeContentToolbarView.ViewModel.Action) -> some View {
        Image(uiImage: viewModel.image(for: action))
            .foregroundColor(Color(Asset.Scene.Compose.buttonTint.color))
            .frame(width: 24, height: 24, alignment: .center)
            .accessibilityLabel(viewModel.label(for: action))
    }
    
    func label(for image: UIImage) -> some View {
        Image(uiImage: image)
            .foregroundColor(Color(Asset.Scene.Compose.buttonTint.color))
            .frame(width: 24, height: 24, alignment: .center)
    }
    
    private func languageBinding(for code: String) -> Binding<Bool> {
        Binding {
            code == viewModel.language
        } set: { newValue in
            if newValue {
                viewModel.language = code
            }
            didChangeLanguage = true
        }
    }
}

extension Mastodon.Entity.Status.Visibility {
    fileprivate var title: String {
        switch self {
        case .public:               return L10n.Scene.Compose.Visibility.public
        case .unlisted:             return L10n.Scene.Compose.Visibility.unlisted
        case .private:              return L10n.Scene.Compose.Visibility.private
        case .direct:               return L10n.Scene.Compose.Visibility.direct
        case ._other(let value):    return value
        }
    }
    
    fileprivate var image: UIImage {
        switch self {
        case .public:       return Asset.Scene.Compose.earth.image.withRenderingMode(.alwaysTemplate)
        case .unlisted:     return Asset.Scene.Compose.people.image.withRenderingMode(.alwaysTemplate)
        case .private:      return Asset.Scene.Compose.peopleAdd.image.withRenderingMode(.alwaysTemplate)
        case .direct:       return Asset.Scene.Compose.mention.image.withRenderingMode(.alwaysTemplate)
        case ._other:       return Asset.Scene.Compose.more.image.withRenderingMode(.alwaysTemplate)
        }
    }
}
