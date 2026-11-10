//
//  AppleIntelligenceService.swift
//  SimplyTrack
//
//  Native on-device Apple Intelligence summarization provider utilizing the FoundationModels framework.
//

import Foundation

#if canImport(FoundationModels)
    import FoundationModels
#endif

/// Errors that can occur when generating summaries with Apple Intelligence.
enum AppleIntelligenceError: LocalizedError {
    case unsupportedOSVersion
    case modelNotAvailable(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedOSVersion:
            return "Apple Intelligence requires macOS 26.0 or later with Apple Silicon."
        case .modelNotAvailable(let reason):
            return "Apple Intelligence is currently unavailable: \(reason)"
        case .emptyResponse:
            return "Apple Intelligence returned an empty response."
        }
    }
}

/// Service that leverages Apple's on-device Foundation Models for usage summary generation.
final class AppleIntelligenceService: SummaryProvider, @unchecked Sendable {

    /// Checks if Apple Intelligence is supported and ready on this Mac.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                return SystemLanguageModel.default.isAvailable
            }
        #endif
        return false
    }

    /// Provides a human-readable availability status description.
    static var availabilityDescription: String {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                if SystemLanguageModel.default.isAvailable {
                    return "Ready (On-Device Apple Intelligence)"
                } else {
                    return "Unavailable on this device (Model not ready or unsupported hardware)"
                }
            } else {
                return "Requires macOS 26.0 or later"
            }
        #else
            return "FoundationModels framework not supported in current build environment"
        #endif
    }

    func generateSummary(
        appSummary: String,
        websiteSummary: String,
        customPromptTemplate: String?
    ) async throws -> String {
        #if canImport(FoundationModels)
            if #available(macOS 26.0, *) {
                guard SystemLanguageModel.default.isAvailable else {
                    throw AppleIntelligenceError.modelNotAvailable("System language model is not available or Apple Intelligence is disabled in System Settings.")
                }

                let template = customPromptTemplate ?? AppStorageDefaults.summaryNotificationPrompt
                let prompt =
                    template
                    .replacingOccurrences(of: "{appSummary}", with: appSummary.isEmpty ? "None" : appSummary)
                    .replacingOccurrences(of: "{websiteSummary}", with: websiteSummary.isEmpty ? "None" : websiteSummary)

                let session = LanguageModelSession()
                let response = try await session.respond(to: prompt)
                let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !text.isEmpty else {
                    throw AppleIntelligenceError.emptyResponse
                }

                return text
            } else {
                throw AppleIntelligenceError.unsupportedOSVersion
            }
        #else
            throw AppleIntelligenceError.unsupportedOSVersion
        #endif
    }
}
