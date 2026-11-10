//
//  GeneralSettingsView.swift
//  SimplyTrack
//
//  Created by Soner Köksal on 08.09.2025.
//

import ServiceManagement
import SwiftUI

/// General settings view for app preferences and system integration.
/// Handles launch at login configuration and update frequency settings.
struct GeneralSettingsView: View {
    @StateObject private var loginItemManager = LoginItemManager.shared
    @State private var launchAtLoginEnabled = false
    @AppStorage("updateFrequency", store: .app) private var updateFrequency: UpdateFrequency = .daily
    @AppStorage("trackingInterval", store: .app) private var trackingInterval: Double = AppStorageDefaults.trackingInterval
    @AppStorage("dataPersistenceInterval", store: .app) private var dataPersistenceInterval: Double = AppStorageDefaults.dataPersistenceInterval
    @AppStorage("idleThreshold", store: .app) private var idleThreshold: Double = AppStorageDefaults.idleThreshold

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "power")
                            .foregroundColor(.blue)
                            .frame(width: 16)
                        Toggle(
                            "Launch SimplyTrack at login",
                            isOn: Binding(
                                get: { launchAtLoginEnabled },
                                set: { _ in toggleLaunchAtLogin() }
                            )
                        )
                        .toggleStyle(.switch)
                        Spacer()
                    }

                    Text("Automatically start SimplyTrack when you log in to your Mac")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundColor(.green)
                            .frame(width: 16)
                        Text("Check for updates")

                        Spacer()

                        Picker("", selection: $updateFrequency) {
                            ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    Text("How often SimplyTrack should check for new versions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Tracking & Performance") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "gauge.with.needle")
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            Text("Activity refresh rate")

                            Spacer()

                            Picker("", selection: $trackingInterval) {
                                ForEach(TrackingInterval.allCases) { interval in
                                    Text(interval.label).tag(interval.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }

                        Text("How often SimplyTrack polls the frontmost application and website")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.purple)
                                .frame(width: 16)
                            Text("Data save interval")

                            Spacer()

                            Picker("", selection: $dataPersistenceInterval) {
                                ForEach(PersistenceInterval.allCases) { interval in
                                    Text(interval.label).tag(interval.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }

                        Text("How often tracked activity sessions are persisted to the database")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "moon.zzz")
                                .foregroundColor(.indigo)
                                .frame(width: 16)
                            Text("Idle detection threshold")

                            Spacer()

                            Picker("", selection: $idleThreshold) {
                                ForEach(IdleThreshold.allCases) { threshold in
                                    Text(threshold.label).tag(threshold.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 200)
                        }

                        Text("Inactive time before active tracking sessions are ended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                launchAtLoginEnabled = await loginItemManager.getCurrentStatus()
            }
        }
    }

    private func toggleLaunchAtLogin() {
        Task {
            do {
                launchAtLoginEnabled = try await loginItemManager.toggleLaunchAtLogin()
            } catch {
                // Error handling is done in the manager
            }
        }
    }

}

#Preview {
    GeneralSettingsView()
        .frame(width: 550, height: 400)
}
