//
//  AppIntent.swift
//  NoDiaryWidget
//
//  Created by Liwei Xie on 13.3.2026.
//  Copyright © 2026 Xie Liwei. All rights reserved.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
}
