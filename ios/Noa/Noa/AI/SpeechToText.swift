//
//  SpeechToText.swift
//  Noa
//
//  Created by Luke on 1/27/24.

//  Created by Bart Trzynadlowski on 5/24/23.
//
//  OpenAI Whisper-based translation (speech -> text).
//

import UIKit

class SpeechToText: NSObject {
    public enum NetworkConfiguration {
        case normal
        case backgroundData
        case backgroundUpload
    }

    public enum AudioFormat: String {
        case wav = "wav"
        case m4a = "m4a"
    }

    private var _session: URLSession!
        private var _completionByTask: [Int: (String, AIError?) -> Void] = [:]

    public override init() {
            super.init()
            _session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        }

        public func transcribe(fileData: Data, format: AudioFormat, completion: @escaping (String, AIError?) -> Void) {
            let url = URL(string: "https://api.openai.com/v1/audio/transcriptions/whisper-1")! // Replace with the actual Whisper API URL
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(brilliantAPIKey)", forHTTPHeaderField: "Authorization") // Replace with your OpenAI API Key

            // Attach audio data
            request.httpBody = fileData
            request.setValue("audio/\(format.rawValue)", forHTTPHeaderField: "Content-Type")

            // Create and start the task
            let task = _session.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    completion("", AIError.clientSideNetworkError(error: error))
                    return
                }
                completion(self.extractTranscript(from: data), nil)
            }
            _completionByTask[task.taskIdentifier] = completion
            task.resume()
        }

        private func extractTranscript(from data: Data) -> String {
            do {
                let response = try JSONDecoder().decode(WhisperResponse.self, from: data)
                return response.transcript
            } catch {
                print("Error parsing response: \(error)")
                return ""
            }
        }
    }

    // Extend this to match the response structure of Whisper API
    struct WhisperResponse: Codable {
        let transcript: String
    }


extension SpeechToText: URLSessionDelegate {
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        let errorMessage = error == nil ? "unknown error" : error!.localizedDescription
        print("[SpeechToText] URLSession became invalid: \(errorMessage)")

        // Deliver error for all outstanding tasks
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            for (_, completion) in self._completionByTask {
                completion("", AIError.clientSideNetworkError(error: error))
            }
            _completionByTask = [:]
        }
    }
    
    private func extractContent(from data: Data) -> (AIError?, String?) {
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return (nil, response.transcript)
        } catch {
            return (AIError.responsePayloadParseError, nil)
        }
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("[SpeechToText] URLSession finished events")
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("[SpeechToText] URLSession received challenge")
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            print("[SpeechToText] URLSession unable to use credential")
        }
    }
}

extension SpeechToText: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
        print("[SpeechToText] URLSessionDataTask became stream task")
        streamTask.resume()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        print("[SpeechToText] URLSessionDataTask became download task")
        downloadTask.resume()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        print("[SpeechToText] URLSessionDataTask received challenge")
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            print("[SpeechToText] URLSessionDataTask unable to use credential")

            // Deliver error
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let completion = self._completionByTask[task.taskIdentifier] {
                    completion("", AIError.urlAuthenticationFailed)
                    self._completionByTask.removeValue(forKey: task.taskIdentifier)
                }
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Original request was redirected somewhere else. Create a new task for redirection.
        if let urlString = request.url?.absoluteString {
            print("[SpeechToText] URLSessionDataTask redirected to \(urlString)")
        } else {
            print("[SpeechToText] URLSessionDataTask redirected")
        }

        // New task
        let newTask = self._session.dataTask(with: request)

        // Replace completion
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self._completionByTask[task.taskIdentifier] {
                self._completionByTask.removeValue(forKey: task.taskIdentifier) // out with the old
                self._completionByTask[newTask.taskIdentifier] = completion     // in with the new
            }
        }

        // Continue with new task
        newTask.resume()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("[SpeechToText] URLSessionDataTask failed to complete: \(error.localizedDescription)")
        } else {
            // Error == nil should indicate successful completion
            print("[SpeechToText] URLSessionDataTask finished")
        }

        // If there really was no error, we should have received data, triggered the completion,
        // and removed the completion. If it's still hanging around, there must be some unknown
        // error or I am interpreting the task lifecycle incorrectly.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self._completionByTask[task.taskIdentifier] {
                completion("", AIError.clientSideNetworkError(error: error))
                self._completionByTask.removeValue(forKey: task.taskIdentifier)
            }
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Assume that regardless of any error (including non-200 status code), the didCompleteWithError
        // delegate method will eventually be called and we can report the error there
        print("[SpeechToText] URLSessionDataTask received response headers")
        guard let response = response as? HTTPURLResponse else {
            print("[SpeechToText] URLSessionDataTask received unknown response type")
            return
        }
        print("[SpeechToText] URLSessionDataTask received response code \(response.statusCode)")
        completionHandler(URLSession.ResponseDisposition.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let (contentError, transcript) = self.extractContent(from: data)
        let transcriptString = transcript ?? "" // if response is nill, contentError will be set

        // Deliver response
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let completion = self._completionByTask[dataTask.taskIdentifier] {
                completion(transcriptString, contentError)
                self._completionByTask.removeValue(forKey: dataTask.taskIdentifier)
            }
        }
    }
    
}


