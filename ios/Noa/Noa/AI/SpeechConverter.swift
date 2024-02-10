//
//  SpeechConverter.swift
//  Noa
//
//  Created by Luke on 2/10/24.
//

import AVFoundation
import Speech
import UIKit

class SpeechToTextConverter: NSObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechURLRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    func convert(fileURL: URL, withCompletion completion: @escaping (Result<String, Error>) -> Void) {
        // First, request authorization
        requestAuthorization { [weak self] authorized in
            guard authorized else {
                completion(.failure(NSError(domain: "SpeechToTextConverter", code: -1, userInfo: [NSLocalizedDescriptionKey: "User did not authorize speech recognition."])))
                return
            }
            self?.startConversion(fileURL: fileURL, completion: completion)
        }
    }
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    self.promptToEnablePermissions(message: "Speech recognition authorization was denied or not determined. Please enable it in Settings to continue.")
                    completion(false)
                @unknown default:
                    print("Unknown speech recognition authorization status.")
                    completion(false)
                }
            }
        }
    }
    
    private func startConversion(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest = SFSpeechURLRecognitionRequest(url: fileURL)
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(NSError(domain: "SpeechToTextConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create a recognition request."])))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = false
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result else {
                completion(.failure(NSError(domain: "SpeechToTextConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No recognition result."])))
                return
            }
            
            if result.isFinal {
                completion(.success(result.bestTranscription.formattedString))
            }
        }
    }
    
    private func promptToEnablePermissions(message: String) {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        DispatchQueue.main.async {
            // Find the active window scene
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return
            }
            
            // Find the key window from the active window scene
            guard let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(title: "Speech Recognition Permission", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Go to Settings", style: .default) { _ in
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            rootViewController.present(alert, animated: true, completion: nil)
        }
    }
    
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("Speech recognition is available")
        } else {
            print("Speech recognition is not available")
        }
    }
}
