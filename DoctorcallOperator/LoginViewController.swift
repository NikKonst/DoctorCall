//
//  ViewController.swift
//  DoctorcallOperator
//
//  Created by Nikita on 04.07.16.
//  Copyright © 2016 Nikita. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController, QBChatDelegate {
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func createUser() {
        var isCreationSuccess = true
        let user = QBUUser()
        user.login = "nikkonst"
        user.password = "Thah9vet"
        
        QBRequest.signUp(user, successBlock: { (resp : QBResponse, user : QBUUser?) in
                NSLog("Success sign up")
                self.loginUser()
            }, errorBlock: { (resp : QBResponse) in
                NSLog("Error: \(resp.error)")
                isCreationSuccess = false
            })
        
        if (!isCreationSuccess) {
            let alert = UIAlertController(title: "", message: "Sign up error", preferredStyle: UIAlertControllerStyle.Alert)
            self.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func loginUser() {
        let login = loginTextField.text
        let password = passwordTextField.text
        
        QBRequest.logInWithUserLogin(login!, password: password!, successBlock: { (resp : QBResponse, user : QBUUser?) in
                NSLog("Success login")
                user?.password = password
            
                QBChat.instance().connectWithUser(user!, completion: { (err : NSError?) in
                    NSLog("Error: \(err)")
                    if (err != nil) {
                        self.loginButton.enabled = true
                        self.sendErrorMessage("Incorrect login or password")
                    }
                    else {
                        self.performSegueWithIdentifier("showCallViewController", sender: self)
                    }
                })
            
            },
            errorBlock: { (resp : QBResponse) in
                NSLog("Error: \(resp.error)")
                self.loginButton.enabled = true
                self.sendErrorMessage("Incorrect login or password")
            })
    }

    @IBAction func loginButtonTouch(sender: AnyObject) {
        loginButton.enabled = false
        loginUser()
    }
    
    func sendErrorMessage(message : String) {
        let alert = UIAlertController(title: "", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default,handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
    }
}

