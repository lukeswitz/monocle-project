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

    // MARK: Process Audio File
    func processAudio(inputURL: URL, outputURL: URL) {
        guard let inputFile = try? AVAudioFile(forReading: inputURL),
              let format = inputFile.processingFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(inputFile.length)),
              let floatChannelData = buffer.floatChannelData else {
            print("Error: Unable to load audio file.")
            return
        }

        do {
            try inputFile.read(into: buffer)
        } catch {
            print("Error: Unable to read audio file. \(error.localizedDescription)")
            return
        }

        let frameLength = vDSP_Length(buffer.frameLength)
        let sampleRate = Float(format.sampleRate)
        
        // Using mono, process audio
        var signal = [Float](repeating: 0, count: Int(frameLength))
        memcpy(&signal, floatChannelData[0], Int(frameLength) * MemoryLayout<Float>.size)
        
        // Apply Band-Pass Filter
        bandPassFilter(signal: &signal, sampleRate: sampleRate, lowCutoff: 300, highCutoff: 3400)
								
								// Apply EQ
								applyEqualization(signal: &signal, sampleRate: sampleRate)
								
								// Apply Noise gate filter
								noiseGate(signal: floatChannelData, frameLength: frameLength)
        
        // Apply Dynamic Range Compression
					 	dynamicRangeCompression(signal: &signal, threshold: -20, ratio: 4.0)
        
        // Copy processed signal back to the buffer
        memcpy(floatChannelData[0], signal, Int(frameLength) * MemoryLayout<Float>.size)

        // Save the processed audio to a new file
        let outputDestinationURL = fileURL.deletingLastPathComponent().appendingPathComponent("enhanced_\(fileURL.lastPathComponent)")
        do {
            let outputFile = try AVAudioFile(forWriting: outputDestinationURL, settings: buffer.format.settings)
            try outputFile.write(from: buffer)
            completion(true, outputDestinationURL)
        } catch {
            completion(false, nil)
        }
    }

    // Noise Gate
    private func noiseGate(signal: UnsafeMutablePointer<Float>, frameLength: AVAudioFrameCount) {
        let threshold: Float = 0.01
        for i in 0..<Int(frameLength) {
            signal[i] = (abs(signal[i]) > threshold) ? signal[i] : 0
        }
    }
    
    // Band-Pass Filter
    private func bandPassFilter(signal: UnsafeMutablePointer<Float>, sampleRate: Double, frameLength: AVAudioFrameCount) {
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
				
				// EQ
				func applyEqualization(signal: inout [Float], sampleRate: Float) {
    let midFrequency = 1000.0 // 1 kHz for speech clarity
    let Q = 0.707 // Quality factor for peaking EQ
    let gainDB = 3.0 // Gain in dB
    
    // Calculate coefficients for peaking EQ
    let coefficients = calculatePeakingEQCoefficients(sampleRate: sampleRate, frequency: midFrequency, gain: gainDB, Q: Q)
    
    // Apply EQ filter
    var biquadSetup = vDSP_biquadm_CreateSetup(coefficients, 1)!
    var state = vDSP_biquadm_CreateState(biquadSetup)!
    vDSP_biquadm_Apply(biquadSetup, state, &signal, &signal, vDSP_Length(signal.count))
    
    // Cleanup
				vDSP_biquadm_DestroySetup(biquadSetup)
    vDSP_biquadm_DestroyState(state)
    }

    // Dynamic Range Compression
    private func dynamicRangeCompression(signal: inout [Float], threshold: Float, ratio: Float) {
        let linearThreshold = pow(10.0, threshold / 20.0)
        
        for i in 0..<signal.count {
            let magnitude = abs(signal[i])
            if magnitude > linearThreshold {
                let overThreshold = magnitude - linearThreshold
                let compressedMagnitude = linearThreshold + overThreshold / ratio
                signal[i] = signal[i] > 0 ? compressedMagnitude : -compressedMagnitude
            }
        }
    }
}
