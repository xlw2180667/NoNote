//
//  NoDiaryWidgetBundle.swift
//  NoDiaryWidget
//
//  Created by Liwei Xie on 13.3.2026.
//  Copyright © 2026 Xie Liwei. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct NoDiaryWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoDiaryWidget()
        NoDiaryWidgetControl()
        NoDiaryWidgetLiveActivity()
    }
}
