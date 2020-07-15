//
//  AccountManager+Extras.swift
//  Server
//
//  Created by Christopher G Prince on 7/12/20.
//

import Foundation
import Credentials
import ServerAccount
import ServerDropboxAccount
import ServerGoogleAccount
import ServerMicrosoftAccount
import ServerAppleSignInAccount
import ServerFacebookAccount
import CredentialsGoogle
import CredentialsFacebook
import CredentialsDropbox
import CredentialsMicrosoft

extension AccountManager {
    func setupAccounts(credentials: Credentials) {
        if Configuration.server.allowedSignInTypes.Google == true {
            let googleCredentials = CredentialsGoogleToken(tokenTimeToLive: Configuration.server.signInTokenTimeToLive)
            credentials.register(plugin: googleCredentials)
            addAccountType(GoogleCreds.self)
        }
        
        if Configuration.server.allowedSignInTypes.Facebook == true {
            let facebookCredentials = CredentialsFacebookToken(tokenTimeToLive: Configuration.server.signInTokenTimeToLive)
            credentials.register(plugin: facebookCredentials)
            addAccountType(FacebookCreds.self)
        }

        if Configuration.server.allowedSignInTypes.Dropbox == true {
            let dropboxCredentials = CredentialsDropboxToken(tokenTimeToLive: Configuration.server.signInTokenTimeToLive)
            credentials.register(plugin: dropboxCredentials)
            addAccountType(DropboxCreds.self)
        }
        
        if Configuration.server.allowedSignInTypes.Microsoft == true {
            let microsoftCredentials = CredentialsMicrosoftToken(tokenTimeToLive: Configuration.server.signInTokenTimeToLive)
            credentials.register(plugin: microsoftCredentials)
            addAccountType(MicrosoftCreds.self)
        }
        
        if Configuration.server.allowedSignInTypes.AppleSignIn == true {
//            let controller = AppleServerServerNotification()
//            func process(params:RequestProcessingParameters) {
//                //controller.
//            }
//
//            proxyRouter.addRoute(ep: AppleServerServerNotification.endpoint, processRequest: process)
        }
        
        // 8/8/17; There needs to be at least one sign-in type configured for the server to do anything. And at least one of these needs to allow owning users. If there can be no owning users, how do you create anything to share? https://github.com/crspybits/SyncServerII/issues/9
        if numberAccountTypes == 0 {
            Startup.halt("There are no sign-in types configured!")
            return
        }
        
        if numberOfOwningAccountTypes == 0 {
            Startup.halt("There are no owning sign-in types configured!")
            return
        }
    }
}