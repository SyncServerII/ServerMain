
import LoggerAPI
@testable import Server
@testable import TestsCommon
import KituraNet
import XCTest
import Foundation
import ServerShared
import ChangeResolvers
import Credentials

class PruneTests: ServerTestCase, UploaderCommon {
    var accountManager: AccountManager!
    var uploader: Uploader!
    var runCompleted:((Swift.Error?)->())?
    
    override func setUp() {
        super.setUp()
        
        accountManager = AccountManager()
        _ = accountManager.setupAccounts(credentials: Credentials())
        let resolverManager = ChangeResolverManager()

        guard let services = Services(accountManager: accountManager, changeResolverManager: resolverManager) else {
            XCTFail()
            return
        }
        
        do {
            try resolverManager.setupResolvers()
        } catch let error {
            XCTFail("\(error)")
            return
        }
        
        uploader = Uploader(services: services.uploaderServices, delegate: nil)
        uploader.delegate = self
        runCompleted = nil
    }

    // Pruning: Remove file change uploads (DeferredUpload, Upload's) from the database corresponding to  deletions.

    func testPruneWithNoDeferredUploads() throws {
        guard uploader.pruneFileUploads(deferredFileDeletions: []) else {
            XCTFail()
            return
        }
    }
    
    // The upload change and deletion are for the same file.
    func runPruneWithOneUploadChangeAndOneFileDeletion() throws {
        let fileUUID1 = Foundation.UUID().uuidString
        let deviceUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName
        
        guard let deferredCount = DeferredUploadRepository(db).count(),
            let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }

        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let result1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup:fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = result1.uploadingUserId else {
            XCTFail()
            return
        }

        let comment1 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)
        
        // Set up the upload change
        guard let deferredUpload1 = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }

        // vN UploadRequest's, for the real endpoint don't allow fileGroupUUID's, but the resultant Upload record (that we're faking), do have a fileGroupUUID.
        let batchUUID = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, fileGroup: fileGroup, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId:deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, state: .vNUploadFileChange) else {
            XCTFail()
            return
        }
        
        // Set up the upload deletion
        guard let deferredUpload2 = createDeferredUpload(userId: userId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, status: .pendingDeletion),
            let deferredUploadId2 = deferredUpload2.deferredUploadId else {
            XCTFail()
            return
        }
        
        guard uploader.pruneFileUploads(deferredFileDeletions: [deferredUpload2]) else {
            XCTFail()
            return
        }
        
        // deferredUploadId1 -- for upload change, it gets pruned.
        guard let status1 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId1), status1 == .completed else {
            XCTFail()
            return
        }

        guard let status2 = getUploadsResults(deviceUUID: deviceUUID, deferredUploadId: deferredUploadId2), status2 == .pendingDeletion else {
            XCTFail()
            return
        }
        
        XCTAssert(deferredCount + 2 == DeferredUploadRepository(db).count(), "\(deferredCount) + 2 != \(String(describing: DeferredUploadRepository(db).count()))")
        
        // The upload deletion has no Upload record
        // The upload change Upload record has been removed.
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count()))")
    }
    
    func testPruneWithOneUploadChangeAndOneFileDeletionWithFileGroup() throws {
        try runPruneWithOneUploadChangeAndOneFileDeletion()
    }
}

extension PruneTests: UploaderDelegate {
    func run(completed: UploaderProtocol, error: Swift.Error?) {
        runCompleted?(error)
    }
}
