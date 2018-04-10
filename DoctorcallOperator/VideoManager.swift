//
//  VideoManager.swift
//  DoctorcallOperator
//
//  Created by Nikita on 11.07.16.
//  Copyright © 2016 Nikita. All rights reserved.
//

import CoreAudioKit
import AVFoundation

func checkAudioStatus(let status : Int32){
    if (status != 0) {
        print("Status not 0! %d\n", status);
    }
}

class VideoManager : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    static let sharedInstance = VideoManager()
    
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    var assetWriterInput: AVAssetWriterInput?
    var assetAudioInput : AVAssetWriterInput?
    var assetWriter: AVAssetWriter?
    var frameNumber: Int64 = 0
    var qbDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    
    let session = AVCaptureSession()
    
    func startSavingCaptureToFileWithURL(url: NSURL, capture: QBRTCCameraCapture) {
        session.sessionPreset = AVCaptureSessionPresetMedium
        
        let mic = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
        var mic_input: AVCaptureDeviceInput!
        
        let audio_output = AVCaptureAudioDataOutput()
        
        audio_output.setSampleBufferDelegate(self, queue: dispatch_get_main_queue())
        
        do
        {
            mic_input = try AVCaptureDeviceInput(device: mic)
        }
        catch
        {
            return
        }
        
        session.addInput(mic_input)
        session.addOutput(audio_output)
        
        session.startRunning()
        
        
        guard let dataOutput = getVideoCaptureDataOutput(capture) else { return }
        
        frameNumber = 0
        
        qbDelegate = dataOutput.sampleBufferDelegate
        dataOutput.setSampleBufferDelegate(self, queue: dataOutput.sampleBufferCallbackQueue)
        
        let outputSettings: [String : AnyObject] = [
            AVVideoWidthKey : 720,
            AVVideoHeightKey: 960,
            AVVideoCodecKey : AVVideoCodecH264
        ]
        let audioSettings: [String : AnyObject] = [
            AVSampleRateKey : 44100.00,
            AVFormatIDKey : Int(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey : 1,
        ]
        
        assetWriterInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: outputSettings)
        assetAudioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioSettings)
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(unsignedInt: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)])
        
        do {
            assetWriter = try AVAssetWriter(URL: url, fileType: AVFileTypeMPEG4)
            assetWriter!.addInput(assetWriterInput!)
            assetWriter!.addInput(assetAudioInput!)
            assetWriterInput!.expectsMediaDataInRealTime = true
            assetAudioInput!.expectsMediaDataInRealTime = true
            
            assetWriter!.startWriting()
            assetWriter!.startSessionAtSourceTime(kCMTimeZero)
        }
        catch {
            print("Error")
        }
        
    }
    
    func stopSavingVideo(completion: () -> Void) {
        self.session.stopRunning()
        assetWriter?.finishWritingWithCompletionHandler { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.frameNumber = 0
            
            completion()
        }
    }
    
    func getVideoCaptureDataOutput(videoCapture: QBRTCCameraCapture) -> AVCaptureVideoDataOutput? {
        var output: AVCaptureVideoDataOutput?
        videoCapture.captureSession.outputs.forEach{ captureOutput in
            if captureOutput is AVCaptureVideoDataOutput {
                output = captureOutput as? AVCaptureVideoDataOutput
            }
        }
        return output
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        let a = connection.inputPorts[0]
        if (a.mediaType == "vide") {
            qbDelegate?.captureOutput?(captureOutput, didOutputSampleBuffer: sampleBuffer, fromConnection: connection)
        
            guard let assetWriterInput = assetWriterInput else { return }
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
            if assetWriterInput.readyForMoreMediaData && assetWriter?.status != AVAssetWriterStatus.Unknown {
                pixelBufferAdaptor?.appendPixelBuffer(imageBuffer, withPresentationTime: CMTimeMake(frameNumber, 25))
            }
        
            frameNumber += 1
        }
        else if(a.mediaType == "soun") {
            guard let assetAudioInput = assetAudioInput else { return }

            let framesToProcess : CMItemCount = CMSampleBufferGetNumSamples(sampleBuffer) //8192
            let sampleRate : Int32 = 44100
            var monoStreamFormat : AudioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: 44100.00, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
            
            
            var format : CMFormatDescriptionRef?
            var status : OSStatus = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &monoStreamFormat, 0,nil, 0, nil, nil, &format);
            if (status != noErr) {
                return
            }
            
            var timing : CMSampleTimingInfo = CMSampleTimingInfo(duration: CMTimeMake(1, sampleRate), presentationTimeStamp: kCMTimeZero, decodeTimeStamp: kCMTimeInvalid)
            
            
            var sampleBufferOut : CMSampleBufferRef?
            status = CMSampleBufferCreate(kCFAllocatorDefault, nil, false, nil, nil, format, framesToProcess, 1, &timing, 0, nil, &sampleBufferOut)
            
            status = CMSampleBufferSetDataBuffer(sampleBufferOut!, CMSampleBufferGetDataBuffer(sampleBuffer)!)
            
            if assetAudioInput.readyForMoreMediaData && assetWriter?.status != AVAssetWriterStatus.Unknown {
                if (assetAudioInput.appendSampleBuffer(sampleBufferOut!))
                {
                    NSLog("OK")
                }
                else {
                    NSLog("Not ok")
                }
            }
        }
    }
}
