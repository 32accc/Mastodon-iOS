// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import CoreDataStack

struct StatusEditHistoryViewModel {
    var status: Status
    var edits: [StatusEdit]
}
