//
//  FileController_GetUploadsResults.swift
//  FileControllerTests
//
//  Created by Christopher G Prince on 8/12/20.
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
import Credentials

class FileController_GetUploadsResults: ServerTestCase, UploaderCommon {
    var accountManager: AccountManager!
    
    override func setUp() {
        super.setUp()
        
        accountManager = AccountManager()
        let credentials = Credentials()
        _ = accountManager.setupAccounts(credentials: credentials)
    }
    
    func runGetUploadsResult(withInvalidDeferredUploadId: Bool) throws {
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
        let fileUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName

        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result.uploadingUserId else {
            XCTFail()
            return
        }
                
        guard let deferredUpload1 = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }
        
        let batchUUID = UUID().uuidString
            
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        let request = GetUploadsResultsRequest()
        
        if withInvalidDeferredUploadId {
            request.deferredUploadId = deferredUploadId1 + 1
        }
        else {
            request.deferredUploadId = deferredUploadId1
        }
        
        guard let getUploadsResult = getUploadsResults(request: request, deviceUUID: deviceUUID) else {
            XCTFail()
            return
        }
        
        if withInvalidDeferredUploadId {
            XCTAssert(getUploadsResult.status == nil)
        }
        else {
            XCTAssert(getUploadsResult.status == .pendingChange)
        }
    }
    
    func testGetUploadsResultWithInvalidDeferredUploadIdGivesNilStatus() throws {
        try runGetUploadsResult(withInvalidDeferredUploadId: true)
    }
    
    func testGetUploadsResultWithValidDeferredUploadIdGivesNonNilStatus() throws {
        try runGetUploadsResult(withInvalidDeferredUploadId: false)
    }
    
    func runGetUploadsResult(withInvalidUserId: Bool) throws {
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
        let fileUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName

        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result.uploadingUserId else {
            XCTFail()
            return
        }

        var actualUserId: UserId = userId
        if withInvalidUserId {
            actualUserId += 1
        }
        
        guard let deferredUpload1 = createDeferredUpload(userId: actualUserId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }
        
        let batchUUID = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, userId: actualUserId, deferredUploadId:deferredUploadId1, updateContents: comment.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        let request = GetUploadsResultsRequest()
        request.deferredUploadId = deferredUploadId1
        
        let getUploadsResult = getUploadsResults(request: request, deviceUUID: deviceUUID)
        if withInvalidUserId {
            XCTAssert(getUploadsResult == nil)
        }
        else {
            XCTAssert(getUploadsResult != nil)
            XCTAssert(getUploadsResult?.status == .pendingChange)
        }
    }
    
    func testGetUploadsResultWithValidUserIdWorks() throws {
        try runGetUploadsResult(withInvalidUserId: false)
    }
    
    func testGetUploadsResultWithInvalidUserIdFails() throws {
        try runGetUploadsResult(withInvalidUserId: true)
    }
    
    func runGetUploadsResult(withDeferredUploadId: Bool) throws {
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
        let fileUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName

        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let deferredUpload1 = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }

        let batchUUID = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        var actualDeferredUpload: Int64?
        if withDeferredUploadId {
            actualDeferredUpload = deferredUploadId1
        }
        
        let request = GetUploadsResultsRequest()
        request.deferredUploadId = actualDeferredUpload
        
        let getUploadsResult = getUploadsResults(request: request, deviceUUID: deviceUUID)
        if withDeferredUploadId {
            XCTAssert(getUploadsResult != nil)
            XCTAssert(getUploadsResult?.status == .pendingChange)
        }
        else {
            XCTAssert(getUploadsResult == nil)
        }
    }
    
    func testGetUploadsResultWithNoDeferredUploadIdFails() throws {
        try runGetUploadsResult(withDeferredUploadId: false)
    }
    
    func testGetUploadsResultWithDeferredUploadIdWorks() throws {
        try runGetUploadsResult(withDeferredUploadId: true)
    }
    
    func testGetUploadsResultWithBatchUUIDWorks() throws {
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
        let fileUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName
        let batchUUID = UUID().uuidString
        
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let deferredUpload1 = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: batchUUID, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        let request = GetUploadsResultsRequest()
        request.batchUUID = batchUUID
        
        let getUploadsResult = getUploadsResults(request: request, deviceUUID: deviceUUID)
        XCTAssert(getUploadsResult != nil)
        XCTAssert(getUploadsResult?.status == .pendingChange)
    }
}
