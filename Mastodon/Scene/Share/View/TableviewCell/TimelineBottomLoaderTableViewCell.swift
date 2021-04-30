//
//  TimelineBottomLoaderTableViewCell.swift
//  Mastodon
//
//  Created by sxiaojian on 2021/2/3.
//

import UIKit
import Combine

final class TimelineBottomLoaderTableViewCell: TimelineLoaderTableViewCell {
    override func _init() {
        super._init()
        
        activityIndicatorView.isHidden = false
        
        startAnimating()
        
        separatorInset = UIEdgeInsets(top: 0, left: bounds.size.width, bottom: 0, right: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        separatorInset = UIEdgeInsets(top: 0, left: bounds.size.width, bottom: 0, right: 0)
    }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct TimelineBottomLoaderTableViewCell_Previews: PreviewProvider {
    
    static var previews: some View {
        UIViewPreview(width: 375) {
            TimelineBottomLoaderTableViewCell()
        }
        .previewLayout(.fixed(width: 375, height: 100))
    }
    
}

#endif

