//
//  FocusLockDiagnostics.swift
//  focus-lock
//

import Foundation

// Temporary diagnostics used while we debug DeviceActivity monitor behavior.
//
// DeviceActivity extensions do not always make print output easy to find, so this
// writes breadcrumbs into the shared App Group container as well as printing them.
enum FocusLockDiagnostics {
    // Keep diagnostics off by default so normal development does not spam the Xcode
    // console or write diagnostic files. Flip this to true temporarily when debugging
    // DeviceActivity scheduling or App Group storage.
    private static let isEnabled = false

    private static let fileName = "diagnostics.log"

    static func record(_ message: String) {
        guard isEnabled else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"

        print(line, terminator: "")

        guard let url = diagnosticsFileURL() else {
            print("[\(timestamp)] FocusLockDiagnostics could not find App Group container.\n", terminator: "")
            return
        }

        guard let data = line.data(using: .utf8) else {
            return
        }

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url)
            }
        } catch {
            print("[\(timestamp)] Failed to write Focus Lock diagnostics: \(error)\n", terminator: "")
        }
    }

    static func appGroupContainerURL() -> URL? {
        if isEnabled {
            print("FocusLockDiagnostics using app group: \(FocusLockConfiguration.appGroupIdentifier) (\(FocusLockConfiguration.appGroupSource))")
        }

        return FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: FocusLockConfiguration.appGroupIdentifier
        )
    }

    static func dumpLogToConsole() {
        guard isEnabled else {
            return
        }

        guard let url = diagnosticsFileURL() else {
            print("FocusLockDiagnostics could not dump log because App Group container is unavailable.")
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            print("FocusLockDiagnostics has no existing log file at \(url.path).")
            return
        }

        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            print("----- Focus Lock diagnostics log -----")
            print(contents)
            print("----- End Focus Lock diagnostics log -----")
        } catch {
            print("FocusLockDiagnostics failed to read log: \(error)")
        }
    }

    private static func diagnosticsFileURL() -> URL? {
        appGroupContainerURL()?.appendingPathComponent(fileName)
    }
}
