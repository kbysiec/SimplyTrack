//
//  AISettingsView.swift
//  SimplyTrack
//
//  Settings view for Apple Intelligence on-device summarization and daily notifications.
//

import SwiftUI
import os

/// AI settings view focused on native Apple Intelligence and summary notifications.
struct AISettingsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AISettingsView")
    @EnvironmentObject private var appDelegate: AppDelegate

    @State private var isTestingConnection = false
    @State private var isSendingTestNotification = false
    @State private var testResult: TestResult?
    @State private var testNotificationResult: TestResult?
    @StateObject private var claudeConfigManager = ClaudeDesktopConfigManager()

    // Notification settings
    @AppStorage("summaryNotificationsEnabled", store: .app) private var summaryNotificationsEnabled = false
    @AppStorage("summaryNotificationTime", store: .app) private var summaryNotificationTime: Double = AppStorageDefaults.summaryNotificationTime
    @AppStorage("summaryNotificationPrompt", store: .app) private var summaryNotificationPrompt = AppStorageDefaults.summaryNotificationPrompt

    private var hasAIConfigurationErrors: Bool {
        !AppleIntelligenceService.isAvailable || summaryNotificationPrompt.isEmpty
    }

    private var canSendTestNotification: Bool {
        AppleIntelligenceService.isAvailable && !summaryNotificationPrompt.isEmpty
    }

    enum TestResult {
        case success(String)
        case failure(String)

        var isSuccess: Bool {
            switch self {
            case .success: return true
            case .failure: return false
            }
        }

        var message: String {
            switch self {
            case .success(let message): return message
            case .failure(let message): return message
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section("Apple Intelligence (On-Device)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: AppleIntelligenceService.isAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(AppleIntelligenceService.isAvailable ? .green : .orange)

                            Text(AppleIntelligenceService.availabilityDescription)
                                .font(.body)
                                .foregroundColor(AppleIntelligenceService.isAvailable ? .primary : .secondary)

                            Spacer()
                        }

                        Text(
                            "SimplyTrack uses Apple's native on-device Foundation Models. All summaries are generated locally using Apple Silicon Neural Engine with zero network requests and full privacy."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "cpu")
                                .foregroundColor(.cyan)
                                .frame(width: 16)

                            Button("Test Apple Intelligence") {
                                Task {
                                    await testAppleIntelligence()
                                }
                            }
                            .disabled(isTestingConnection)

                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            }

                            Spacer()
                        }

                        Text("Verify that on-device Foundation Models are ready to generate summaries.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)

                    if let result = testResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .font(.caption)

                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }

                Section("Summary Notifications") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            Toggle(
                                "Enable summary notification",
                                isOn: Binding(
                                    get: { summaryNotificationsEnabled && !hasAIConfigurationErrors },
                                    set: { newValue in
                                        summaryNotificationsEnabled = newValue
                                    }
                                )
                            )
                            .disabled(hasAIConfigurationErrors)
                            .toggleStyle(.switch)
                            Spacer()
                        }

                        Text("Send daily notification with AI-generated usage summary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                                .frame(width: 16)
                            Text("Notification time")

                            Spacer()

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { Date(timeIntervalSince1970: summaryNotificationTime) },
                                    set: { summaryNotificationTime = $0.timeIntervalSince1970 }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .frame(width: 100)
                        }

                        Text("Time to receive daily summary notifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.purple)
                                .frame(width: 16)
                            TextField(text: $summaryNotificationPrompt, prompt: Text("Create a brief daily summary..."), axis: .vertical) {
                                Text("Prompt")
                            }
                            .lineLimit(4...8)
                        }

                        if summaryNotificationsEnabled && summaryNotificationPrompt.isEmpty {
                            Text("Prompt is required")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("Prompt for generating summary notification. Use {appSummary} and {websiteSummary} placeholders.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.green)
                                .frame(width: 16)
                            Button("Send Test Notification") {
                                Task {
                                    await sendTestNotification()
                                }
                            }
                            .disabled(!canSendTestNotification || isSendingTestNotification)

                            if isSendingTestNotification {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .frame(width: 16, height: 16)
                            }

                            Spacer()
                        }

                        Text("Generate an AI summary for the currently selected day and deliver it as a notification now.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let result = testNotificationResult {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .font(.caption)

                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.isSuccess ? .green : .red)
                                .multilineTextAlignment(.leading)

                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                }

                Section("AI Tool Integration") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "terminal")
                                .foregroundColor(.blue)
                                .frame(width: 16)
                            Text("MCP Server Configuration")
                                .font(.headline)
                            Spacer()
                        }

                        Text("SimplyTrack includes a bundled MCP (Model Context Protocol) server for AI tool integration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purple)
                                .frame(width: 16)
                            Text("Configuration")
                            Spacer()
                        }

                        TextEditor(text: .constant(claudeConfigManager.mcpConfiguration))
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 160)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )

                        Text("Copy this configuration to your Claude Desktop config file (\(claudeConfigManager.claudeConfigPath))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Image(systemName: claudeConfigManager.status.icon)
                                .foregroundColor(claudeConfigManager.status.color)
                                .frame(width: 16)

                            Text(claudeConfigManager.status.message)
                                .foregroundColor(claudeConfigManager.status.color)

                            Spacer()
                        }

                        HStack(spacing: 8) {
                            if case .warning = claudeConfigManager.status {
                                Button("Auto-Configure") {
                                    claudeConfigManager.addConfiguration()
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            Button("Copy Configuration") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(claudeConfigManager.mcpConfiguration, forType: .string)
                            }

                            Button("Refresh Status") {
                                claudeConfigManager.checkConfiguration()
                            }

                            Spacer()
                        }

                        Text("Auto-configure Claude Desktop or copy configuration manually")
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
            claudeConfigManager.checkConfiguration()
        }
    }

    private func testAppleIntelligence() async {
        isTestingConnection = true
        testResult = nil

        if AppleIntelligenceService.isAvailable {
            do {
                let service = AppleIntelligenceService()
                let result = try await service.generateSummary(
                    appSummary: "Xcode: 2h 30m, Safari: 1h 15m",
                    websiteSummary: "github.com: 45m",
                    customPromptTemplate: "Create a 1-sentence confirmation test summary based on: {appSummary}"
                )
                testResult = .success("Apple Intelligence is available and working on-device! Sample: \"\(result.prefix(60))...\"")
            } catch {
                testResult = .failure("Apple Intelligence test failed: \(error.localizedDescription)")
            }
        } else {
            testResult = .failure(AppleIntelligenceService.availabilityDescription)
        }

        isTestingConnection = false
    }

    private func sendTestNotification() async {
        isSendingTestNotification = true
        testNotificationResult = nil

        do {
            try await appDelegate.sendTestSummaryNotification()
            testNotificationResult = .success("Test notification sent")
        } catch {
            testNotificationResult = .failure("Test notification failed: \(error.localizedDescription)")
        }

        isSendingTestNotification = false
    }
}

#Preview {
    AISettingsView()
        .frame(width: 550, height: 400)
}
