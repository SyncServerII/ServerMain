//
//  AccountAuthenticationTests_Solid.swift
//  AccountAuthenticationTests
//
//  Created by Christopher G Prince on 8/18/21.
//

import XCTest
import Kitura
import KituraNet
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import CredentialsSolid
import Foundation
import ServerShared
import SolidAuthSwiftTools
@testable import ServerSolidAccount

// Credentials are stored in ServerTests.json, under "solid1".
// To regenerate, I'm taking the creds from the Neebla test server *database* User table and copying them into the ServerTests.json file.

class AccountAuthenticationTests_Solid: AccountAuthenticationTests {
    var creds:SolidCreds!
    
    override func setUp() {
        super.setUp()
        testAccount = .solid1
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // I'm having some problems getting callbacks from my Solid auth methods. Trying to simplify the tests.
    func testBasicSolidAuth() {
        let solidAccount:TestAccount = .solid1
        
        guard let creds = SolidCreds(configuration: Configuration.server, delegate: nil) else {
            Log.error("Could not create SolidCreds")
            XCTFail()
            return
        }
        
        self.creds = creds
        creds.refreshToken = solidAccount.token()
                    
        guard let base64 = solidAccount.secondToken() else {
            XCTFail()
            Log.error("Could not get secondToken for SolidCreds")
            return
        }
        
        creds.codeParameters = try! CodeParameters.from(fromBase64: base64)

        let exp = expectation(description: "exp")

        creds.refresh {[unowned creds] error in
            Log.debug("Finished call to refresh SolidCreds")
            XCTAssert(error == nil, "credsFor: Failure on refresh: \(error!)")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testCredsCache() {
        let solidAccount:TestAccount = .solid1

        let exp = expectation(description: "exp")

        CredsCache.credsFor(solidAccount:solidAccount) { creds in
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
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
    
    override func testThatAccountForExistingUserCannotBeCreated() {
        super.testThatAccountForExistingUserCannotBeCreated()
    }
}
