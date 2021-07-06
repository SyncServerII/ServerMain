//
//  FileController_VN_UploadTests.swift
//  Server
//
//  Created by Christopher Prince on 7/26/17.
//
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

class FileController_VN_UploadTests: ServerTestCase, UploaderCommon {
    var accountManager: AccountManager!
    var services: Services!
    var fileIndexClientUIRepo: FileIndexClientUIRepository!

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
        
        fileIndexClientUIRepo = FileIndexClientUIRepository(db)
    }
    
    func runUploadVNFile(withMimeType: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        var mimeType: MimeType?
        
        let file:TestFile = .commentFile
        let changeResolverName = CommentFile.changeResolverName
        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)

        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let result1 = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        if withMimeType {
            mimeType = file.mimeType
        }

        let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: mimeType?.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), errorExpected: withMimeType, file: file, dataToUpload: comment.updateContents)
        if withMimeType {
            XCTAssert(result2 == nil)
        }
        else {
            XCTAssert(result2 != nil)
            
            // nil creation date with vN uploads.
            XCTAssert(result2?.response?.creationDate == nil)
        }
    }
    
    func testUploadVNFileWithoutMimeTypeWorks() {
        runUploadVNFile(withMimeType: false)
    }
    
    func testUploadVNFileWithMimeTypeFails() {
        runUploadVNFile(withMimeType: true)
    }
    
    func testUploadVNFileWithFileLabelFails() {
        let file:TestFile = .commentFile
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        let mimeType = file.mimeType
        
        let changeResolverName = CommentFile.changeResolverName
        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")

        let fileLabel = UUID().uuidString
        
        guard let result1 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: fileLabel, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup:fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: fileLabel, mimeType: mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), errorExpected: true, file: file, dataToUpload: comment.updateContents)

        XCTAssert(result2 == nil)
    }
    
    // Returns the first `UploadFileResult?`
    @discardableResult
    func runUploadOneV1TextFileWorks(informAllButSelf: Bool? = nil) -> UploadFileResult? {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        let exampleComment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
         
        // First upload the v0 file.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName, informAllButSelf: informAllButSelf),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return nil
        }
                
        // Next, upload v1 of the file -- i.e., upload just the specific change to the file.
        
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        let deferredUploads = DeferredUploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count(),
            let uploadCount1 = upload.count(),
            let deferredUploadCount1 = deferredUploads.count() else {
            XCTFail()
            return nil
        }
                
        let v1ChangeData = exampleComment.updateContents
        
        guard let result2 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: v1ChangeData, informAllButSelf: informAllButSelf) else {
            XCTFail()
            return nil
        }
        
        XCTAssert(result2.response?.deferredUploadId != nil)
        
        XCTAssert(fileIndexCount1 == fileIndex.count() )
        XCTAssert(uploadCount1 == upload.count(), "uploadCount1 (\(uploadCount1) == upload.count() \(String(describing: upload.count()))")
        XCTAssert(deferredUploadCount1 + 1 == deferredUploads.count())
        
        return result
    }
    
    func testUploadOneV1TextFileWorks() {
        runUploadOneV1TextFileWorks()
    }
    
    enum FileGroupOption {
        case sameFileGroup
        case differentFileGroup
        case noFileGroup
    }
    
    func runUploadOfSameFile(fileGroupOption: FileGroupOption) {
        let testAccount: TestAccount = .primaryOwningAccount
        
        let fileUUID = Foundation.UUID().uuidString
        let deviceUUID = Foundation.UUID().uuidString

        let file:TestFile = .commentFile
        let changeResolverName = CommentFile.changeResolverName
        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        
        let fileGroup1 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        var fileGroup2: FileGroup?
        
        let expectedError: Bool
        
        switch fileGroupOption {
        case .sameFileGroup:
            fileGroup2 = fileGroup1
            expectedError = true
        case .differentFileGroup:
            fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
            expectedError = true
        case .noFileGroup:
            expectedError = false
        }
        
        guard let result1 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .yes, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup1, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), errorExpected: expectedError, file: file,  dataToUpload: comment.updateContents, fileGroup:fileGroup2)

        switch fileGroupOption {
        case .sameFileGroup, .differentFileGroup:
            XCTAssert(result2 == nil)
        case .noFileGroup:
            XCTAssert(result2 != nil)
        }
    }
    
    func testUploadOfSameFileWithDifferentFileGroupFails() {
        runUploadOfSameFile(fileGroupOption: .differentFileGroup)
    }

    func testUploadOfSameFileWithSameFileGroupFails() {
        runUploadOfSameFile(fileGroupOption: .sameFileGroup)
    }
    
    func testUploadOfSameFileWithNoFileGroupWorks() {
        runUploadOfSameFile(fileGroupOption: .noFileGroup)
    }
    
    func testUploadV1TextFileWithDifferentDeviceUUIDWorks() {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID1 = Foundation.UUID().uuidString
        let deviceUUID2 = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        let exampleComment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
         
        // First upload the v0 file.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID1, fileUUID: fileUUID,  fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
                
        // Next, upload v1 of the file -- i.e., upload just the specific change to the file.
        
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        let deferredUploads = DeferredUploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count(),
            let uploadCount1 = upload.count(),
            let deferredUploadCount1 = deferredUploads.count() else {
            XCTFail()
            return
        }
                
        let v1ChangeData = exampleComment.updateContents
        
        guard let result2 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID2, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: v1ChangeData) else {
            XCTFail()
            return
        }
        
        XCTAssert(result2.response?.deferredUploadId != nil)
        
        XCTAssert(fileIndexCount1 == fileIndex.count() )
        XCTAssert(uploadCount1 == upload.count())
        XCTAssert(deferredUploadCount1 + 1 == deferredUploads.count())
    }
    
    func runUploadTwoV1TextFilesInSameSharingGroupWorks() {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString
        let batchUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let exampleComment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let exampleComment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // First upload the v0 files.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 2, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 2, uploadCount: 2, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName) else {
            XCTFail()
            return
        }
        
        // Next, upload v1 of the files -- i.e., upload just the specific changes to the files.
        
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        let deferredUploads = DeferredUploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count(),
            let uploadCount1 = upload.count(),
            let deferredUploadCount1 = deferredUploads.count() else {
            XCTFail()
            return
        }
                
        let v1ChangeData1 = exampleComment1.updateContents
        let v1ChangeData2 = exampleComment2.updateContents
        
        Log.debug("Starting vN uploads...")
        
        let batchUUID2 = UUID().uuidString

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 2, batchUUID: batchUUID2, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID1, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: v1ChangeData1) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 2, uploadCount: 2, batchUUID: batchUUID2, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: v1ChangeData2) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndexCount1 == fileIndex.count() )
        XCTAssert(uploadCount1 == upload.count())
        XCTAssert(deferredUploadCount1 + 1 == deferredUploads.count(), "deferredUploadCount1: \(deferredUploadCount1) == deferredUploads.count(): \(String(describing: deferredUploads.count()))")
    }
    
    func testUploadTwoV1TextFilesInSameSharingGroupWorks() {
        runUploadTwoV1TextFilesInSameSharingGroupWorks()
    }
    
    // Single changes for each of two files.
    func runUploadTwoV1Changes(fromDifferentFileGroupsInSameBatch: Bool) {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString

        let fileGroup1 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let fileGroup2: FileGroup

        if fromDifferentFileGroupsInSameBatch {
            fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        }
        else {
            fileGroup2 = fileGroup1
        }
        
        let exampleComment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let exampleComment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // First upload the v0 files. Will use separate batches here. What I want to test is the VN upload process.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup1, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup2, changeResolverName: changeResolverName)
        
        // Next, upload v1 of the files -- i.e., upload just the specific changes to the files.
        
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        let deferredUploads = DeferredUploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count(),
            let uploadCount1 = upload.count(),
            let deferredUploadCount1 = deferredUploads.count() else {
            XCTFail()
            return
        }
                
        let v1ChangeData1 = exampleComment1.updateContents
        let v1ChangeData2 = exampleComment2.updateContents
        
        Log.debug("Starting vN uploads...")
        let batchUUID = UUID().uuidString
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 2, batchUUID: batchUUID, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID1, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, dataToUpload: v1ChangeData1) else {
            XCTFail()
            return
        }
        
        // Expecting a failure here.
        let result2 = uploadTextFile(uploadIndex: 2, uploadCount: 2, batchUUID: batchUUID, testAccount: .primaryOwningAccount, mimeType: nil, deviceUUID: deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, errorExpected: fromDifferentFileGroupsInSameBatch, dataToUpload: v1ChangeData2)
        
        if !fromDifferentFileGroupsInSameBatch {
            XCTAssert(result2 != nil)
            XCTAssert(fileIndexCount1 == fileIndex.count() )
            XCTAssert(uploadCount1 == upload.count())
            XCTAssert(deferredUploadCount1 + 1 == deferredUploads.count(), "deferredUploadCount1 + 1: \(deferredUploadCount1) != deferredUploads.count(): \(String(describing: deferredUploads.count()))")
        }
    }
    
    func testUploadTwoV1ChangesFromDifferentFileGroupsInSameBatchFails() {
        runUploadTwoV1Changes(fromDifferentFileGroupsInSameBatch: true)
    }
    
    func testUploadTwoV1ChangesFromSameFileGroupsInSameBatchWorks() {
        runUploadTwoV1Changes(fromDifferentFileGroupsInSameBatch: false)
    }
    
    // I'd like to run a test with multiple sharing groups, so that the Uploader async processing for the multiple groups takes place together.
    // Normally, in my test setup, this wouldn't happen. The Uploader run for the first batch would take place together, and the second batch would likely have to wait.
    // However, this situation, with the multiple sharing groups, is possible. It can happen if a Uploader run attempt after a batch upload can't get the lock because some other server instance has the lock.
    // I can do this test by faking the upload of the first batch: I can simulate another device/client uploading the first batch of files by uploading the file directly and making additions to FileIndex, Upload and DeferredUpload directly.
    // And then, the second batch can be done as usual-- with the regular file upload endpoint.
    func testUploadV1TextFilesInDifferentSharingGroupsWorks() {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString

        let fileGroup1 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        let comment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // First, do the v0 uploads.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup1, changeResolverName: changeResolverName),
            let sharingGroupUUID1 = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let sharingGroup = ServerShared.SharingGroup()
        sharingGroup.sharingGroupName = "Louisiana Guys"
        let sharingGroupUUID2 = UUID().uuidString
        
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID2), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup2, changeResolverName: changeResolverName) else {
            XCTFail()
            return
        }
        
        let fileIndexRepo = FileIndexRepository(db)
        let uploadRepo = UploadRepository(db)
        let deferredUploadsRepo = DeferredUploadRepository(db)
        
        guard let fileIndexCount1 = fileIndexRepo.count(),
            let uploadCount1 = uploadRepo.count(),
            let deferredUploadCount1 = deferredUploadsRepo.count() else {
            XCTFail()
            return
        }

        // Next, prepare the vN uploads-- not using the upload file endpoint for the first one-- faking that another server instance uploaded it and it didn't have an Uploader run occurring.
        
       guard let fileIndex = getFileIndex(fileUUID: fileUUID1) else {
            XCTFail()
            return
        }
        
        guard let fileGroupModel1 = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup1.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let fileGroupModel2 = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup2.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let deferredUpload1 = createDeferredUpload(userId: fileGroupModel1.userId, fileGroupUUID: fileGroup1.fileGroupUUID, sharingGroupUUID: sharingGroupUUID1, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }
        
        let batchUUID = UUID().uuidString
        
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, sharingGroupUUID: sharingGroupUUID1, userId: fileGroupModel1.userId, deferredUploadId: deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID) else {
            XCTFail()
            return
        }
        
        // Can do the second one normally. Both this upload and the faked one should get processed by Uploader run.
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID2), fileLabel: nil, dataToUpload: comment2.updateContents) else {
            XCTFail()
            return
        }
        
        guard let fileIndex1 = getFileIndex(fileUUID: fileUUID1) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex1.fileVersion == 1, "\(String(describing: fileIndex1.fileVersion))")
        
        guard let fileIndex2 = getFileIndex(fileUUID: fileUUID2) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileIndex2.fileVersion == 1, "\(String(describing: fileIndex2.fileVersion))")
        
        XCTAssert(fileIndexCount1 == fileIndexRepo.count(), "fileIndexCount1: \(fileIndexCount1) != fileIndexRepo.count(): \(String(describing: fileIndexRepo.count()))")
        XCTAssert(uploadCount1 == uploadRepo.count(), "uploadCount1: \(uploadCount1) != uploadRepo.count(): \(String(describing: uploadRepo.count()))")
        XCTAssert(deferredUploadCount1 + 2 == deferredUploadsRepo.count())
    }
    
    func testUploadTwoChangesToTheSameFileWorks() throws {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        let comment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // First, do the v0 uploads.
        
        let fileGroup:FileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")
        
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID1 = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Prepare the v1 uploads
        
        guard let fg = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        // This upload needs to be with a different user. (We don't allow 2 rows in the Upload table with the same fileUUID and userId).
        let otherUserId = fg.owningUserId + 1
        guard let deferredUpload1 = createDeferredUpload(userId: otherUserId, fileGroupUUID: fileGroup.fileGroupUUID, sharingGroupUUID: sharingGroupUUID1, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }

        let batchUUID = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID1, userId: otherUserId, deferredUploadId: deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: nil, dataToUpload: comment2.updateContents) else {
            XCTFail()
            return
        }
        
        guard let mimeType = result.request.mimeType else {
            XCTFail()
            return
        }
        
        let (_, cloudStorage) = try UserRepository(db).getCloudStorage(owningUserId: fg.owningUserId, services: services.uploaderServices)
        let cloudFileName = Filename.inCloud(deviceUUID: deviceUUID, fileUUID: fileUUID, mimeType: mimeType, fileVersion: 1)
        let options = CloudStorageFileNameOptions(cloudFolderName: ServerTestCase.cloudFolderName, mimeType: mimeType)
        
        var commentFileData: Data!
        
        let exp = expectation(description: "download")
        
        cloudStorage.downloadFile(cloudFileName: cloudFileName, options: options) { result in
            switch result {
            case .success(data: let data, checkSum: _):
                commentFileData = data
            default:
                XCTFail()
                return
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        
        let commentFile = try CommentFile(with: commentFileData)
        
        guard lookup(comment: comment1, commentFile: commentFile) else {
            XCTFail()
            return
        }
        
        guard lookup(comment: comment2, commentFile: commentFile) else {
            XCTFail()
            return
        }
        
        let comment3 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)
        guard !lookup(comment: comment3, commentFile: commentFile) else {
            XCTFail()
            return
        }
    }
    
    func runUploadVersionN(withAppMetaData: Bool) {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        let comment = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobly")
        
        // First, do the v0 uploads.
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result.sharingGroupUUID else {
            XCTFail()
            return
        }
                
        var appMetaData: String?
        if withAppMetaData {
            appMetaData = "Example app meta data"
        }
        
        let result2 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: nil, appMetaData: appMetaData, errorExpected: withAppMetaData, dataToUpload: comment.updateContents)
        
        if withAppMetaData {
            XCTAssert(result2 == nil)
        }
        else {
            XCTAssert(result2 != nil)
        }
    }
    
    func testUploadAppMetaDataWithVersionNFails() {
        runUploadVersionN(withAppMetaData: true)
    }

    func testUploadWithoutAppMetaDataWithVersionNWorks() {
        runUploadVersionN(withAppMetaData: false)
    }

    func lookup(comment: ExampleComment, commentFile: CommentFile) -> Bool {
        for element in 0..<commentFile.count {
            guard let fileComment = commentFile[element] else {
                XCTFail()
                return false
            }
            
            guard let id = fileComment[CommentFile.idKey] as? String else {
                return false
            }

            guard let message = fileComment[ExampleComment.messageKey] as? String else {
                return false
            }
            
            if id == comment.id && message == comment.messageString {
                return true
            }
        }
        
        return false
    }
    
    func runUploadVNFile(withChangeResolver: Bool) {
        let file:TestFile = .commentFile
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        
        let changeResolverName = CommentFile.changeResolverName

        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")

        guard let result1 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup:fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        var secondChangeResolver: String?
        if withChangeResolver {
            secondChangeResolver = changeResolverName
        }
        
        let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), errorExpected: withChangeResolver, file: file, dataToUpload: comment.updateContents, changeResolverName: secondChangeResolver)
        
        XCTAssert((result2 == nil) == withChangeResolver)
    }
    
    func testUploadVNWithChangeResolverFails() {
        runUploadVNFile(withChangeResolver: true)
    }
    
    func testUploadVNWithoutChangeResolverWorks() {
        runUploadVNFile(withChangeResolver: false)
    }
    
    enum ChangeResolverTest {
        case v0HadNoChangeResolver
        case uploadedChangeIsBad
        case v0HadChangeResolverAndUploadedChangeIsGood
    }
    
    func runUploadVNFile(changeResolverTest: ChangeResolverTest) {
        let file:TestFile = .commentFile
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        var changeResolverName: String?
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")

        let comment = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
                
        if changeResolverTest != .v0HadNoChangeResolver {
            changeResolverName = CommentFile.changeResolverName
        }

        guard let result1 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, file: file, fileGroup: fileGroup, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let dataToUpload: Data
        let errorExpected: Bool
        
        switch changeResolverTest {
        case .uploadedChangeIsBad:
            errorExpected = true
            dataToUpload = "Some bad data".data(using: .utf8)!
            
        case .v0HadChangeResolverAndUploadedChangeIsGood:
            errorExpected = false
            dataToUpload = comment.updateContents
            
        case .v0HadNoChangeResolver:
            errorExpected = true
            dataToUpload = comment.updateContents
        }
        
        let result2 = uploadServerFile(uploadIndex: 1,  uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), errorExpected: errorExpected, file: file, dataToUpload: dataToUpload)
        
        switch changeResolverTest {
        case .uploadedChangeIsBad, .v0HadNoChangeResolver:
            XCTAssert(result2 == nil)
            
        case .v0HadChangeResolverAndUploadedChangeIsGood:
            XCTAssert(result2 != nil)
        }
    }

    func testUploadVNFileV0HadNoChangeResolverFails() {
        runUploadVNFile(changeResolverTest: .v0HadNoChangeResolver)
    }
    
    func testUploadVNFileUploadedChangeIsBadFails() {
        runUploadVNFile(changeResolverTest: .uploadedChangeIsBad)
    }
    
    func testUploadVNFileV0HadChangeResolverAndUploadedChangeIsGoodWorks() {
        runUploadVNFile(changeResolverTest: .v0HadChangeResolverAndUploadedChangeIsGood)
    }
    
    // MARK: Upload vN file(s) and check for FileIndexClientUI record(s).

    func testUploadOneV1TextFileWithoutInformAllButSelf_checkFileIndexClientUI() {
        guard let uploadResult = runUploadOneV1TextFileWorks() else {
            XCTFail()
            return
        }
        
        guard let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID)
        let lookupResult = fileIndexClientUIRepo.lookup(key: key, modelInit: FileIndexClientUI.init)
        switch lookupResult {
        case .found:
            XCTFail()
        case .noObjectFound:
            break
        default:
            XCTFail()
            return
        }
    }
    
    func testUploadOneV1TextFileWithInformAllButSelf_checkFileIndexClientUI() {
        guard let uploadResult = runUploadOneV1TextFileWorks(informAllButSelf: true) else {
            XCTFail()
            return
        }
        
        guard let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        guard let fileUUID = uploadResult.request.fileUUID else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID)
        guard let fileIndexClientUIRecords = fileIndexClientUIRepo.lookupAll(key: key, modelInit: FileIndexClientUI.init) else {
            XCTFail()
            return
        }
        
        // There are two records-- one for v0 of the file, the other for v1.
        XCTAssert(fileIndexClientUIRecords.count == 2)
        
        let v0 = fileIndexClientUIRecords.filter { $0.fileVersion == 0}
        guard v0.count == 1 else {
            XCTFail()
            return
        }
        XCTAssert(v0[0].fileUUID == fileUUID)
        XCTAssert(v0[0].sharingGroupUUID == sharingGroupUUID)

        let v1 = fileIndexClientUIRecords.filter { $0.fileVersion == 1}
        guard v1.count == 1 else {
            XCTFail()
            return
        }
        XCTAssert(v1[0].fileUUID == fileUUID)
        XCTAssert(v1[0].sharingGroupUUID == sharingGroupUUID)
    }
    
    func testMultipleMutationsInBatchWithInformAllButSelf_checkFileIndexClientUI() throws {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        let fileGroupUUID = Foundation.UUID().uuidString
        
        let comment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // First, do the v0 upload.
        
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUID, objectType: "ObjectType")
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName, informAllButSelf: true),
            let sharingGroupUUID1 = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // Prepare the v1 uploads
        
        guard let fg = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        // This upload needs to be with a different user. (We don't allow 2 rows in the Upload table with the same fileUUID and userId).
        let otherUserId = fg.owningUserId + 1
        guard let deferredUpload1 = createDeferredUpload(userId: otherUserId, fileGroupUUID: fileGroupUUID, sharingGroupUUID: sharingGroupUUID1, batchUUID: nil, status: .pendingChange),
            let deferredUploadId1 = deferredUpload1.deferredUploadId else {
            XCTFail()
            return
        }

        let batchUUID = UUID().uuidString

        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID, fileGroup: fileGroup, sharingGroupUUID: sharingGroupUUID1, userId: otherUserId, deferredUploadId: deferredUploadId1, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID, informAllButSelf: true) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: nil, dataToUpload: comment2.updateContents, informAllButSelf: true) else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID1)
        guard let fileIndexClientUIRecords = fileIndexClientUIRepo.lookupAll(key: key, modelInit: FileIndexClientUI.init) else {
            XCTFail()
            return
        }
        
        // One FileIndexClientUI record for the original v0 upload, and one additional FileIndexClientUI record for each upload in the v1 batch.
        XCTAssert(fileIndexClientUIRecords.count == 3, "fileIndexClientUIRecords.count: \(fileIndexClientUIRecords.count)")
        
        let v0 = fileIndexClientUIRecords.filter { $0.fileVersion == 0}
        XCTAssert(v0.count == 1)
        
        let v1 = fileIndexClientUIRecords.filter { $0.fileVersion == 1}
        XCTAssert(v1.count == 2)
    }
    
    // Multiple mutations across successive batches
    func testMutationsSuccessiveBatchesWithInformAllButSelf_checkFileIndexClientUI() throws {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        let fileGroupUUID = Foundation.UUID().uuidString
        
        let comment1 = ExampleComment(messageString: "Hello, World", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Goodbye!", id: Foundation.UUID().uuidString)

        // v0 upload.
        
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUID, objectType: "ObjectType")
  
        guard let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup, changeResolverName: changeResolverName, informAllButSelf: true),
            let sharingGroupUUID1 = result.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        // v1 upload.
        // (We don't give a file group here b/c we only give a file group with v0 uploads.)
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: nil, dataToUpload: comment1.updateContents, informAllButSelf: true) else {
            XCTFail()
            return
        }
        
        // v2 upload.
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, mimeType: nil, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: nil, dataToUpload: comment2.updateContents, informAllButSelf: true) else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID1)
        guard let fileIndexClientUIRecords = fileIndexClientUIRepo.lookupAll(key: key, modelInit: FileIndexClientUI.init) else {
            XCTFail()
            return
        }

        // One FileIndexClientUI record for the original v0 upload, and one each for the additional two file versions.
        XCTAssert(fileIndexClientUIRecords.count == 3, "fileIndexClientUIRecords.count: \(fileIndexClientUIRecords.count)")
        
        let v0 = fileIndexClientUIRecords.filter { $0.fileVersion == 0}
        XCTAssert(v0.count == 1)
        
        let v1 = fileIndexClientUIRecords.filter { $0.fileVersion == 1}
        XCTAssert(v1.count == 1)
        
        let v2 = fileIndexClientUIRecords.filter { $0.fileVersion == 2}
        XCTAssert(v2.count == 1)
    }
}

