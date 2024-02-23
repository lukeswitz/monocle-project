//
//  AVAudioPCMBuffer+Extensions.swift
//  Noa
//
//  Created by Bart Trzynadlowski on 5/20/23.
//

import AVFoundation
import Accelerate

extension AVAudioPCMBuffer
{
    public static func fromMonoInt16Data(_ data: Data, sampleRate: Int) -> AVAudioPCMBuffer? {
        // Allocate buffer
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(data.count) / format.streamDescription.pointee.mBytesPerFrame) else {
            return nil
        }
        
        // Get the underlying memory for the PCM buffer and copy data into it
        guard let destSamples = buffer.int16ChannelData else {
            return nil
        }
        let destPtr = UnsafeMutableBufferPointer(start: destSamples.pointee, count: Int(buffer.frameCapacity))
        destPtr.withMemoryRebound(to: UInt8.self) { destBytes -> Void in
            // Now we have the destination as a byte buffer and can copy from the data buffer
            _ = data.copyBytes(to: destBytes)
        }
        buffer.frameLength = buffer.frameCapacity
        // Before returning the buffer, apply audio processing optimized for spoken word clarity
        buffer.applyRefinedNoiseGate(threshold: 0.01) // Lower threshold to remove background noise while preserving soft speech
        buffer.applyRefinedDynamicRangeCompression(threshold: 0.15, ratio: 4.0) // Gentle compression for maintaining natural vocal dynamics
        return buffer
    }
    
    public static func fromMonoInt8Data(_ data: Data, sampleRate: Int) -> AVAudioPCMBuffer? {
        // Allocate buffer
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(sampleRate), channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count)) else {
            return nil
        }
        
        // Get the underlying memory for the PCM buffer and store samples converted from signed 8-
        // bit to signed 16-bit in it
        guard let destSamples = buffer.int16ChannelData else {
            return nil
        }
        let destPtr = UnsafeMutableBufferPointer(start: destSamples.pointee, count: Int(buffer.frameCapacity))
        destPtr.withMemoryRebound(to: Int16.self) { destWords -> Void in
            for i in 0..<data.count {
                // Interpret each byte as a signed 8-bit value and shift left 8 bits for Int16
                let sample = Int8(bitPattern: data[i])
                let sample16 = Int16(sample) << 8
                destWords[i] = sample16
            }
        }
        
        buffer.frameLength = buffer.frameCapacity
        return buffer
    }
    
    
    // Refined noise gate
        func applyRefinedNoiseGate(threshold: Float = 0.02) {
            guard let channelData = floatChannelData else { return }
            let frameLength = Int(self.frameLength)
            for channel in 0..<Int(format.channelCount) {
                let signal = channelData[channel]
                for index in 0..<frameLength {
                    signal[index] = abs(signal[index]) > threshold ? signal[index] : 0
                }
            }
        }

        // Dynamic range compression
        func applyRefinedDynamicRangeCompression(threshold: Float = 0.25, ratio: Float = 2.0) {
            guard let channelData = floatChannelData else { return }
            let frameLength = Int(self.frameLength)
            let linearThreshold = pow(10.0, threshold / 20.0)
            for channel in 0..<Int(format.channelCount) {
                let signal = channelData[channel]
                for index in 0..<frameLength {
                    let magnitude = abs(signal[index])
                    if magnitude > linearThreshold {
                        let overThreshold = magnitude - linearThreshold
                        let compressedMagnitude = linearThreshold + overThreshold / ratio
                        signal[index] = signal[index] > 0 ? compressedMagnitude : -compressedMagnitude
                    }
                }
            }
        }
    
    public func convertToCMSampleBuffer(presentationTimeStamp: CMTime? = nil) -> CMSampleBuffer? {
        if self.frameLength == 0 {
            // Procedure below does not work for zero-length buffers
            return nil
        }
        
        // https://gist.github.com/aibo-cora/c57d1a4125e145e586ecb61ebecff47c
        let pcmBuffer = self
        let audioBufferList = pcmBuffer.mutableAudioBufferList
        let asbd = pcmBuffer.format.streamDescription
        
        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil
        
        var status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        )
        
        if (status != noErr) {
            return nil
        }
        
        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
            presentationTimeStamp: presentationTimeStamp ?? CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: CMTime.invalid
        )
        
        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(pcmBuffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        if (status != noErr) {
            print("[AVAudioPCMBuffer] CMSampleBufferCreate failed: \(status)")
            return nil
        }
        
        status = CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: audioBufferList
        )
        
        if (status != noErr) {
            print("[AVAudioPCMBuffer] CMSampleBufferSetDataBufferFromAudioBufferList failed: \(status)")
            return nil
        }
        
        return sampleBuffer
    }
}

