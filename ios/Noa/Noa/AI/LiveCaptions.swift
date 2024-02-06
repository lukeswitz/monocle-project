import SwiftUI
import Speech

struct LiveCaptions: View {
    @State private var textListen = "Start speaking..."
    @State private var btnStr = ""
    @State private var isListening = false
    @State private var speechRec = SpeechRecognizer()
    
    private let speechRecognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    
    var body: some View {
        VStack {
            ScrollView {
                if isListening {
                    Text(textListen).padding()
                } else {
                    Text(btnStr).padding()
                }
            }
            Button(isListening ? "Stop Listening" : "Begin Listening") {
                self.toggleListening()
            }.onAppear {
                self.requestSpeechAuthorization()
            }
            
        }
    }
    
    func requestSpeechAuthorization(){
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized.")
                default:
                    print("Speech recognition not authorized.")
                }
            }
        }
    }

    @MainActor public func startListening() throws {
        speechRec.startTranscribing()
        isListening = true
    }

    @MainActor public func stopListening() {
        speechRec.stopTranscribing()
        isListening = false
    }
    

    @MainActor private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            try? startListening()
        }
    }
}
