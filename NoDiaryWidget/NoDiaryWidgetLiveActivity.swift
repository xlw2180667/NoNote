//
//  NoDiaryWidgetLiveActivity.swift
//  NoDiaryWidget
//
//  Created by Liwei Xie on 13.3.2026.
//  Copyright © 2026 Xie Liwei. All rights reserved.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct NoDiaryWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct NoDiaryWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NoDiaryWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension NoDiaryWidgetAttributes {
    fileprivate static var preview: NoDiaryWidgetAttributes {
        NoDiaryWidgetAttributes(name: "World")
    }
}

extension NoDiaryWidgetAttributes.ContentState {
    fileprivate static var smiley: NoDiaryWidgetAttributes.ContentState {
        NoDiaryWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: NoDiaryWidgetAttributes.ContentState {
         NoDiaryWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: NoDiaryWidgetAttributes.preview) {
   NoDiaryWidgetLiveActivity()
} contentStates: {
    NoDiaryWidgetAttributes.ContentState.smiley
    NoDiaryWidgetAttributes.ContentState.starEyes
}
