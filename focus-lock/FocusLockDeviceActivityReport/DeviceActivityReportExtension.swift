//
//  DeviceActivityReportExtension.swift
//  FocusLockDeviceActivityReport
//

import DeviceActivity
import _DeviceActivity_SwiftUI

@main
struct FocusLockDeviceActivityReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        FocusLockHabitsReport()
    }
}
