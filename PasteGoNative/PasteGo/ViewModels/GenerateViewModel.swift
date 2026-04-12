import Foundation
import NaturalLanguage
import SwiftUI

/// ViewModel for AI generation view
@Observable
final class GenerateViewModel {
    var workbenchOutput: String = ""
    var shortcutOutput: String = ""
    var workbenchIsGenerating = false
    var shortcutIsGenerating = false
    var workbenchError: String?
    var shortcutError: String?
    var activeTemplateId: String?
    var isCustomMode = false
    var customPrompt: String = ""
    var workbenchThinkExpanded = false
    var shortcutThinkExpanded = false
    var quickActionSourceText: String?
    var quickActionSourceType: ClipType?

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
    var workbenchParsedOutput: (thinking: String, content: String) {
        parseOutput(workbenchOutput)
    }

    var shortcutParsedOutput: (thinking: String, content: String) {
        parseOutput(shortcutOutput)
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
        let target: GenerateTarget = template == nil ? .workbench : .shortcuts
        // Build the prompt
        let materials = items.map(\.content).joined(separator: "\n\n")
        let prompt: String

        if let template {
            prompt = buildTemplatePrompt(template: template, materials: materials)
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
            setError("尚未配置 AI 模型。请先到“设置”里添加并设为默认模型。", for: target)
            return
        }

        // Cancel any existing generation
        generateTask?.cancel()

        setOutput("", for: target)
        setError(nil, for: target)
        setThinkingExpanded(false, for: target)
        setGenerating(true, for: target)

        generateTask = Task { @MainActor in
            do {
                let stream = aiService.generate(provider: provider, prompt: prompt)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    if !chunk.content.isEmpty {
                        appendOutput(chunk.content, for: target)
                    }
                    if chunk.done {
                        break
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.setError(error.localizedDescription, for: target)
                }
            }
            setGenerating(false, for: target)
        }
    }

    func reset() {
        generateTask?.cancel()
        activeTemplateId = nil
        customPrompt = ""
        resetWorkbench()
        resetShortcuts()
    }

    func resetWorkbench() {
        workbenchOutput = ""
        workbenchError = nil
        workbenchIsGenerating = false
        workbenchThinkExpanded = false
    }

    func resetShortcuts() {
        shortcutOutput = ""
        shortcutError = nil
        shortcutIsGenerating = false
        shortcutThinkExpanded = false
    }

    func setQuickActionSource(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            quickActionSourceText = nil
            quickActionSourceType = nil
            return
        }
        quickActionSourceText = trimmed
        quickActionSourceType = ContentTypeDetector.detect(trimmed)
    }

    func setShortcutError(_ message: String?) {
        shortcutError = message
    }

    private func buildTemplatePrompt(template: Template, materials: String) -> String {
        guard template.id == "tpl-translate" else {
            return template.prompt.replacingOccurrences(of: "{{materials}}", with: materials)
        }

        let targetLanguage = translationTarget(for: materials)
        switch targetLanguage {
        case .english:
            return """
            You are a professional translator. Translate the following text into natural, accurate English. Output only the translation. Do not explain, do not add notes, and do not repeat the source text.

            Source text:
            \(materials)
            """
        case .simplifiedChinese:
            return """
            你是一名专业翻译助手。请将下面的原文翻译成自然、准确的简体中文。只输出译文，不要解释，不要添加注释，也不要重复原文。

            原文：
            \(materials)
            """
        }
    }

    private func translationTarget(for text: String) -> TranslationTarget {
        if containsJapaneseKana(text) {
            return .simplifiedChinese
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(2000)))

        switch recognizer.dominantLanguage {
        case .simplifiedChinese, .traditionalChinese:
            return .english
        case .japanese, .korean, .english, .french, .german, .italian, .spanish, .portuguese, .russian:
            return .simplifiedChinese
        default:
            return containsMostlyChinese(text) ? .english : .simplifiedChinese
        }
    }

    private func containsJapaneseKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
        }
    }

    private func containsMostlyChinese(_ text: String) -> Bool {
        let scalars = text.unicodeScalars
        let cjkCount = scalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        let latinCount = scalars.filter {
            (0x0041...0x005A).contains($0.value) || (0x0061...0x007A).contains($0.value)
        }.count
        return cjkCount > 0 && cjkCount >= latinCount
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

    private func setOutput(_ value: String, for target: GenerateTarget) {
        switch target {
        case .workbench: workbenchOutput = value
        case .shortcuts: shortcutOutput = value
        }
    }

    private func appendOutput(_ value: String, for target: GenerateTarget) {
        switch target {
        case .workbench: workbenchOutput += value
        case .shortcuts: shortcutOutput += value
        }
    }

    private func setError(_ value: String?, for target: GenerateTarget) {
        switch target {
        case .workbench: workbenchError = value
        case .shortcuts: shortcutError = value
        }
    }

    private func setGenerating(_ value: Bool, for target: GenerateTarget) {
        switch target {
        case .workbench: workbenchIsGenerating = value
        case .shortcuts: shortcutIsGenerating = value
        }
    }

    private func setThinkingExpanded(_ value: Bool, for target: GenerateTarget) {
        switch target {
        case .workbench: workbenchThinkExpanded = value
        case .shortcuts: shortcutThinkExpanded = value
        }
    }
}

private enum TranslationTarget {
    case english
    case simplifiedChinese
}

private enum GenerateTarget {
    case workbench
    case shortcuts
}
