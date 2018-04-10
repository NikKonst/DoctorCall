//
//  VideoCallViewController.swift
//  DoctorcallOperator
//
//  Created by Nikita on 05.07.16.
//  Copyright © 2016 Nikita. All rights reserved.
//

import Foundation
import UIKit
import AVKit
import QuartzCore

class VideoCallViewController: UIViewController, QBRTCClientDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var callButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    @IBOutlet var opponentVideoView: QBRTCRemoteVideoView!
    @IBOutlet weak var localVideoView: UIView!
    @IBOutlet weak var callUserInfo: UILabel!
    
    var isRecord = false
    var isCall = false
    let callDoctorID = 14596665
    var session : QBRTCSession! = nil
    var fileOutput : AVCaptureMovieFileOutput! = nil
    var ses : AVCaptureSession! = nil
    var videoCaptureOutput = AVCaptureVideoDataOutput()
    var videoManager : VideoManager! = nil
    let webManager : WebManager = WebManager()
    var callingUserName : String = ""
    
    var cameraCapture : QBRTCCameraCapture!
    var cameraCaptureFile : QBRTCCameraCapture!
    
    @IBAction func switchCamera(sender: AnyObject) {
        let position = self.cameraCapture.currentPosition()
        let newPosition = position == AVCaptureDevicePosition.Back ? AVCaptureDevicePosition.Front : AVCaptureDevicePosition.Back
        
        if (self.cameraCapture.hasCameraForPosition(newPosition)) {
            self.cameraCapture.selectCameraPosition(newPosition)
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        QBRTCClient.instance().addDelegate(self)
        
        let videoFormat = QBRTCVideoFormat.init()
        videoFormat.frameRate = 30;
        videoFormat.pixelFormat = QBRTCPixelFormat.Format420f
        videoFormat.width = 640;
        videoFormat.height = 480;
        
        cameraCapture = QBRTCCameraCapture.init(videoFormat: videoFormat, position: AVCaptureDevicePosition.Front)
        
        self.cameraCapture.previewLayer.frame = self.localVideoView.bounds
        
        cameraCapture.startSession()
        
        self.localVideoView.layer.insertSublayer(self.cameraCapture.previewLayer, atIndex: 0)
                
        fileOutput = AVCaptureMovieFileOutput.init()
        let TotalSeconds : Double = 60;
        let preferredTimeScale : Int32 = 30;	//Frames per second
        let maxDuration = CMTimeMakeWithSeconds(TotalSeconds, preferredTimeScale);	//<<SET MAX DURATION
        fileOutput.maxRecordedDuration = maxDuration;
        fileOutput.minFreeDiskSpaceLimit = 1024 * 1024;
        
        videoManager = VideoManager.sharedInstance
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func callUser(sender: AnyObject) {
        let userInfo = ["userName" : (QBChat.instance().currentUser()?.login)!]
        
        if isCall {
            if(session != nil) {
                self.session.hangUp(userInfo)
            }
        }
        else {
            changeIsCallStatusOn(true)
            
            let opponentsIDs = [callDoctorID]
        
            self.session = QBRTCClient.instance().createNewSessionWithOpponents(opponentsIDs, withConferenceType: QBRTCConferenceType.Video)
            
            self.session.startCall(userInfo)
        }
    }
    
    func didReceiveNewSession(session: QBRTCSession!, userInfo: [NSObject : AnyObject]!) {
        if(self.session != nil) {
            let userInfo = ["key" : "value"]
            session.rejectCall(userInfo)
        }
        else {
            setCallUserInfo_userCall(String(userInfo["userName"]!))
            
            callButton.hidden = true
            acceptButton.hidden = false
            rejectButton.hidden = false
            self.session = session
        } 
    }
    
    func session(session: QBRTCSession!, acceptedByUser userID: NSNumber!, userInfo: [NSObject : AnyObject]!) {
        setCallUserInfo_userOnLine(String(userInfo["userName"]!))
        
        startRecord()
    }
    
    func session(session: QBRTCSession!, initializedLocalMediaStream mediaStream: QBRTCMediaStream!) {
        mediaStream.videoTrack.videoCapture = self.cameraCapture
    }
    
    func session(session: QBRTCSession!, receivedRemoteVideoTrack videoTrack: QBRTCVideoTrack!, fromUser userID: NSNumber!) {
        self.opponentVideoView.setVideoTrack(videoTrack)
        
        startRecord()
    }
    
    func sessionDidClose(session: QBRTCSession!) {
        self.session = nil
        changeIsCallStatusOn(false)
        setCallUserInfo_hiddenInfo()
        
        if(isRecord) {
            videoManager.stopSavingVideo {
                self.isRecord = false
            
                let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
                let outputPath = NSString.init(format: "%@/%@", documentsPath, "outs.mp4")
                let outputURL = NSURL.init(fileURLWithPath: outputPath as String)
            
                let fileManager = NSFileManager.defaultManager()
                if fileManager.fileExistsAtPath(outputPath as String) {
                    print("FILE AVAILABLE")
                    
                    let player = AVPlayer(URL: outputURL)
                    let playerController = AVPlayerViewController()
                    playerController.player = player
                    self.presentViewController(playerController, animated: true) {
                        player.play()
                    }
                    
                } else {
                    print("FILE NOT AVAILABLE")
                }
            }
        }
    }
    
    @IBAction func acceptButtonTouch(sender: AnyObject) {
        acceptButton.hidden = true
        rejectButton.hidden = true
        callButton.hidden = false
        
        changeIsCallStatusOn(true)
        
        setCallUserInfo_userOnLine(callingUserName)
        let userInfo = ["userName" : (QBChat.instance().currentUser()?.login)!]
        self.session.acceptCall(userInfo)
    }
    
    
    
    @IBAction func rejectButtonTouch(sender: AnyObject) {
        acceptButton.hidden = true
        rejectButton.hidden = true
        callButton.hidden = false
        
        changeIsCallStatusOn(false)
        
        let userInfo = ["key" : "value"]
        
        setCallUserInfo_hiddenInfo()
        session.rejectCall(userInfo)
    }
    
    func changeIsCallStatusOn(stat : Bool) {
        isCall = stat
        if(stat) {
            callButton.setTitle("End", forState: UIControlState.Normal)
        }
        else {
            callButton.setTitle("Call", forState: UIControlState.Normal)
        }
    }
    
    func startRecord() {
        if (!isRecord && cameraCapture.captureSession.inputs.count > 0) {
            isRecord = true
            let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            let outputPath = NSString.init(format: "%@/%@", documentsPath, "outs.mp4")
            let outputURL = NSURL.init(fileURLWithPath: outputPath as String)
        
            let fileManager = NSFileManager.defaultManager()
            do {
                try fileManager.removeItemAtURL(outputURL)
            }
            catch {
                NSLog("File not deleted")
            }
        
            videoManager.startSavingCaptureToFileWithURL(outputURL, capture: self.cameraCapture)
        }
    }
    
    func setCallUserInfo_userCall(userName : String) {
        callUserInfo.text = userName + " calling..."
        callingUserName = userName
        callUserInfo.hidden = false
    }
    
    func setCallUserInfo_userOnLine(userName : String) {
        callUserInfo.text = userName
        callUserInfo.hidden = false
    }
    
    func setCallUserInfo_hiddenInfo() {
        callUserInfo.text = ""
        callingUserName = ""
        callUserInfo.hidden = true
    }
}