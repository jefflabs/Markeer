import AppKit
import Foundation

/// Local-model chat client. Uses the Ollama HTTP API (OpenAI-compatible enough for this purpose).
/// All requests stay on the local network; no cloud is used.
final class AskAI {
    static let shared = AskAI()

    private let baseURL: URL
    private let defaultModel = "llama3.2:1b"

    init(baseURL: URL = URL(string: "http://localhost:11434/api/chat")!) {
        self.baseURL = baseURL
    }

    func isOllamaReachable(timeout: TimeInterval = 2) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { reachable = true }
            semaphore.signal()
        }.resume()
        semaphore.wait(timeout: .now() + timeout)
        return reachable
    }

    /// Synchronous variant for headless tests.
    func askBlocking(prompt: String, context: String, model: String = "llama3.2:1b") -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        ask(prompt: prompt, context: context, model: model) { result in
            if case .success = result { ok = true }
            semaphore.signal()
        }
        semaphore.wait(timeout: .now() + 15)
        return ok
    }

    func ask(prompt: String, context: String, model: String = "llama3.2:1b", completion: @escaping (Result<String, Error>) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        let systemPrompt = "Je bent een assistent die schrijft en aanpast bij een document. Antwoord kort en behulpzaam in dezelfde taal als het document."
        let userContent = "Documentcontext:\n\(context)\n\nVraag: \(prompt)"
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent]
            ],
            "stream": false
        ]
        do { request.httpBody = try JSONSerialization.data(withJSONObject: body) } catch {
            completion(.failure(error)); return
        }
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(NSError(domain: "AskAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ongeldige response van het lokale model"]))); return
            }
            if let msg = (json["message"] as? [String: Any])?["content"] as? String {
                completion(.success(msg))
            } else {
                completion(.failure(NSError(domain: "AskAI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Geen tekst in antwoord"])))
            }
        }.resume()
    }
}
