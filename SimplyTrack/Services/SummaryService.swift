//
//  SummaryService.swift
//  SimplyTrack
//
//  Coordinates summarization across Apple Intelligence and OpenAI-compatible providers.
//

import Foundation

/// Unified service responsible for preparing data and generating AI-powered usage summaries.
final class SummaryService: @unchecked Sendable {

    static let shared = SummaryService()

    private let appleIntelligenceService = AppleIntelligenceService()

    private init() {}

    /// Resolves the effective provider based on user settings and runtime availability.
    func resolveProvider(engine: AISummaryEngine, apiURL: String, apiKey: String, model: String, chatTemplateKwargs: String, reasoningEffort: String) -> SummaryProvider {
        switch engine {
        case .appleIntelligence:
            return appleIntelligenceService

        case .openAICompatible:
            return OpenAISummaryProvider(
                apiURL: apiURL,
                apiKey: apiKey,
                model: model,
                chatTemplateKwargs: chatTemplateKwargs,
                reasoningEffort: reasoningEffort
            )

        case .automatic:
            if AppleIntelligenceService.isAvailable {
                return appleIntelligenceService
            } else {
                return OpenAISummaryProvider(
                    apiURL: apiURL,
                    apiKey: apiKey,
                    model: model,
                    chatTemplateKwargs: chatTemplateKwargs,
                    reasoningEffort: reasoningEffort
                )
            }
        }
    }

    /// Generates a summary with the resolved engine.
    func generateSummary(
        engine: AISummaryEngine,
        appSummary: String,
        websiteSummary: String,
        promptTemplate: String,
        apiURL: String,
        apiKey: String,
        model: String,
        chatTemplateKwargs: String,
        reasoningEffort: String
    ) async throws -> String {
        let provider = resolveProvider(
            engine: engine,
            apiURL: apiURL,
            apiKey: apiKey,
            model: model,
            chatTemplateKwargs: chatTemplateKwargs,
            reasoningEffort: reasoningEffort
        )

        return try await provider.generateSummary(
            appSummary: appSummary,
            websiteSummary: websiteSummary,
            customPromptTemplate: promptTemplate
        )
    }
}

/// Adapter conforming `OpenAIService` to `SummaryProvider`.
final class OpenAISummaryProvider: SummaryProvider, @unchecked Sendable {
    private let apiURL: String
    private let apiKey: String
    private let model: String
    private let chatTemplateKwargs: String
    private let reasoningEffort: String

    init(apiURL: String, apiKey: String, model: String, chatTemplateKwargs: String, reasoningEffort: String) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.model = model
        self.chatTemplateKwargs = chatTemplateKwargs
        self.reasoningEffort = reasoningEffort
    }

    func generateSummary(
        appSummary: String,
        websiteSummary: String,
        customPromptTemplate: String?
    ) async throws -> String {
        let template = customPromptTemplate ?? AppStorageDefaults.summaryNotificationPrompt
        let fullPrompt =
            template
            .replacingOccurrences(of: "{appSummary}", with: appSummary.isEmpty ? "None" : appSummary)
            .replacingOccurrences(of: "{websiteSummary}", with: websiteSummary.isEmpty ? "None" : websiteSummary)

        let openAI = OpenAIService(apiURL: apiURL, apiKey: apiKey)
        let parsedKwargs = try OpenAIService.parseChatTemplateKwargs(chatTemplateKwargs)
        let parsedEffort = OpenAIService.parseReasoningEffort(reasoningEffort)

        let response = try await openAI.chatCompletions(
            model: model,
            messages: [
                OpenAIChatMessage(
                    role: "system",
                    content: "Return only the final user-facing summary. Do not include thinking process, reasoning steps, analysis, or chain-of-thought."
                ),
                OpenAIChatMessage(role: "user", content: fullPrompt),
            ],
            temperature: 0.7,
            maxTokens: 2048,
            chatTemplateKwargs: parsedKwargs,
            reasoningEffort: parsedEffort
        )

        let rawSummary = response.choices.first?.message.content ?? ""
        let cleanedSummary = OpenAIService.stripThinkingContent(from: rawSummary)

        guard !cleanedSummary.isEmpty else {
            throw NotificationError.emptySummary
        }

        return cleanedSummary
    }
}
