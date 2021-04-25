//
//  AccountAuthenticationTests_Apple.swift
//  AccountAuthenticationTests
//
//  Created by Christopher G Prince on 1/24/21.
//

import XCTest
import Kitura
import KituraNet
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import CredentialsAppleSignIn
import Foundation
import ServerShared

// Credentials are stored in ServerTests.json, under "apple1".
// To regenerate, I'm taking the creds from the Neebla test server *database* User table and copying them into the ServerTests.json file.
// The `testThatAppleSignInUserHasValidCreds` test case also uses the .dropbox1 creds.
// So, those creds also need to be copied over from the server.
// And it uses the .google1 creds. Copy those over too.

class AccountAuthenticationTests_Apple: AccountAuthenticationTests {
    override func setUp() {
        super.setUp()
        testAccount = .apple1
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    override func testGoodEndpointWithBadCredsFails() {
        super.testGoodEndpointWithBadCredsFails()
    }

    override func testGoodEndpointWithGoodCredsWorks() {
        super.testGoodEndpointWithGoodCredsWorks()
    }

    override func testBadPathWithGoodCredsFails() {
        super.testBadPathWithGoodCredsFails()
    }

    override func testGoodPathWithBadMethodWithGoodCredsFails() {
        super.testGoodPathWithBadMethodWithGoodCredsFails()
    }

    func testThatAppleSignInUserHasValidCreds() {
        createSharingUser(withSharingPermission: .read, sharingUser: testAccount)
        
        let deviceUUID = Foundation.UUID().uuidString
        
        self.performServerTest(testAccount: testAccount) { expectation, appleSignInCreds in
            let headers = self.setupHeaders(testUser: self.testAccount, accessToken: appleSignInCreds.accessToken, deviceUUID:deviceUUID)
            self.performRequest(route: ServerEndpoints.checkCreds, headers: headers) { response, dict in
                Log.info("Status code: \(String(describing: response?.statusCode))")
                XCTAssert(response?.statusCode == .OK, "Did not work on check creds request")
                expectation.fulfill()
            }
        }
    }
    
    override func testThatAccountForExistingUserCannotBeCreated() {
        // This fails. It only works for owning users.
        // super.testThatAccountForExistingUserCannotBeCreated()
    }
}
