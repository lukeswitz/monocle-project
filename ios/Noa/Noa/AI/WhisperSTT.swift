//
//  SpeechToText.swift
//  Noa
//
//  Created by Luke on 2/1/24.
//

import Foundation
import AVFoundation

public class WhisperSTT: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private var recordingURL: URL?
    
    // Initialize apiKey with a default value
    private var apiKey: String = UserDefaults.standard.string(forKey: "k_openAIKey") ?? ""
    
    public override init() {
        super.init()
        setupAudioRecorder()
        
        // Register observer for the OpenAI API key changes
        NotificationCenter.default.addObserver(self, selector: #selector(apiKeyChanged), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc private func apiKeyChanged(notification: NSNotification) {
        // Update the API key if it changes
        apiKey = UserDefaults.standard.string(forKey: "k_openAIKey") ?? ""
        print("Updated API Key: \(apiKey)")
    }
    
    private func setupAudioRecorder() {
        let fileName = "recording.wav"
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentPath.appendingPathComponent(fileName)
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
        } catch {
            print("Failed to set up the audio recorder: \(error)")
        }
    }
    
    public func startRecording() {
        do {
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            audioRecorder?.record()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    public func stopRecording() {
        audioRecorder?.stop()
        try? audioSession.setActive(false)
        sendAudioToWhisper()
    }
    
    private func sendAudioToWhisper() {
        guard let audioURL = recordingURL else {
            print("Audio file URL is not available.")
            return
        }
        
        guard let audioData = try? Data(contentsOf: audioURL) else {
            print("Failed to load audio data.")
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/whisper")! // Correct API endpoint
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type") // Assuming JSON; adjust based on actual requirements
        
        // Audio data needs to be base64 encoded to be embedded in a JSON payload
        let base64Audio = audioData.base64EncodedString()
        let jsonPayload: [String: Any] = [
            "model": "whisper-1", // Specify the model
            "audio": base64Audio, // Embed the base64 encoded audio
            "language": "en" // Optionally specify the language, if required by the API
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonPayload)
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                    print("Error during the network request: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Parse the JSON response to extract the transcribed text
                do {
                    if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let text = jsonResult["text"] as? String {
                        print("Transcribed text: \(text)")
                        // Here you can use a completion handler or a delegate to return the transcribed text
                    } else {
                        print("Failed to decode the response.")
                    }
                } catch {
                    print("Error parsing the response data: \(error.localizedDescription)")
                }
            }
            
            task.resume()
        } catch {
            print("Failed to create JSON payload: \(error.localizedDescription)")
        }
    }

}

