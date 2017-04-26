//
//  SignInVC.swift
//  SharedImages
//
//  Created by Christopher Prince on 3/12/17.
//  Copyright © 2017 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import UIKit
import SMCoreLib
import SyncServer
import SevenSwitch

class SignInVC : SMGoogleUserSignInViewController {
    fileprivate var signinTypeSwitch:SevenSwitch!
    
    static private var rawSharingPermission:SMPersistItemString = SMPersistItemString(name: "SignInVC.rawSharingPermission", initialStringValue: "", persistType: .userDefaults)
    
    // If user is signed in as a sharing user, this persistently gives their permissions.
    var sharingPermission:SharingPermission? {
        set {
            SignInVC.rawSharingPermission.stringValue = newValue == nil ? "" : newValue!.rawValue
            setSharingButtonState()
        }
        get {
            return SignInVC.sharingPermission
        }
    }
    
    static var sharingPermission:SharingPermission? {
        return SignInVC.rawSharingPermission.stringValue == "" ? nil : SharingPermission(rawValue: SignInVC.rawSharingPermission.stringValue)
    }
    
    var googleSignInButton:GoogleSignInOutButton!
    var sharingBarButton:UIBarButtonItem!
    
    private var _acceptSharingInvitation:Bool = false
    var acceptSharingInvitation: Bool {
        get {
            let result = _acceptSharingInvitation
            _acceptSharingInvitation = false
            return result
        }
        set {
            _acceptSharingInvitation = newValue
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: *2* Signing out and then signing in as a different user will mess up this app. What we're really assuming is that the user may sign out, but will then again sign in as the same user. If the user signs in as a different user, we need to alert them that this is going to remove all local files. And, signing in again as the prior user will cause redownload of the prior files. This may be something we want to fix in the future: To enable the client to handle multiple users. This would require indexing the meta data by user.
        
        googleSignInButton = SignIn.session.googleSignIn.signInButton(delegate: self)
        googleSignInButton.frameY = 100
        view.addSubview(googleSignInButton)
        googleSignInButton.centerHorizontallyInSuperview()

        signinTypeSwitch = SevenSwitch()
        signinTypeSwitch.offLabel.text = "Existing user"
        signinTypeSwitch.offLabel.textColor = UIColor.black
        signinTypeSwitch.onLabel.text = "New user"
        signinTypeSwitch.onLabel.textColor = UIColor.black
        signinTypeSwitch.frameY = googleSignInButton.frameMaxY + 30
        signinTypeSwitch.frameWidth = 120
        signinTypeSwitch.inactiveColor =  UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        signinTypeSwitch.onTintColor = UIColor(red: 16.0/255.0, green: 125.0/255.0, blue: 247.0/255.0, alpha: 1)
        view.addSubview(signinTypeSwitch)
        signinTypeSwitch.centerHorizontallyInSuperview()

        sharingBarButton = UIBarButtonItem(title: "Share", style: .plain, target: self, action: #selector(shareAction))
        navigationItem.rightBarButtonItem = sharingBarButton
        
        SharingInvitation.session.delegate = self
        SignIn.session.googleSignIn.delegate = self
        
        setSharingButtonState()
        setSignInTypeState()
    }
    
    func setSharingButtonState() {
        switch sharingPermission {
        case .some(.admin), .none: // .none means this is not a sharing user.
            sharingBarButton.isEnabled = true
            
        case .some(.read), .some(.write):
            sharingBarButton.isEnabled = false
        }
    }
    
    func setSignInTypeState() {
        signinTypeSwitch?.isHidden = SignIn.session.googleSignIn.userIsSignedIn
    }
    
    func shareAction() {
        var alert:UIAlertController
        
        if SignIn.session.googleSignIn.userIsSignedIn {
            alert = UIAlertController(title: "Share your data with a Google user?", message: nil, preferredStyle: .actionSheet)

            func addAlertAction(_ permission:SharingPermission) {
                alert.addAction(UIAlertAction(title: permission.userFriendlyText(), style: .default){alert in
                    self.completeSharing(permission: permission)
                })
            }
            
            addAlertAction(.read)
            addAlertAction(.write)
            addAlertAction(.admin)

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel){alert in
            })
        }
        else {
            alert = UIAlertController(title: "Please sign in first!", message: "There is no signed in user.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel){alert in
            })
        }
        
        alert.popoverPresentationController?.barButtonItem = sharingBarButton
        present(alert, animated: true, completion: nil)
    }
    
    private func completeSharing(permission:SharingPermission) {
        SyncServerUser.session.createSharingInvitation(withPermission: permission) { invitationCode, error in
            if error == nil {
                let sharingURLString = SharingInvitation.createSharingURL(invitationCode: invitationCode!, permission:permission)
                if let email = SMEmail(parentViewController: self) {
                    let message = "I'd like to share my images with you through the SharedImages app and your Google account. To share my images, you need to:\n" +
                        "1) download the SharedImages iOS app onto your iPhone or iPad,\n" +
                        "2) tap the link below in the Apple Mail app, and\n" +
                        "3) follow the instructions within the app to sign in to your Google account to access my images.\n" +
                        "You will have " + permission.userFriendlyText() + " access to my images.\n\n" +
                            sharingURLString
                    
                    email.setMessageBody(message, isHTML: false)
                    email.setSubject("Share my images using the SharedImages app")
                    email.show()
                }
            }
            else {
                let alert = UIAlertController(title: "Error creating sharing invitation!", message: "\(error)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel) {alert in
                })
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

// TODO: *1* Need a delegate callback from the signin, to let us hide the user type button when the user is signed in.

extension SignInVC : SharingInvitationDelegate {
    func sharingInvitationReceived(_ sharingInvitation:SharingInvitation) {
        
        let userFriendlyText = sharingInvitation.sharingInvitationPermission!.userFriendlyText()
        if !SignIn.session.googleSignIn.userIsSignedIn {
            let alert = UIAlertController(title: "Do you want to share the images (\(userFriendlyText)) in the invitation?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Not now", style: .cancel) {alert in
            })
            alert.addAction(UIAlertAction(title: "Share", style: .default) {alert in
                self.acceptSharingInvitation = true
                self.googleSignInButton.tap()
            })
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension SignInVC : SMGoogleUserSignInDelegate {
    func shouldDoUserAction(creds:GoogleSignInCreds) -> UserActionNeeded {
        var result:UserActionNeeded
        
        if acceptSharingInvitation {
            result = .createSharingUser(invitationCode: SharingInvitation.session.sharingInvitationCode!)
        } else if signinTypeSwitch.isOn() {
            result = .createOwningUser
        }
        else {
            result = .signInExistingUser
        }
        
        return result
    }
    
    func userActionOccurred(action:UserActionOccurred, googleUserSignIn:SMGoogleUserSignIn) {
        switch action {
        case .userSignedOut:
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.selectTabInController(tab: .signIn)
            
        case .userNotFoundOnSignInAttempt:
            // TODO: *2* Need to inform user.
            break
            
        case .existingUserSignedIn(let sharingPermission):
            self.sharingPermission = sharingPermission
            
        case .owningUserCreated:
            sharingPermission = nil
            
        case .sharingUserCreated:
            self.sharingPermission = SharingInvitation.session.sharingInvitationPermission!
        }
        
        setSharingButtonState()
        setSignInTypeState()
    }
}

extension SignInVC : TabControllerNavigation {
    func tabBarViewControllerWasSelected() {
        setSignInTypeState()
    }
}
