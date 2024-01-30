//
//  AIAssistant.swift
//  Noa
//
//  Created by Bart Trzynadlowski on 5/12/23.
//

import UIKit

public class AIAssistant: NSObject {
    // Network configurations for different usage scenarios.
    public enum NetworkConfiguration {
        case normal
        case backgroundData
        case backgroundUpload
    }

    // Modes for different functionalities: assistant or translator.
    public enum Mode {
        case assistant
        case translator
    }

    // Conservative token limit, but can be adjusted based on model capabilities.
    private static var maxTokens = 2000

    // URLSession to manage network requests.
    private var session: URLSession!
    // Dictionary to map tasks to their completion handlers.
    private var completionByTask: [Int: (String, AIError?) -> Void] = [:]
    // URL for temporary file used in background upload tasks.
    private var tempFileURL: URL?

    // Predefined prompts for different modes.
    private static let assistantPrompt = "You are a smart assistant that answers all user queries, questions, and statements with a single sentence."
    private static let translatorPrompt = "You are a smart assistant that translates user input to English. Translate as faithfully as you can and do not add any other commentary."

    // API Payload structure.
    private var payload: [String: Any] = [
        "model": "gpt-3.5-turbo", // Default model, adjustable via init or send method.
        "messages": [[ "role": "system", "content": ""]]
    ]

    // Initializer with network configuration.
    public init(configuration: NetworkConfiguration, model: String = "gpt-3.5-turbo") {
        super.init()
        payload["model"] = model
        configureSession(with: configuration)
    }

    // Configure URLSession based on the network configuration.
    private func configureSession(with configuration: NetworkConfiguration) {
        switch configuration {
        case .normal:
            session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        case .backgroundUpload:
            tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
            fallthrough
        case .backgroundData:
            let config = URLSessionConfiguration.background(withIdentifier: "AIAssistant-\(UUID().uuidString)")
            configureBackgroundSession(config: config)
            session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }
    }

    // Additional configuration for background sessions.
    private func configureBackgroundSession(config: URLSessionConfiguration) {
        config.isDiscretionary = false
        config.shouldUseExtendedBackgroundIdleMode = true
        config.sessionSendsLaunchEvents = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
    }

    // Method to clear the chat history.
    public func clearHistory() {
        if var messages = payload["messages"] as? [[String: String]],
           messages.count > 1 {
            messages.removeSubrange(1..<messages.count)
            payload["messages"] = messages
            print("[AIAssistant] Cleared history")
        }
    }

    // Send method with improved error handling and dynamic model setting.
    public func send(mode: Mode, query: String, apiKey: String, model: String, completion: @escaping (String, AIError?) -> Void) {
        payload["model"] = model
        setSystemPrompt(for: mode)
        appendUserQueryToChatSession(query: query)

        let jsonPayload = try? JSONSerialization.data(withJSONObject: payload)
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Authorization": "Bearer \(apiKey)", "Content-Type": "application/json"]

        prepareAndStartTask(with: request, jsonPayload: jsonPayload, completion: completion)
    }

    // Helper function to prepare and start the URLSession task.
    private func prepareAndStartTask(with request: URLRequest, jsonPayload: Data?, completion: @escaping (String, AIError?) -> Void) {
        var request = request
        request.httpBody = jsonPayload

        let task: URLSessionTask
        if let fileURL = tempFileURL {
            do {
                try jsonPayload?.write(to: fileURL)
                task = session.uploadTask(with: request, fromFile: fileURL)
            } catch {
                completion("", AIError.dataFormatError(message: "Error preparing data for upload: \(error.localizedDescription)")) // Use existing error type
                return
            }
        } else {
            task = session.dataTask(with: request)
        }

        completionByTask[task.taskIdentifier] = completion
        task.resume()
    }

    // Set the system prompt based on the selected mode.
    private func setSystemPrompt(for mode: Mode) {
        if var messages = payload["messages"] as? [[String: String]],
           messages.count >= 1 {
            messages[0]["content"] = mode == .assistant ? Self.assistantPrompt : Self.translatorPrompt
            payload["messages"] = messages
        }
    }

    // Append the user's query to the chat session.
    private func appendUserQueryToChatSession(query: String) {
        if var messages = payload["messages"] as? [[String: String]] {
            messages.append([ "role": "user", "content": "\(query)" ])
            payload["messages"] = messages
        }
    }

    // Append the AI's response to the chat session.
    private func appendAIResponseToChatSession(response: String) {
        if var messages = payload["messages"] as? [[String: String]] {
            messages.append([ "role": "assistant", "content": "\(response)" ])
            payload["messages"] = messages
        }
    }

    // Extract content from the received data with improved error handling.
    private func extractContent(from data: Data) -> (Any?, AIError?, String?) {
        do {
            let jsonString = String(decoding: data, as: UTF8.self)
            print("[AIAssistant] Response payload: \(jsonString)")

            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let response = json as? [String: AnyObject] {
                if let errorPayload = response["error"] as? [String: AnyObject],
                   let errorMessage = errorPayload["message"] as? String {
                    return (json, AIError.apiError(message: errorMessage), nil)
                } else if let choices = response["choices"] as? [AnyObject],
                          let first = choices.first as? [String: AnyObject],
                          let message = first["message"] as? [String: AnyObject],
                          let content = message["content"] as? String {
                    return (json, nil, content)
                }
            }
        } catch {
            print("[AIAssistant] Error: Unable to deserialize response: \(error)")
            return (nil, AIError.responsePayloadParseError, nil)
        }
        return (nil, AIError.apiError(message: "Unknown error occurred"), nil) // Use existing error type
    }

    // Extract total tokens used from the JSON response.
    private func extractTotalTokensUsed(from json: Any?) -> Int {
        if let json = json as? [String: AnyObject],
           let usage = json["usage"] as? [String: AnyObject],
           let totalTokens = usage["total_tokens"] as? Int {
            return totalTokens
        }
        return 0
    }
}

extension AIAssistant: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let errorMessage = error == nil ? "unknown error" : error!.localizedDescription
        print("[AIAssistant] URLSession became invalid: \(errorMessage)")

        // Deliver error for all outstanding tasks
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (_, completion) in completionByTask {
                completion("", AIError.clientSideNetworkError(error: error))
            }
            completionByTask = [:]
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("[AIAssistant] URLSession finished events")
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("[AIAssistant] URLSession received challenge")
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            print("[AIAssistant] URLSession unable to use credential")
        }
    }
}

extension AIAssistant: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        print("[AIAssistant] URLSessionDataTask became stream task")
        streamTask.resume()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print("[AIAssistant] URLSessionDataTask became download task")
        downloadTask.resume()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("[AIAssistant] URLSessionDataTask received challenge")
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            print("[AIAssistant] URLSessionDataTask unable to use credential")

            // Deliver error
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let completion = self.completionByTask[task.taskIdentifier] {
                    completion("", AIError.urlAuthenticationFailed)
                    self.completionByTask.removeValue(forKey: task.taskIdentifier)
                }
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Original request was redirected somewhere else. Create a new task for redirection.
        if let urlString = request.url?.absoluteString {
            print("[AIAssistant] URLSessionDataTask redirected to \(urlString)")
        } else {
            print("[AIAssistant] URLSessionDataTask redirected")
        }

        // New task
        let newTask = self.session.dataTask(with: request)

        // Replace completion
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self.completionByTask[task.taskIdentifier] {
                self.completionByTask.removeValue(forKey: task.taskIdentifier) // out with the old
                self.completionByTask[newTask.taskIdentifier] = completion     // in with the new
            }
        }

        // Continue with new task
        newTask.resume()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[AIAssistant] URLSessionDataTask failed to complete: \(error.localizedDescription)")
        } else {
            // Error == nil should indicate successful completion
            print("[AIAssistant] URLSessionDataTask finished")
        }

        // If there really was no error, we should have received data, triggered the completion,
        // and removed the completion. If it's still hanging around, there must be some unknown
        // error or I am interpreting the task lifecycle incorrectly.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self.completionByTask[task.taskIdentifier] {
                completion("", AIError.clientSideNetworkError(error: error))
                self.completionByTask.removeValue(forKey: task.taskIdentifier)
            }
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Assume that regardless of any error (including non-200 status code), the didCompleteWithError
        // delegate method will eventually be called and we can report the error there
        print("[AIAssistant] URLSessionDataTask received response headers")
        guard let response = response as? HTTPURLResponse else {
            print("[AIAssistant] URLSessionDataTask received unknown response type")
            return
        }
        print("[AIAssistant] URLSessionDataTask received response code \(response.statusCode)")
        completionHandler(URLSession.ResponseDisposition.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let (json, contentError, response) = extractContent(from: data)
        let responseString = response ?? "" // if response is nill, contentError will be set
        let totalTokensUsed = extractTotalTokensUsed(from: json)

        // Deliver response and append to chat session
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Append to chat session to maintain running dialog unless we've exceeded the context
            // window
            if totalTokensUsed >= AIAssistant.maxTokens {
                clearHistory()
                print("[AIAssistant] Cleared context history because total tokens used reached \(totalTokensUsed)")
            } else if let response = response {
                appendAIResponseToChatSession(response: response)
            }

            // Deliver response
            if let completion = self.completionByTask[dataTask.taskIdentifier] {
                completion(responseString, contentError)
                self.completionByTask.removeValue(forKey: dataTask.taskIdentifier)
            } else {
                print("[AIAssistant]: Error: No completion found for task \(dataTask.taskIdentifier)")
            }
        }
    }
}
