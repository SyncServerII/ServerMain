
import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared
import ChangeResolvers
import Credentials

class FileController_UploadDeletionTests: ServerTestCase, UploaderCommon {
    var accountManager: AccountManager!
    
    override func setUp() {
        super.setUp()
        accountManager = AccountManager(userRepository: UserRepository(db))
        accountManager.setupAccounts(credentials: Credentials())
    }
    
    func runDeletionOfOneFile(withFileGroup: Bool) throws {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        var fileGroupUUID: String?
        if withFileGroup {
            fileGroupUUID = Foundation.UUID().uuidString
        }
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }

        // This file is going to be deleted.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID, fileGroupUUID: fileGroupUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        
        if let fileGroupUUID = fileGroupUUID {
            uploadDeletionRequest.fileGroupUUID = fileGroupUUID
        }
        else {
            uploadDeletionRequest.fileUUID = fileUUID
        }
        
        guard let _ = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false) else {
            XCTFail()
            return
        }
        
        guard let fileIndex1 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex1)
        XCTAssert(!found1)
        
        XCTAssert(deferredCount == DeferredUploadRepository(db).count())
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count())))")
    }
    
    func testDeletionOfOneFileWithNoFileGroup() throws {
        try runDeletionOfOneFile(withFileGroup: false)
    }
    
    func testDeletionOfOneFileWithFileGroup() throws {
        try runDeletionOfOneFile(withFileGroup: true)
    }
    
    func runTwoFileDeletions(withFileGroup: Bool) throws {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString

        var fileGroupUUID: String?
        if withFileGroup {
            fileGroupUUID = Foundation.UUID().uuidString
        }
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }

        // These files are going to be deleted.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileGroupUUID: fileGroupUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = uploadResult.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }

        if fileGroupUUID == nil {
            // Fake an earlier pending deletion, so that in this case we can actually run two non-file group deletions when the request is received.

            guard let deferredUpload = createDeferredUpload(userId: userId, sharingGroupUUID: sharingGroupUUID, status: .pendingDeletion),
                let deferredUploadId = deferredUpload.deferredUploadId else {
                XCTFail()
                return
            }
        
            guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId: deferredUploadId, state: .deleteSingleFile) else {
                XCTFail()
                return
            }
        }
        
        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        
        if let fileGroupUUID = fileGroupUUID {
            uploadDeletionRequest.fileGroupUUID = fileGroupUUID
        }
        else {
            uploadDeletionRequest.fileUUID = fileUUID2
        }
        
        guard let _ = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false) else {
            XCTFail()
            return
        }
        
        guard let fileIndex1 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1) else {
            XCTFail()
            return
        }
        
        guard let fileIndex2 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex1)
        XCTAssert(!found1)
        let found2 = try fileIsInCloudStorage(fileIndex: fileIndex2)
        XCTAssert(!found2)
        
        XCTAssert(deferredCount == DeferredUploadRepository(db).count())
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count())))")
    }
    
    func testTwoFileDeletionWithoutFileGroup() throws {
        try runTwoFileDeletions(withFileGroup: false)
    }
    
    func testTwoFileDeletionWithFileGroup() throws {
        try runTwoFileDeletions(withFileGroup: true)
    }
    
    func testMixedFileGroupAndNonFileGroupDeletion() throws {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString
        let fileUUID3 = Foundation.UUID().uuidString
        let fileGroupUUID = Foundation.UUID().uuidString
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }

        // These files are going to be deleted.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileGroupUUID: fileGroupUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let userId = uploadResult.uploadingUserId else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID3, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileGroupUUID: nil) else {
            XCTFail()
            return
        }
        
        // Fake pending deletion for a non-file group.
        guard let deferredUpload = createDeferredUpload(userId: userId, sharingGroupUUID: sharingGroupUUID, status: .pendingDeletion),
            let deferredUploadId = deferredUpload.deferredUploadId else {
            XCTFail()
            return
        }
    
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID3, sharingGroupUUID: sharingGroupUUID, userId: userId, deferredUploadId: deferredUploadId, state: .deleteSingleFile) else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        uploadDeletionRequest.fileGroupUUID = fileGroupUUID

        guard let _ = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false) else {
            XCTFail()
            return
        }
        
        guard let fileIndex1 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID1) else {
            XCTFail()
            return
        }
        
        guard let fileIndex2 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID2) else {
            XCTFail()
            return
        }

        guard let fileIndex3 = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID3) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex1)
        XCTAssert(!found1)
        let found2 = try fileIsInCloudStorage(fileIndex: fileIndex2)
        XCTAssert(!found2)
        let found3 = try fileIsInCloudStorage(fileIndex: fileIndex3)
        XCTAssert(!found3)
        
        XCTAssert(deferredCount == DeferredUploadRepository(db).count())
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count())))")
    }
    
    enum FileGroupDeletion {
        case deleteFileHavingFileGroupWithFileUUIDFails
        case deleteFileHavingFileGroupWithFileGroupWorks
    }
    
    func runUploadDeletion(withTest: FileGroupDeletion) throws {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        let fileGroupUUID = Foundation.UUID().uuidString

        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID, fileGroupUUID: fileGroupUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        var expectError: Bool = false
        
        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        
        switch withTest {
        case .deleteFileHavingFileGroupWithFileUUIDFails:
            uploadDeletionRequest.fileUUID = fileUUID
            expectError = true
            
        case .deleteFileHavingFileGroupWithFileGroupWorks:
            uploadDeletionRequest.fileGroupUUID = fileGroupUUID
        }
        
        let deletionResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: expectError, expectingUploaderToRun: !expectError)

        switch withTest {
        case .deleteFileHavingFileGroupWithFileUUIDFails:
            XCTAssert(deletionResult == nil)
        case .deleteFileHavingFileGroupWithFileGroupWorks:
            XCTAssert(deletionResult != nil)
        }
    }
    
    func testUploadDeletionWithFileUUIDWithFileGroupFileFails() throws {
        try runUploadDeletion(withTest: .deleteFileHavingFileGroupWithFileUUIDFails)
    }
    
    func testUploadDeletionWithFileGroupWithFileGroupFileWorks() throws {
        try runUploadDeletion(withTest: .deleteFileHavingFileGroupWithFileGroupWorks)
    }
    
    func testThatUploadDeletionTwiceOfSameFileWorks() throws {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }

        // This file is going to be deleted.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        uploadDeletionRequest.fileUUID = fileUUID
        
        guard let _ = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectingUploaderToRun: false) else {
            XCTFail()
            return
        }
        
        guard let fileIndex = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex)
        XCTAssert(!found1)
        
        XCTAssert(deferredCount == DeferredUploadRepository(db).count())
        XCTAssert(uploadCount == UploadRepository(db).count(), "\(uploadCount) != \(String(describing: UploadRepository(db).count())))")
    }
    
    func testThatDeletionOfUnknownFileUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString

        // Using this upload file only for creating a user.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        
        let unknownFileUUID = Foundation.UUID().uuidString
        uploadDeletionRequest.fileUUID = unknownFileUUID
        
        let deletionResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true, expectingUploaderToRun: false)
        XCTAssert(deletionResult == nil)
    }
    
    func testThatUploadByOneDeviceAndDeletionByAnotherActuallyDeletes() throws {
        let deviceUUID1 = Foundation.UUID().uuidString
        let deviceUUID2 = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString

        // Using this upload file only for creating a user.
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID1, fileUUID: fileUUID),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        uploadDeletionRequest.fileUUID = fileUUID
        
        let deletionResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID2, addUser: false)
        XCTAssert(deletionResult != nil)
        
        guard let fileIndex = getFileIndex(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID) else {
            XCTFail()
            return
        }
        
        let found1 = try fileIsInCloudStorage(fileIndex: fileIndex)
        XCTAssert(!found1)
    }
    
    func testThatUploadDeletionWithUnknownSharingGroupUUIDFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString

        // Using this upload file only for creating a user.
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, deviceUUID:deviceUUID, fileUUID: fileUUID) else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        let unknownSharingGroupUUID = Foundation.UUID().uuidString
        uploadDeletionRequest.sharingGroupUUID = unknownSharingGroupUUID
        uploadDeletionRequest.fileUUID = fileUUID
        
        let deletionResult = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true, expectingUploaderToRun: false)
        XCTAssert(deletionResult == nil)
    }
}
