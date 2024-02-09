import AVFoundation
import Foundation

class M4AWriter: NSObject, AVAssetWriterDelegate {
    private let _temporaryDirectory: URL
    private var assetWriter: AVAssetWriter?
    private let writingQueue = DispatchQueue(label: "com.noa.m4awriter.queue")
    private var currentFileURL: URL?

    override init() {
        _temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        super.init()
    }

    deinit {
        // Clean up the last file created
        if let currentFileURL = currentFileURL {
            delete(file: currentFileURL)
        }
    }

    public func write(buffer: AVAudioPCMBuffer, completion: @escaping (Data?) -> Void) {
        writingQueue.async {
            self.setupAssetWriter(for: buffer, completion: completion)
        }
    }

    private func load(file url: URL, completion: @escaping (Data?) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let data = try? Data(contentsOf: url)
            DispatchQueue.main.async {
                completion(data)
            }
        }
    }

    private func setupAssetWriter(for buffer: AVAudioPCMBuffer, completion: @escaping (Data?) -> Void) {
        guard let cmSampleBuffer = buffer.convertToCMSampleBuffer() else {
            DispatchQueue.main.async {
                print("[M4AWriter] Error: Unable to convert PCM buffer to CMSampleBuffer")
                completion(nil)
            }
            return
        }

        let file = getFileURL()
        currentFileURL = file

        do {
            assetWriter = try AVAssetWriter(outputURL: file, fileType: .m4a)
        } catch {
            DispatchQueue.main.async {
                print("[M4AWriter] Error: Unable to create asset writer: \(error.localizedDescription)")
                completion(nil)
            }
            return
        }

        guard let assetWriter = assetWriter else { return }

        assetWriter.shouldOptimizeForNetworkUse = true

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128000
        ]

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        assetWriter.add(audioInput)

        guard assetWriter.startWriting() else {
            DispatchQueue.main.async {
                print("[M4AWriter] Error: Unable to start writing: \(assetWriter.error?.localizedDescription ?? "unknown error")")
                completion(nil)
            }
            return
        }

        assetWriter.startSession(atSourceTime: .zero)
        audioInput.append(cmSampleBuffer)
        audioInput.markAsFinished()
        
        assetWriter.finishWriting { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if assetWriter.status == .completed {
                    print("[M4AWriter] Created m4a file successfully")
                    self.load(file: file, completion: completion)
                    self.delete(file: file)
                    self.currentFileURL = nil // Clear the current file URL after deletion
                } else if assetWriter.status == .failed {
                    print("[M4AWriter] Error: Failed to create m4a file: \(assetWriter.error?.localizedDescription ?? "unknown error") \(assetWriter.status)")
                    completion(nil)
                } else {
                    print("[M4AWriter] Error: Failed to create m4a file")
                    completion(nil)
                }
            }
        }
    }

    private func getFileURL() -> URL {
        return _temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }

    private func delete(file url: URL) {
        DispatchQueue.global(qos: .background).async {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("[M4AWriter] Error: Unable to delete temporary file: \(url)")
            }
        }
    }
}
