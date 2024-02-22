import AVFoundation
import Foundation

class M4AWriter: NSObject, AVAssetWriterDelegate {
    private let writingQueue = DispatchQueue(label: "com.noa.m4awriter.queue")
    private var assetWriter: AVAssetWriter?
    private var currentFileURL: URL?
    private var lastFileURL: URL? // Store the last file URL for external access

    private var temporaryDirectory: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }
    
    deinit {
        // Clean up the last file written if it hasn't been manually removed
        if let currentFileURL = self.currentFileURL {
            try? FileManager.default.removeItem(at: currentFileURL)
        }
    }
    
    // Modify the completion handler to return both URL and Data
    public func write(buffer: AVAudioPCMBuffer, completion: @escaping (URL?, Data?) -> Void) {
        guard let cmSampleBuffer = buffer.convertToCMSampleBuffer() else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        self.currentFileURL = fileURL
        
        do {
            self.assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
        } catch {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        guard let assetWriter = self.assetWriter else { return }
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        if assetWriter.canAdd(audioInput) {
            assetWriter.add(audioInput)
        } else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        
        if audioInput.append(cmSampleBuffer) {
            audioInput.markAsFinished()
            
            assetWriter.finishWriting { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if assetWriter.status == .completed {
                        self.lastFileURL = fileURL // Store the last successful file URL
                        // Attempt to load the file data to return
                        do {
                            let fileData = try Data(contentsOf: fileURL)
                            completion(fileURL, fileData)
                        } catch {
                            print("Failed to load file data: \(error)")
                            completion(fileURL, nil) // Return the URL even if Data loading fails
                        }
                    } else {
                        completion(nil, nil)
                    }
                    self.currentFileURL = nil // Reset the current file URL after writing
                }
            }
        } else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
        }
    }
    
    // Method to retrieve the last file URL after successful write operation
    public func getLastFileURL() -> URL? {
        return lastFileURL
    }
}
