//
//  SummaryProvider.swift
//  SimplyTrack
//
//  Defines the common abstraction for usage summarization providers,
//  supporting on-device Apple Intelligence and external/local OpenAI-compatible endpoints.
//

import Foundation

/// Defines the contract for services capable of generating text summaries from usage data.
protocol SummaryProvider: Sendable {
    /// Generates a summary based on application and website usage text.
    /// - Parameters:
    ///   - appSummary: Aggregated application usage string.
    ///   - websiteSummary: Aggregated website usage string.
    ///   - customPromptTemplate: Optional prompt template containing {appSummary} and {websiteSummary} placeholders.
    /// - Returns: A generated summary string.
    func generateSummary(
        appSummary: String,
        websiteSummary: String,
        customPromptTemplate: String?
    ) async throws -> String
}

/// Identifies the configured or preferred AI summary engine.
enum AISummaryEngine: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case appleIntelligence = "appleIntelligence"
    case openAICompatible = "openAICompatible"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic:
            return "Automatic (Apple Intelligence if available)"
        case .appleIntelligence:
            return "Apple Intelligence (On-Device)"
        case .openAICompatible:
            return "Custom / Local Endpoint (Ollama, OpenAI)"
        }
    }
}

