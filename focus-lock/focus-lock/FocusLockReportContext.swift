//
//  FocusLockReportContext.swift
//  focus-lock
//

// _DeviceActivity_SwiftUI gives us DeviceActivityReport.Context.
//
// Apple exposes the report UI pieces in this SwiftUI companion framework.
import _DeviceActivity_SwiftUI

// The main app and the DeviceActivity report extension must agree on the same
// context value. The main app asks for this context, and the report extension
// provides the matching report scene.
extension DeviceActivityReport.Context {
    static let focusLockHabits = Self("FocusLockHabits")
}
