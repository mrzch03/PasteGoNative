import Foundation
import SwiftUI

/// ViewModel for AI generation view
@Observable
final class GenerateViewModel {
    var output: String = ""
    var isGenerating = false
    var error: String?
    var activeTemplateId: String?
    var isCustomMode = false
    var customPrompt: String = ""
    var thinkExpanded = false

    var templates: [Template] = []
    var providers: [AiProvider] = []

    private let templateRepo: TemplateRepository
    private let providerRepo: ProviderRepository
    private let aiService = AIStreamingService()
    private var generateTask: Task<Void, Never>?

    init(templateRepo: TemplateRepository, providerRepo: ProviderRepository) {
        self.templateRepo = templateRepo
        self.providerRepo = providerRepo
    }

    var defaultProvider: AiProvider? {
        providers.first { $0.isDefault } ?? providers.first
    }

    /// Parsed output: separates <think> blocks from main content
    var parsedOutput: (thinking: String, content: String) {
        parseOutput(output)
    }

    // MARK: - Data loading

    func fetchTemplates() {
        do {
            templates = try templateRepo.fetchAll()
        } catch {
            print("Failed to fetch templates: \(error)")
        }
    }

    func fetchProviders() {
        do {
            providers = try providerRepo.fetchAll()
        } catch {
            print("Failed to fetch providers: \(error)")
        }
    }

    // MARK: - Generation

    func generate(items: [ClipItem], template: Template?, customPrompt: String, providerId: String? = nil) {
        // Build the prompt
        let materials = items.map(\.content).joined(separator: "\n\n")
        var prompt: String

        if let template {
            prompt = template.prompt.replacingOccurrences(of: "{{materials}}", with: materials)
            activeTemplateId = template.id
            isCustomMode = false
        } else {
            prompt = "\(customPrompt)\n\n素材:\n\(materials)"
            activeTemplateId = nil
            isCustomMode = true
        }

        let provider: AiProvider?
        if let providerId {
            provider = providers.first { $0.id == providerId }
        } else {
            provider = defaultProvider
        }

        guard let provider else {
            error = "No AI provider configured. Please add one in Settings."
            return
        }

        // Cancel any existing generation
        generateTask?.cancel()

        output = ""
        error = nil
        isGenerating = true

        generateTask = Task { @MainActor in
            do {
                let stream = aiService.generate(provider: provider, prompt: prompt)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    if !chunk.content.isEmpty {
                        output += chunk.content
                    }
                    if chunk.done {
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.error = error.localizedDescription
                }
            }
            isGenerating = false
        }
    }

    func reset() {
        generateTask?.cancel()
        output = ""
        error = nil
        isGenerating = false
        activeTemplateId = nil
        customPrompt = ""
        thinkExpanded = false
    }

    // MARK: - Parse <think> blocks

    private func parseOutput(_ raw: String) -> (thinking: String, content: String) {
        guard let range = raw.range(of: #"<think>([\s\S]*?)(</think>|$)"#, options: .regularExpression) else {
            return ("", raw)
        }
        let thinkMatch = raw[range]
        let thinking = thinkMatch
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let content = raw.replacingCharacters(in: range, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (thinking, content)
    }
}
