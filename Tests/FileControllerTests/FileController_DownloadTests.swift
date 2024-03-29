//
//  FileController_DownloadTests.swift
//  FileControllerTests
//
//  Created by Christopher G Prince on 8/8/20.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import Foundation
import ServerShared
import HeliumLogger
import ServerAccount
import ChangeResolvers

class FileController_DownloadTests: ServerTestCase {
    override func setUp() {
        super.setUp()
    }
    
    func testDownloadFileTextSucceeds() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum) else {
            XCTFail()
            return
        }
        
        guard let data = downloadResult.data else {
            XCTFail()
            return
        }
        
        XCTAssert(file.contents.equal(to: data))
    }
    
    func testDownloadURLFileSucceeds() {
        let file:TestFile = .testUrlFile
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum) else {
            XCTFail()
            return
        }
        
        guard let data = downloadResult.data else {
            XCTFail()
            return
        }
        
        XCTAssert(file.contents.equal(to: data))
    }
    
    func testDownloadTextFileWithFileGroup() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum) else {
            XCTFail()
            return
        }
        
        guard let data = downloadResult.data else {
            XCTFail()
            return
        }
        
        XCTAssert(file.contents.equal(to: data))
    }
    
    func testDownloadTextFileWhereFileDeletedGivesGoneResponse() {
        let testAccount:TestAccount = .primaryOwningAccount
        let deviceUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadTextFile(batchUUID: UUID().uuidString, testAccount: testAccount, deviceUUID: deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        var checkSum:String!
        let file = TestFile.test2
        
        checkSum = file.checkSum(type: testAccount.scheme.accountName)

        let uploadRequest = UploadFileRequest()
        uploadRequest.fileUUID = uploadResult.request.fileUUID
        uploadRequest.mimeType = file.mimeType.rawValue
        uploadRequest.sharingGroupUUID = sharingGroupUUID
        uploadRequest.checkSum = checkSum
    
        let options = CloudStorageFileNameOptions(cloudFolderName: ServerTestCase.cloudFolderName, mimeType: file.mimeType.rawValue)

        let cloudFileName = Filename.inCloud(deviceUUID: deviceUUID, fileUUID: uploadResult.request.fileUUID, mimeType: file.mimeType.rawValue, fileVersion: 0)
        deleteFile(testAccount: testAccount, cloudFileName: cloudFileName, options: options)

        self.performServerTest(testAccount:testAccount) { expectation, testCreds in
            let headers = self.setupHeaders(testUser:testAccount, accessToken: testCreds.accessToken, deviceUUID:deviceUUID)
            
            let downloadFileRequest = DownloadFileRequest()
            downloadFileRequest.fileUUID = uploadRequest.fileUUID
            downloadFileRequest.fileVersion = 0
            downloadFileRequest.sharingGroupUUID = sharingGroupUUID
            
            self.performRequest(route: ServerEndpoints.downloadFile, responseDictFrom:.header, headers: headers, urlParameters: "?" + downloadFileRequest.urlParameters()!, body:nil) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                
                if let dict = dict,
                    let downloadFileResponse = try? DownloadFileResponse.decode(dict) {
                    XCTAssert(downloadFileResponse.gone == GoneReason.fileRemovedOrRenamed.rawValue)
                }
                else {
                    XCTFail()
                }
                
                expectation.fulfill()
            }
        }
    }
    
    func testDownloadFileTextWithAppMetaDataSucceeds() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let appMetaData = "{ \"foo\": \"bar\" }"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, appMetaData: appMetaData, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum) else {
            XCTFail()
            return
        }
        
        guard let data = downloadResult.data else {
            XCTFail()
            return
        }
        
        XCTAssert(file.contents.equal(to: data))
        XCTAssert(downloadResult.response?.appMetaData == appMetaData)
    }
    
    func testDownloadFileWithIncorrectVersionFails() {        
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let appMetaData = "{ \"foo\": \"bar\" }"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, appMetaData: appMetaData, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 1, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum, expectedError: true)
        XCTAssert(downloadResult == nil)
    }
    
    func testThatDownloadWithNilFileVersionFails() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let downloadResult = downloadFile(testAccount: testAccount, fileUUID: nil, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum, expectedError: true)
        XCTAssert(downloadResult == nil)
    }
    
    func testDownloadFileWithIncorrectUUIDFails() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let fakeFileUUID = Foundation.UUID().uuidString
        let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fakeFileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum, expectedError: true)
        XCTAssert(downloadResult == nil)
    }
    
    func testThatFileUploadTimeIsReasonable() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        let beforeUploadTime = Date()
        
        guard let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let afterUploadTime = Date()

        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 0, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID, expectedCheckSum: uploadResult.checkSum) else {
            XCTFail()
            return
        }
        
        
        guard let data = downloadResult.data else {
            XCTFail()
            return
        }
        
        XCTAssert(file.contents.equal(to: data))
        
        checkThatDateFor(fileUUID: fileUUID, isBetween: beforeUploadTime, end: afterUploadTime, sharingGroupUUID: sharingGroupUUID)
    }
    
    func testDownloadVNOfFileWorks() throws {
        let file:TestFile = .commentFile
        let comment = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard case .string(let initialFileString) = file.contents,
            let initialData = initialFileString.data(using: .utf8) else {
            XCTFail()
            return
        }
        
        var initialCommentFile = try CommentFile(with: initialData)
        try initialCommentFile.add(newRecord: comment.updateContents)
        
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName

        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, testAccount: testAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: comment.updateContents) else {
            XCTFail()
            return
        }
        
        guard let downloadResult = downloadFile(testAccount: testAccount, fileUUID: fileUUID, fileVersion: 1, sharingGroupUUID: sharingGroupUUID, deviceUUID: deviceUUID) else {
            XCTFail()
            return
        }
        
        guard let downloadedData = downloadResult.data else {
            XCTFail()
            return
        }
        
        let downloadedCommentFile = try CommentFile(with: downloadedData)
        
        // TODO: The `==` operator on `CommentFile`'s appears broken. It failed with:
        /*
        /root/Apps/ServerMain/Tests/FileControllerTests/FileController_DownloadTests.swift:301: error: FileController_DownloadTests.testDownloadVNOfFileWorks : XCTAssertTrue failed - initialCommentFile: CommentFile(elementsKey: "elements", mainDictionary: ["elements": [["id": "9A52DB59-BC73-4FB7-A310-E645E9486039", "messageString": "Example"]]], ids: Set(["9A52DB59-BC73-4FB7-A310-E645E9486039"])) == downloadedCommentFile: CommentFile(elementsKey: "elements", mainDictionary: ["elements": [["messageString": "Example", "id": "9A52DB59-BC73-4FB7-A310-E645E9486039"]]], ids: Set(["9A52DB59-BC73-4FB7-A310-E645E9486039"]))
         */
        //XCTAssert(initialCommentFile == downloadedCommentFile, "initialCommentFile: \(initialCommentFile) == downloadedCommentFile: \(downloadedCommentFile)")
        
        XCTAssert(initialCommentFile ~~ downloadedCommentFile, "initialCommentFile: \(initialCommentFile) == downloadedCommentFile: \(downloadedCommentFile)")
        
        guard initialCommentFile.count == 1, downloadedCommentFile.count == 1 else {
            XCTFail()
            return
        }
        
        guard let elements1 = initialCommentFile[0] as? [String: String],
            let elements2 = downloadedCommentFile[0] as? [String: String] else {
            XCTFail()
            return
        }
        
        XCTAssert(elements1 == elements2)
    }
}
