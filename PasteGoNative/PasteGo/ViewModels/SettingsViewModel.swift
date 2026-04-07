import Foundation
import SwiftUI

/// ViewModel for the settings view
@Observable
final class SettingsViewModel {
    var providers: [AiProvider] = []
    var templates: [Template] = []

    // Provider editing state
    var isEditingProvider = false
    var providerForm = AiProvider()

    // Template editing state
    var isEditingTemplate = false
    var templateForm = Template()
    var isRecordingShortcut = false

    private let providerRepo: ProviderRepository
    private let templateRepo: TemplateRepository
    var onTemplatesChanged: (() -> Void)?

    init(providerRepo: ProviderRepository, templateRepo: TemplateRepository) {
        self.providerRepo = providerRepo
        self.templateRepo = templateRepo
    }

    // MARK: - Data loading

    func fetchAll() {
        do {
            providers = try providerRepo.fetchAll()
            templates = try templateRepo.fetchAll()
        } catch {
            print("Failed to fetch settings data: \(error)")
        }
    }

    // MARK: - Provider operations

    func startAddProvider() {
        providerForm = AiProvider(
            id: "provider-\(Int(Date().timeIntervalSince1970))",
            isDefault: providers.isEmpty
        )
        isEditingProvider = true
    }

    func startEditProvider(_ provider: AiProvider) {
        providerForm = provider
        isEditingProvider = true
    }

    func changeProviderKind(_ kind: ProviderKind) {
        providerForm.kind = kind
        providerForm.endpoint = kind.defaultEndpoint
        providerForm.model = kind.defaultModels.first ?? ""
        if providerForm.name.isEmpty {
            providerForm.name = kind.label
        }
    }

    func saveProvider() {
        guard !providerForm.name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try providerRepo.upsert(providerForm)
            fetchAll()
            isEditingProvider = false
        } catch {
            print("Failed to save provider: \(error)")
        }
    }

    func deleteProvider(_ id: String) {
        do {
            try providerRepo.delete(id: id)
            fetchAll()
        } catch {
            print("Failed to delete provider: \(error)")
        }
    }

    // MARK: - Template operations

    func startAddTemplate() {
        templateForm = Template(id: "tpl-\(Int(Date().timeIntervalSince1970))")
        isEditingTemplate = true
    }

    func startEditTemplate(_ template: Template) {
        templateForm = template
        isEditingTemplate = true
    }

    func saveTemplate() {
        guard !templateForm.name.trimmingCharacters(in: .whitespaces).isEmpty,
              !templateForm.prompt.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            if let shortcut = templateForm.shortcut, shortcut.trimmingCharacters(in: .whitespaces).isEmpty {
                templateForm.shortcut = nil
            }
            try templateRepo.upsert(templateForm)
            fetchAll()
            isEditingTemplate = false
            onTemplatesChanged?()
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    func deleteTemplate(_ id: String) {
        do {
            try templateRepo.delete(id: id)
            fetchAll()
            onTemplatesChanged?()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }
}
