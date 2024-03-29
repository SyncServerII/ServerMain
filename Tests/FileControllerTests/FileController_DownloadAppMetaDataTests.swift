//
//  FileController_DownloadAppMetaDataTests.swift
//  ServerTests
//
//  Created by Christopher G Prince on 3/24/18.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import Foundation
import ServerShared
import HeliumLogger
import ChangeResolvers

class FileController_DownloadAppMetaDataTests: ServerTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDownloadAppMetaDataForBadUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"
        
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult1.sharingGroupUUID else {
            XCTFail()
            return
        }

    
        let badFileUUID = Foundation.UUID().uuidString
        downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: badFileUUID, sharingGroupUUID: sharingGroupUUID, expectedError: true)
    }
    
    func testDownloadAppMetaDataForReallyBadUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup), let sharingGroupUUID = uploadResult1.sharingGroupUUID else {
            XCTFail()
            return
        }
    
        let badFileUUID = "Blig"
        downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: badFileUUID, sharingGroupUUID: sharingGroupUUID, expectedError: true)
    }
    
    func testDownloadAppMetaDataForFileThatIsNotOwnedFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"

        Log.debug("About to uploadTextFile")
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup) else {
            XCTFail()
            return
        }
        
        let deviceUUID2 = Foundation.UUID().uuidString
        
        Log.debug("About to addNewUser")

        let nonOwningAccount:TestAccount = .google2
        let sharingGroupUUID2 = UUID().uuidString
        guard let _ = addNewUser(testAccount: nonOwningAccount, sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID2) else {
            XCTFail()
            return
        }
        
        Log.debug("About to downloadAppMetaData")

        downloadAppMetaData(testAccount: nonOwningAccount, deviceUUID:deviceUUID2, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: sharingGroupUUID2, expectedError: true)
    }
    
    func testDownloadValidAppMetaData0() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult1.sharingGroupUUID else {
            XCTFail()
            return
        }

        guard let downloadAppMetaDataResponse = downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(downloadAppMetaDataResponse.appMetaData == appMetaData)
    }
    
    func testDownloadValidAppMetaData1() {
        let deviceUUID = Foundation.UUID().uuidString
        var appMetaData = "Test1"

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let downloadAppMetaDataResponse1 = downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(downloadAppMetaDataResponse1.appMetaData == appMetaData)
        
        // Expect an error here because you can only upload app meta data with version 0 of the file.
        appMetaData = "Test2"
        uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, appMetaData:appMetaData, errorExpected: true)
    }
    
    // Upload app meta data version 0, then upload app meta version nil, and then make sure when you download you still have app meta version 0. i.e., nil doesn't overwrite a non-nil version.
    func testUploadingNilAppMetaDataDoesNotOverwriteCurrent() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"
        let file: TestFile = .commentFile
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, stringFile: file, fileGroup: fileGroup, changeResolverName: CommentFile.changeResolverName),
            let sharingGroupUUID = uploadResult1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let comment1 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)

        guard let _ = uploadTextFile(batchUUID: UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: comment1.updateContents) else {
            XCTFail()
            return
        }
        
        guard let downloadAppMetaDataResponse1 = downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(downloadAppMetaDataResponse1.appMetaData == appMetaData)
    }
    
    func testDownloadAppMetaDataWithFakeSharingGroupUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup) else {
            XCTFail()
            return
        }

        let invalidSharingGroupUUID = UUID().uuidString
        downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: invalidSharingGroupUUID, expectedError: true)
    }
    
    func testDownloadAppMetaDataWithBadSharingGroupUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Test1"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let uploadResult1 = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData:appMetaData, fileGroup: fileGroup) else {
            XCTFail()
            return
        }

        let workingButBadSharingGroupUUID = UUID().uuidString
        guard addSharingGroup(sharingGroupUUID: workingButBadSharingGroupUUID) else {
            XCTFail()
            return
        }
        
        downloadAppMetaData(deviceUUID:deviceUUID, fileUUID: uploadResult1.request.fileUUID, sharingGroupUUID: workingButBadSharingGroupUUID, expectedError: true)
    }
}


