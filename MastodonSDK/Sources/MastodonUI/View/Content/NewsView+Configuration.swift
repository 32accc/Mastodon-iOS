//
//  NewsView+Configuration.swift
//  
//
//  Created by MainasuK on 2022-4-13.
//

import UIKit
import Combine
import MastodonSDK
import MastodonLocalization
import AlamofireImage
import FaviconFinder

extension NewsView {
    public func configure(link: Mastodon.Entity.Link) {
        let faviconPlaceholder = UIImage(systemName: "network")
        providerFaviconImageView.image = faviconPlaceholder
        if let url = URL(string: link.url) {
            let token = providerFaviconImageView.tag
            FaviconFinder(url: url).downloadFavicon { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let favicon):
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        guard self.providerFaviconImageView.tag == token else { return }
                        self.providerFaviconImageView.image = favicon.image
                    }
                case .failure:
                    break
                }
            }
        }
        providerNameLabel.text = link.providerName
        headlineLabel.text = link.title
        footnoteLabel.text = L10n.Plural.peopleTalking(link.talkingPeopleCount ?? 0) 
        
        let configuration = MediaView.Configuration(
            info: .image(info: .init(
                aspectRadio: CGSize(width: link.width, height: link.height),
                assetURL: link.image,
                altDescription: nil
            )),
            blurhash: link.blurhash,
            index: 1,
            total: 1
        )
        imageView.setup(configuration: configuration)
        
        if let previewURL = configuration.previewURL,
           let url = URL(string: previewURL)
        {
            let placeholder = UIImage.placeholder(color: .systemGray6)
            let request = URLRequest(url: url)
            ImageDownloader.default.download(request, completion:  { response in
                switch response.result {
                case .success(let image):
                    configuration.previewImage = image
                case .failure:
                    configuration.previewImage = placeholder
                }
            })
        }
    }   // end func
}
