//
//  KadoWidgetsBundle.swift
//  KadoWidgets
//
//  Created by Sébastien Castiel on 18/04/2026.
//

import SwiftUI
import WidgetKit

@main
struct KadoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayGridSmallWidget()
        TodayProgressMediumWidget()
        WeeklyGridLargeWidget()
        LockRectangularWidget()
        LockCircularWidget()
        LockInlineWidget()
    }
}
