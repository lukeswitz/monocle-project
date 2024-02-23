//
//  AudioEnhancer.swift
//  third eye 
//
//  Created by Luke Switzer on 2024-02-23.
//  Copyright © 2024 Root Down Digital. All rights reserved.
//


import AVFoundation
import Accelerate

class AudioEnhancer {

    func enhanceAudio(fileURL: URL, completion: @escaping (Bool, URL?) -> Void) {
        guard let inputFile = try? AVAudioFile(forReading: fileURL),
              let processingFormat = AVAudioFormat(standardFormatWithSampleRate: inputFile.fileFormat.sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: AVAudioFrameCount(inputFile.length)),
              let floatChannelData = buffer.floatChannelData?.pointee else {
            completion(false, nil)
            return
        }

        do {
            try inputFile.read(into: buffer)
        } catch {
            completion(false, nil)
            return
        }

        // Apply DSP techniques
        noiseGate(signal: floatChannelData, frameLength: buffer.frameLength)
        applyBandPassFilter(signal: floatChannelData, sampleRate: processingFormat.sampleRate, frameLength: buffer.frameLength)
        
        // Assuming a simplistic dynamic range compression for demonstration
        dynamicRangeCompression(signal: floatChannelData, frameLength: buffer.frameLength)

        // Save the processed audio to a new file
        saveProcessedBuffer(buffer, originalFileURL: fileURL, completion: completion)
    }

    // Simple Noise Gate
    private func noiseGate(signal: UnsafeMutablePointer<Float>, frameLength: AVAudioFrameCount) {
        let threshold: Float = 0.01 // Adjust based on your needs
        for i in 0..<Int(frameLength) {
            signal[i] = (abs(signal[i]) > threshold) ? signal[i] : 0
        }
    }
    
    // Band-Pass Filter
    private func applyBandPassFilter(signal: UnsafeMutablePointer<Float>, sampleRate: Double, frameLength: AVAudioFrameCount) {
        let n = Int(frameLength)
        var processedSignal = [Float](repeating: 0, count: n)
        
        // Define filter stuff
        let lowPassFilterOrder = 2
        let nyquist = 0.5 * sampleRate
        let lowCutoffFrequency = 300.0 / nyquist
        let highCutoffFrequency = 3400.0 / nyquist
        
        var coefficients = [Float](repeating: 0, count: 5)
        vDSP_biquad_CreateBandPass2(lowFrequency: lowCutoffFrequency, highFrequency: highCutoffFrequency, sampleRate: Float(sampleRate), singlePrecision: Float.self, coefficients: &coefficients)
        
        // Add the filter
        var state = vDSP_biquad_State(singlePrecision: Float.self, coefficients: coefficients, channels: 1)
        vDSP_biquad(&state, signal, 1, &processedSignal, 1, vDSP_Length(n - lowPassFilterOrder))
        
        // Copy processed signal back
        for i in 0..<n {
            signal[i] = processedSignal[i]
        }
    }
    
    // Dynamic Range Compression
    private func dynamicRangeCompression(signal: UnsafeMutablePointer<Float>, frameLength: AVAudioFrameCount) {
        // Placeholder for dynamic range compression algorithm - signal amplitude based on a threshold we decide is ok
    }
    
				// Save the enhanced audio file
    private func saveProcessedBuffer(_ buffer: AVAudioPCMBuffer, originalFileURL: URL, completion: @escaping (Bool, URL?) -> Void) {
        let outputURL = originalFileURL.deletingLastPathComponent().appendingPathComponent("enhanced_\(originalFileURL.lastPathComponent)")
        do {
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: buffer.format.settings)
            try outputFile.write(from: buffer)
            completion(true, outputURL)
        } catch {
            completion(false, nil)
        }
    }
}
