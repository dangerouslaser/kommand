//
//  KommandLiveActivityBundle.swift
//  KommandLiveActivity
//
//  Widget bundle for Kommand Live Activities.
//

import SwiftUI
import WidgetKit

@main
struct KommandLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingLiveActivity()
    }
}
