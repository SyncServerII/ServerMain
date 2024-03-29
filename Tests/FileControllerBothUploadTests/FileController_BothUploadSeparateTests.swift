
import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared
import ChangeResolvers
import Credentials

// Upload requests with both upload file changes and upload deletions, but both requests independent (separate) of the other.

class FileController_BothUploadSeparateTests: ServerTestCase, UploaderCommon {
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
    
    func runOneUploadFileChangeAndOneUploadDeletion() {
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString
        let deviceUUID = Foundation.UUID().uuidString
        let batchUUID1 = Foundation.UUID().uuidString
        let batchUUID2 = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName
        
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let result1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: batchUUID1, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup:fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result1.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: batchUUID2, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup2) else {
            XCTFail()
            return
        }
        
        let comment1 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)

        guard let deferredUpload = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: batchUUID2, status: .pendingChange),
            let deferredUploadId1 = deferredUpload.deferredUploadId else {
            XCTFail()
            return
        }

        let batchUUID3 = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID3, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        uploadDeletionRequest.fileGroupUUID = fileGroup2.fileGroupUUID
        
        guard let uploadResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false),
            let deferredUploadId2 = uploadResult.deferredUploadId else {
            XCTFail()
            return
        }

        guard let status1 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId1), status1 == .completed else {
            XCTFail()
            return
        }
        
        guard let status2 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId2), status2 == .completed else {
            XCTFail()
            return
        }
    }

    func testOneUploadFileChangeAndOneUploadDeletionWithFileGroup() {
        runOneUploadFileChangeAndOneUploadDeletion()
    }
    
    func runTwoUploadFileChangesAndOneUploadDeletion() throws {
        // Upload changes
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString
        
        // Upload deletion
        let fileUUID3 = Foundation.UUID().uuidString

        let deviceUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName
        
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let result1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result1.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup:fileGroup, changeResolverName: changeResolverName) else {
            XCTFail()
            return
        }
        
        let batchUUID = Foundation.UUID().uuidString
        let fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo2")

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID3, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup2) else {
            XCTFail()
            return
        }
        
        let comment1 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)
        
        guard let deferredUpload = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: batchUUID, status: .pendingChange),
            let deferredUploadId1 = deferredUpload.deferredUploadId else {
            XCTFail()
            return
        }

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment2.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        uploadDeletionRequest.fileGroupUUID = fileGroup2.fileGroupUUID
        
        guard let uploadResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false),
            let deferredUploadId2 = uploadResult.deferredUploadId else {
            XCTFail()
            return
        }
        
        guard let fileIndex1 = getFileIndex(fileUUID: fileUUID1),
            let fileIndex2 = getFileIndex(fileUUID: fileUUID2),
            let fileIndex3 = getFileIndex(fileUUID: fileUUID3) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex1, services: services.uploaderServices)
        XCTAssert(found1)
        let found2 = try fileIsInCloudStorage(fileIndex: fileIndex2, services: services.uploaderServices)
        XCTAssert(found2)
        let found3 = try fileIsInCloudStorage(fileIndex: fileIndex3, services: services.uploaderServices)
        XCTAssert(!found3)
        
        guard let status1 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId1), status1 == .completed else {
            XCTFail()
            return
        }
        
        guard let status2 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId2), status2 == .completed else {
            XCTFail()
            return
        }
        
        XCTAssert(deferredCount + 2 == DeferredUploadRepository(db).count())
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count())))")
    }
    
    func testTwoUploadFileChangesAndOneUploadDeletionWithFileGroup() throws {
        try runTwoUploadFileChangesAndOneUploadDeletion()
    }
}
