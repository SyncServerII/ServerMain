//
//  FileController_DownloadStaleFiles.swift
//  FileControllerUploadFileTests
//
//  Created by Christopher G Prince on 2/16/21.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared
import ChangeResolvers
import Credentials
import ServerAccount

// Given that a vN file has been uploaded, the vN-1 files (stale versions) can be deleted for a period of time afterwards.

class FileController_DownloadStaleFiles: ServerTestCase, UploaderCommon  {
    var accountManager: AccountManager!
    var services: Services!
    
    override func setUp() {
        super.setUp()
        HeliumLogger.use(.debug)
        
        accountManager = AccountManager()
        let credentials = Credentials()
        _ = accountManager.setupAccounts(credentials: credentials)
        let resolverManager = ChangeResolverManager()

        guard let services = Services(accountManager: accountManager, changeResolverManager: resolverManager) else {
            XCTFail()
            return
        }
        
        self.services = services
        
        do {
            try resolverManager.setupResolvers()
        } catch let error {
            XCTFail("\(error)")
            return
        }
    }

    func testUploadVNAndDownloadVNMinusOne() throws {
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        var mimeType: MimeType?
        
        let file:TestFile = .commentFile
        let changeResolverName = CommentFile.changeResolverName
        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)

        guard let result1 = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), file: file, dataToUpload: comment.updateContents) else {
            XCTFail()
            return
        }
        
        // Download the prior version. It should still be available.
        guard let _ = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: result1.checkSum, contentsChangedExpected: true) else {
            XCTFail()
            return
        }
    }
}
