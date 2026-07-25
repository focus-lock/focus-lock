//
//  ScreenTimePermissionNotice.swift
//  focus-lock
//

import FamilyControls
import SwiftUI

struct ScreenTimePermissionNotice: View {
    @EnvironmentObject private var familyControlsManager: FamilyControlsManager

    var body: some View {
        if !familyControlsManager.hasScreenTimePermission {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screen Time access needed")
                            .font(.subheadline.weight(.semibold))

                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let errorMessage = familyControlsManager.authorizationErrorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task {
                        await familyControlsManager.requestAuthorization()
                    }
                } label: {
                    Label("Request Access", systemImage: "shield")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var message: String {
        let status = familyControlsManager.authorizationStatus

        if status == .notDetermined {
            return "Focus Lock needs Screen Time permission before it can pick apps, register schedules, or block distractions."
        }

        if status == .denied {
            return "Screen Time permission is currently denied. Rules may save, but blocking and reports will not work until access is restored."
        }

        if status == .approved {
            return ""
        }

        if #available(iOS 26.4, *), status == .approvedWithDataAccess {
            return ""
        }

        return "Focus Lock cannot confirm Screen Time access right now. Blocking and reports may not work until access is restored."
    }
}

#Preview {
    ScreenTimePermissionNotice()
        .environmentObject(FamilyControlsManager.shared)
        .padding()
}
