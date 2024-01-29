// SpeechToTextlator.swift
// Noa
//
// Created by Luke on 1/26/24.
//

import Foundation
import UIKit

class SpeechToTextTranslator: NSObject {
    public enum NetworkConfiguration {
        case normal
        case backgroundData
        case backgroundUpload
    }
    
    private var session: URLSession!
    private var completionByTask: [Int: (String, AIError?) -> Void] = [:]
    private var tempFileURL: URL?
    
    public init(configuration: NetworkConfiguration) {
        super.init()
        
        switch configuration {
        case .normal:
            session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        case .backgroundUpload:
            tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
            fallthrough
        case .backgroundData:
            let configuration = URLSessionConfiguration.background(withIdentifier: "SpeechToText-\(UUID().uuidString)")
            configuration.isDiscretionary = false
            configuration.shouldUseExtendedBackgroundIdleMode = true
            configuration.sessionSendsLaunchEvents = true
            configuration.allowsConstrainedNetworkAccess = true
            configuration.allowsExpensiveNetworkAccess = true
            session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
    }
    
    public func transcribeAudio(fileData: Data, format: Whisper.AudioFormat, completion: @escaping (String, AIError?) -> Void) {
        let url = URL(string: "https://api.openai.com/v1/engines/whisper-1/transcribe")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(brilliantAPIKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonBody: [String: Any] = [
            "audio": fileData.base64EncodedString(),
            "model": "gpt-3.5-turbo" // Replace with your desired model name
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: jsonBody)
        
        request.httpBody = jsonData
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion("", AIError.clientSideNetworkError(error: error))
                }
                return
            }
            let (contentError, transcript) = self.extractContent(from: data)
            DispatchQueue.main.async {
                completion(transcript ?? "", contentError)
            }
        }
        task.resume()
    }
    
    private func extractContent(from data: Data) -> (AIError?, String?) {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return (nil, response.transcript)
        } catch {
            return (AIError.responsePayloadParseError, nil)
        }
    }
}

extension SpeechToTextTranslator: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (_, completion) in self.completionByTask {
                completion("", AIError.clientSideNetworkError(error: error))
            }
            self.completionByTask = [:]
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Handle session completion
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}

extension SpeechToTextTranslator: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let (contentError, transcript) = extractContent(from: data)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self.completionByTask[dataTask.taskIdentifier] {
                completion(transcript ?? "", contentError)
                self.completionByTask.removeValue(forKey: dataTask.taskIdentifier)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self.completionByTask[task.taskIdentifier] {
                completion("", AIError.clientSideNetworkError(error: error))
                self.completionByTask.removeValue(forKey: task.taskIdentifier)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(URLSession.ResponseDisposition.allow)
    }
}

struct OpenAIResponse: Decodable {
    let transcript: String
}
