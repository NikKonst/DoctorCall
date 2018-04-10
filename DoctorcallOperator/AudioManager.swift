//
//  AudioManager.swift
//  DoctorcallOperator
//
//  Created by Nikita on 03.08.16.
//  Copyright © 2016 Nikita. All rights reserved.
//

import Foundation

func checkStatus(let status : Int32){
    if (status != 0) {
        print("Status not 0! %d\n", status);
    }
}

func recordingCallback(inRefCon:UnsafeMutablePointer<()>,
                       ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                       inTimeStamp:UnsafePointer<AudioTimeStamp>,
                       inBusNumber:UInt32,
                       inNumberFrames:UInt32,
                       ioData:UnsafeMutablePointer<AudioBufferList>) -> Int32 {
    // Because of the way our audio format (setup below) is chosen:
    // we only need 1 buffer, since it is mono
    // Samples are 16 bits = 2 bytes.
    // 1 frame includes only 1 sample
    
    let buffer : AudioBuffer = AudioBuffer.init(mNumberChannels: 1, mDataByteSize: inNumberFrames * 2, mData: UnsafeMutablePointer<Void>.alloc(Int(inNumberFrames * 2)))
    
    // Put buffer in a AudioBufferList
    let bufferList : UnsafeMutablePointer<AudioBufferList> = UnsafeMutablePointer<AudioBufferList>.alloc(1)
    bufferList.memory.mNumberBuffers = 1;
    bufferList.memory.mBuffers = buffer
    //bufferList.mBuffers[0] = buffer;
    
    /*var buffer = [UInt8](count: Int(inNumberFrames * 2), repeatedValue: 0)
    var audioBufferList = AudioBufferList(
        mNumberBuffers: 1,
        mBuffers: AudioBuffer(
            mNumberChannels: 2,
            mDataByteSize: UInt32(inNumberFrames * 2),
            mData: &buffer
        )  
    )*/
    
    //AudioTimeStamp *timeStamp = inTimeStamp;
    
    // Then:
    // Obtain recorded samples
    
    //OSStatus status;
    
    AudioManager.sharedInstance.processAudio(bufferList, inNumberFrames: inNumberFrames, ioActionFlags: ioActionFlags, inTimeStamp: inTimeStamp, inBusNumber: inBusNumber)
    
    //[[AudioHelper sharedInstance] processAudio:&bufferList andFrames:inNumberFrames andIOActionFlags:ioActionFlags andTimeStamp:timeStamp andBunNum:inBusNumber];
    free(bufferList)
    return noErr;
}

class AudioManager {
    var _assetWriterAudioInput : AVAssetWriterInput!
    var _audioUnit : AudioUnit = nil
    var audioInitialized = false
    let kInputBus  = AudioUnitElement(1)
    
    static let sharedInstance = AudioManager()
    
    func start() {
        if (!self.audioInitialized) {
            self.initAudioIO()
            self.audioInitialized = true
        }
        
        let status : OSStatus = AudioOutputUnitStart(_audioUnit);
        checkStatus(status);
    }
    
    func stop() {
        let status : OSStatus = AudioOutputUnitStop(_audioUnit);
        checkStatus(status);
    }
    
    func initAudioIO() {
        var status : OSStatus
        
        // Describe audio component
        var desc : AudioComponentDescription = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO, componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        /*desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;*/
        
        // Get component
        let inputComponent : AudioComponent = AudioComponentFindNext(nil, &desc);
        
        // Get audio units
        status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
        checkStatus(status);
        
        // Enable IO for recording
        var flag : UInt32 = 1;
        status = AudioUnitSetProperty(_audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Input,
                                      kInputBus,
                                      &flag,
                                      UInt32(sizeofValue(flag)));
        checkStatus(status);
        
        // Describe format
        var audioFormat: AudioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: 44100.00, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        /*audioFormat.mSampleRate			= 44100.00;
        audioFormat.mFormatID			= kAudioFormatMPEG4AAC;
        audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket	= 1;
        audioFormat.mChannelsPerFrame	= 1;
        audioFormat.mBitsPerChannel		= 16;
        audioFormat.mBytesPerPacket		= 2;
        audioFormat.mBytesPerFrame		= 2;*/
        
        // Apply format
        status = AudioUnitSetProperty(_audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &audioFormat,
                                      UInt32(sizeofValue(audioFormat)))
        checkStatus(status);
        
        // Set input callback
        var callbackStruct : AURenderCallbackStruct = AURenderCallbackStruct(inputProc: recordingCallback, inputProcRefCon: bridge(self))
        status = AudioUnitSetProperty(_audioUnit,
                                      kAudioOutputUnitProperty_SetInputCallback,
                                      kAudioUnitScope_Global,
                                      kInputBus,
                                      &callbackStruct,
                                      UInt32(sizeofValue(callbackStruct)))
        checkStatus(status);
        
        
        // Disable buffer allocation for the recorder (optional - do this if we want to pass in our own)
        flag = 0;
        status = AudioUnitSetProperty(_audioUnit,
                                      kAudioUnitProperty_ShouldAllocateBuffer,
                                      kAudioUnitScope_Output,
                                      kInputBus,
                                      &flag,
                                      UInt32(sizeofValue(flag)))
        
        // Initialise
        status = AudioUnitInitialize(_audioUnit);    
        checkStatus(status);
    }
    
    
    func processAudio(bufferList : UnsafeMutablePointer<AudioBufferList>, inNumberFrames : UInt32, ioActionFlags : UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp : UnsafePointer<AudioTimeStamp>, inBusNumber : UInt32)  {
        var status : OSStatus
        let framesToProcess : CMItemCount = CMItemCount(inNumberFrames)
        status = AudioUnitRender(_audioUnit,
                                 ioActionFlags,
                                 inTimeStamp,
                                 inBusNumber,
                                 inNumberFrames,
                                 bufferList)
        checkStatus(status)
    
        var sampleBufferOut : CMSampleBufferRef?
        let sampleRate : Int32 = 44100;
        var timeNS  = CMClockGetHostTimeClock()

        var timing : CMSampleTimingInfo = CMSampleTimingInfo(duration: CMTimeMake(1, sampleRate), presentationTimeStamp: kCMTimeZero, decodeTimeStamp: kCMTimeInvalid)
    
        // create description
        //status = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, assetReaderOutputASBD, 0, NULL, 0, NULL, NULL, &format);
    
        var format : CMAudioFormatDescriptionRef?
        
        var audioFormat: AudioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: 44100.00, mFormatID: kAudioFormatMPEG4AAC, mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        /*audioFormat.mSampleRate			= 44100.00;
        audioFormat.mFormatID			= kAudioFormatMPEG4AAC;
        audioFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioFormat.mFramesPerPacket	= 1;
        audioFormat.mChannelsPerFrame	= 1;
        audioFormat.mBitsPerChannel		= 16;
        audioFormat.mBytesPerPacket		= 2;
        audioFormat.mBytesPerFrame		= 2;*/
    
        CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &audioFormat, 0, nil, 0, nil, nil, &format);
        CMSampleBufferCreate( kCFAllocatorDefault, nil, false, nil, nil, format, framesToProcess, 1, &timing, 0, nil, &sampleBufferOut);
        
        if(bufferList.memory.mBuffers.mData == nil || sampleBufferOut == nil) {
            return;
        }
        
        // put data into buffer from ABL (audio buffer list)
        status = CMSampleBufferSetDataBufferFromAudioBufferList( sampleBufferOut!, kCFAllocatorDefault,  kCFAllocatorDefault, 0, bufferList );
    
        //AVAssetWriterInput *b = [AudioHelper sharedInstance].assetWriterAudioInput;
    
        guard let assetWriterAudioInput = _assetWriterAudioInput else{return}
        guard let sampleBufferOutCheck = sampleBufferOut else{return}
        
        //guard let a : String! = sampleBufferOut.debugDescription else{return}
        if(!CMSampleBufferIsValid(sampleBufferOut!)) {
            return;
        }
        // write to assetwriter audioinput
        //веси блять все в видео менеджер тупо также как там в обработчике, мб собрать постоянный бущер звука также как с видео
        //все до завтра, а теперь домой спатенькиииии
        if(assetWriterAudioInput.readyForMoreMediaData) {
            if (assetWriterAudioInput.appendSampleBuffer(sampleBufferOut!))
            {
                NSLog("Couldn't append audio sample buffer");
            }
            else {
                NSLog("Ok");
            }
        }
    }
    
    func bridge<T : AnyObject>(obj : T) -> UnsafeMutablePointer<Void> {
        return UnsafeMutablePointer(Unmanaged.passUnretained(obj).toOpaque())
    }
}