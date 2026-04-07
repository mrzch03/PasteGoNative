import Foundation

/// A chunk of streaming AI output
struct StreamChunk {
    let content: String
    let done: Bool
}

/// Service for streaming AI generation from various providers
final class AIStreamingService {
    /// Stream a generation request, yielding chunks as they arrive
    func generate(provider: AiProvider, prompt: String) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    switch provider.kind {
                    case .openai, .kimi, .minimax:
                        try await streamOpenAI(
                            endpoint: provider.endpoint, model: provider.model,
                            apiKey: provider.apiKey, prompt: prompt, continuation: continuation
                        )
                    case .claude:
                        try await streamClaude(
                            endpoint: provider.endpoint, model: provider.model,
                            apiKey: provider.apiKey, prompt: prompt, continuation: continuation
                        )
                    case .ollama:
                        try await streamOllama(
                            endpoint: provider.endpoint, model: provider.model,
                            prompt: prompt, continuation: continuation
                        )
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - OpenAI-compatible streaming (OpenAI, Kimi, MiniMax)

    private func streamOpenAI(endpoint: String, model: String, apiKey: String,
                              prompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        let url = URL(string: "\(endpoint.trimmingSuffix("/"))/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw AIError.apiError(httpResponse.statusCode, errorBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            if data == "[DONE]" {
                continuation.yield(StreamChunk(content: "", done: true))
                continuation.finish()
                return
            }

            if let jsonData = data.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                continuation.yield(StreamChunk(content: content, done: false))
            }
        }

        continuation.yield(StreamChunk(content: "", done: true))
        continuation.finish()
    }

    // MARK: - Claude (Anthropic) streaming

    private func streamClaude(endpoint: String, model: String, apiKey: String,
                              prompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        let url = URL(string: "\(endpoint.trimmingSuffix("/"))/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [["role": "user", "content": prompt]],
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw AIError.apiError(httpResponse.statusCode, errorBody)
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))

            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let eventType = json["type"] as? String else { continue }

            switch eventType {
            case "content_block_delta":
                if let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    continuation.yield(StreamChunk(content: text, done: false))
                }
            case "message_stop":
                continuation.yield(StreamChunk(content: "", done: true))
                continuation.finish()
                return
            default:
                break
            }
        }

        continuation.yield(StreamChunk(content: "", done: true))
        continuation.finish()
    }

    // MARK: - Ollama streaming

    private func streamOllama(endpoint: String, model: String,
                              prompt: String, continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation) async throws {
        let url = URL(string: "\(endpoint.trimmingSuffix("/"))/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw AIError.apiError(httpResponse.statusCode, errorBody)
        }

        for try await line in bytes.lines {
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            if let responseText = json["response"] as? String {
                continuation.yield(StreamChunk(content: responseText, done: false))
            }
            if json["done"] as? Bool == true {
                continuation.yield(StreamChunk(content: "", done: true))
                continuation.finish()
                return
            }
        }

        continuation.yield(StreamChunk(content: "", done: true))
        continuation.finish()
    }
}

enum AIError: LocalizedError {
    case apiError(Int, String)
    case noProvider

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body):
            "API error \(code): \(body)"
        case .noProvider:
            "No AI provider configured. Please add one in Settings."
        }
    }
}

private extension String {
    func trimmingSuffix(_ suffix: String) -> String {
        if hasSuffix(suffix) {
            return String(dropLast(suffix.count))
        }
        return self
    }
}
