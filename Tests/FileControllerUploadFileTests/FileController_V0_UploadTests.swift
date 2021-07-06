//
//  FileController_V0_UploadTests.swift
//  Server
//
//  Created by Christopher Prince on 3/22/17.
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
import ServerGoogleAccount
import ServerAccount
import KituraNet

class FileController_V0_UploadTests: ServerTestCase {
    var fileIndexClientUIRepo: FileIndexClientUIRepository!
    var userRepo: UserRepository!

    override func setUp() {
        super.setUp()
        fileIndexClientUIRepo = FileIndexClientUIRepository(db)
        userRepo = UserRepository(db)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    /*
    Testing parameters:
        1) Type of file (e.g., JPEG, text, URL)
        2) Number of uploads in batch: 1, 2, ...
            Done uploads triggered?
     */
     
    // MARK: file upload, v0, 1 of 1 files.
    struct UploadResult {
        let deviceUUID: String
        let fileUUID: String
        let sharingGroupUUID: String?
    }
    
    @discardableResult
    func uploadSingleV0File(changeResolverName: String? = nil, expectError: Bool = false, uploadSingleFile:(_ deviceUUID: String, _ fileUUID: String, _ changeResolverName: String?)->(ServerTestCase.UploadFileResult?)) -> UploadResult? {
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count() else {
            XCTFail()
            return nil
        }
        
        guard let uploadCount1 = upload.count() else {
            XCTFail()
            return nil
        }
        
        let deviceUUID = Foundation.UUID().uuidString
        
        let fileUUID = Foundation.UUID().uuidString
        
        guard let result = uploadSingleFile(deviceUUID, fileUUID, changeResolverName) else {
            if expectError {
                return nil
            }
            XCTFail()
            return nil
        }
        
        XCTAssert(result.response?.creationDate != nil)
        XCTAssert(result.response?.allUploadsFinished == .v0UploadsFinished)
                
        guard let fileIndexCount2 = fileIndex.count() else {
            XCTFail()
            return nil
        }
        
        guard let uploadCount2 = upload.count() else {
            XCTFail()
            return nil
        }
        
        // Make sure the file index has another row.
        XCTAssert(fileIndexCount1 + 1 == fileIndexCount2)
        
        // And the upload table has no more rows after.
        XCTAssert(uploadCount1 == uploadCount2)
        
        return UploadResult(deviceUUID: deviceUUID, fileUUID: fileUUID, sharingGroupUUID: result.sharingGroupUUID)
    }
    
    func testUploadSingleV0TextFile() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        let uploadResult = uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup)
        }
        
        guard let sharingGroupUUID = uploadResult?.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID)
        let lookupResult = fileIndexClientUIRepo.lookup(key: key, modelInit: FileIndexClientUI.init)
        switch lookupResult {
        case .found:
            XCTFail()
            return
        case .noObjectFound:
            break
        default:
            XCTFail()
            return
        }
    }
    
    func runUploadV0File(file: TestFile, mimeType: String?, errorExpected: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString
        
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: mimeType, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, errorExpected: errorExpected, file: file, fileGroup: fileGroup)
        
        XCTAssert((uploadResult == nil) == errorExpected)
    }
    
    func testUpoadV0WithoutFileLabelFails() {
        let file:TestFile = .test1
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: nil, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, errorExpected: true, file: file, fileGroup: fileGroup)
        
        XCTAssert(uploadResult == nil)
    }
    
    func testUploadV0FileWithoutMimeTypeFails() {
        let file:TestFile = .test1
        runUploadV0File(file: file, mimeType: nil, errorExpected: true)
    }
    
    func testUploadV0FileWithoutBadMimeTypeFails() {
        let file:TestFile = .test1
        runUploadV0File(file: file, mimeType: "foobar", errorExpected: true)
    }
    
    func testUploadV0FileWithMimeTypeWorks() {
        let file:TestFile = .test1
        runUploadV0File(file: file, mimeType: file.mimeType.rawValue, errorExpected: false)
    }
    
    func testUploadSingleV0JPEGFile() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadJPEGFile(batchUUID: UUID().uuidString, deviceUUID: deviceUUID, fileUUID: fileUUID, fileGroup: fileGroup)
        }
    }

    func testUploadSingleV0URLFile() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadFileUsingServer(batchUUID: UUID().uuidString, deviceUUID: deviceUUID, fileUUID: fileUUID, mimeType: .url, file: .testUrlFile, fileLabel: UUID().uuidString, fileGroup: fileGroup)
        }
    }
    
    func testUploadSingleV0MovFile() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadMovFile(batchUUID: UUID().uuidString, deviceUUID: deviceUUID, fileUUID: fileUUID, fileGroup: fileGroup)
        }
    }
    
    func testUploadSingleV0PngFile() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadPngFile(batchUUID: UUID().uuidString, deviceUUID: deviceUUID, fileUUID: fileUUID, fileGroup: fileGroup)
        }
    }
    
    // With non-nil changeResolverName
    let changeResolverName = CommentFile.changeResolverName
    
    // TODO: Upload a single file, with a non-nil fileGroupUUID
    
    // MARK: file upload, v0, 1 of 2 files, and then 2 of 2 files.
    
    // Returns the sharingGroupUUID
    @discardableResult
    func uploadTwoV0Files(fileUUIDs: [String],
        uploadSingleFile:(_ addUser:AddUser, _ deviceUUID: String, _ fileUUID: String, _ uploadIndex: Int32, _ uploadCount: Int32)->(ServerTestCase.UploadFileResult?)) -> String? {
        let fileIndex = FileIndexRepository(db)
        let upload = UploadRepository(db)
        
        guard let fileIndexCount1 = fileIndex.count(),
            let uploadCount1 = upload.count()  else {
            XCTFail()
            return nil
        }
        
        let deviceUUID = Foundation.UUID().uuidString
        
        var uploadIndex: Int32 = 1
        let uploadCount: Int32 = Int32(fileUUIDs.count)
        var addUser:AddUser = .yes

        guard let result1 = uploadSingleFile(addUser, deviceUUID, fileUUIDs[Int(uploadIndex)-1], uploadIndex, uploadCount),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return nil
        }
        
        addUser = .no(sharingGroupUUID: sharingGroupUUID)

        XCTAssert(result1.response?.allUploadsFinished == .uploadsNotFinished)
                
        guard let fileIndexCount2 = fileIndex.count() else {
            XCTFail()
            return nil
        }
        
        guard let uploadCount2 = upload.count() else {
            XCTFail()
            return nil
        }
        
        XCTAssert(fileIndexCount1 == fileIndexCount2)
        XCTAssert(uploadCount1 + 1 == uploadCount2)
        
        uploadIndex += 1
        guard let result2 = uploadSingleFile(addUser, deviceUUID, fileUUIDs[Int(uploadIndex)-1], uploadIndex, uploadCount) else {
            XCTFail()
            return nil
        }

        XCTAssert(result2.response?.allUploadsFinished == .v0UploadsFinished)
                
        guard let fileIndexCount3 = fileIndex.count() else {
            XCTFail()
            return nil
        }
        
        guard let uploadCount3 = upload.count() else {
            XCTFail()
            return nil
        }
        
        XCTAssert(fileIndexCount1 + 2 == fileIndexCount3)
        XCTAssert(uploadCount3 == uploadCount1)
        
        return sharingGroupUUID
    }
    
    func testUploadTwoV0TextFiles() {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let batchUUID = UUID().uuidString
        
        uploadTwoV0Files(fileUUIDs: fileUUIDs) { addUser, deviceUUID, fileUUID, uploadIndex, uploadCount in
            return uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: addUser, fileLabel: UUID().uuidString, fileGroup: fileGroup)
        }
    }
    
    func testUploadTwoV0JPEGFiles() {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let batchUUID = UUID().uuidString
        
        uploadTwoV0Files(fileUUIDs: fileUUIDs) { addUser, deviceUUID, fileUUID, uploadIndex, uploadCount in
            return uploadJPEGFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID: deviceUUID, fileUUID: fileUUID, addUser: addUser, fileGroup: fileGroup)
        }
    }
    
    func testUploadTwoV0URLFiles() {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foobar")
        let batchUUID = UUID().uuidString
        
        uploadTwoV0Files(fileUUIDs: fileUUIDs) { addUser, deviceUUID, fileUUID, uploadIndex, uploadCount in
            return uploadFileUsingServer(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID: deviceUUID, fileUUID: fileUUID, mimeType: .url, file: .testUrlFile, fileLabel: UUID().uuidString, addUser: addUser, fileGroup: fileGroup)
        }
    }
    
   func uploadTwoV0FilesWith(differentFileGroupUUIDs: Bool) {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let deviceUUID = Foundation.UUID().uuidString
        let batchUUID = UUID().uuidString
        
        var uploadIndex: Int32 = 1
        let uploadCount: Int32 = Int32(fileUUIDs.count)
        var addUser:AddUser = .yes
        let fileGroup1 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let result1 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, fileGroup: fileGroup1),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        addUser = .no(sharingGroupUUID: sharingGroupUUID)

        XCTAssert(result1.response?.allUploadsFinished == .uploadsNotFinished)

        let fileGroup2: FileGroup
        if differentFileGroupUUIDs {
            fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        }
        else {
            fileGroup2 = fileGroup1
        }
        
        uploadIndex += 1
        
        let result2 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, errorExpected: differentFileGroupUUIDs, fileGroup:fileGroup2)
        
        if differentFileGroupUUIDs {
            XCTAssert(result2 == nil)
        }
        else {
            XCTAssert(result2?.response?.allUploadsFinished == .v0UploadsFinished)
        }
    }
    
    func testUploadTwoV0FilesWithSameFileGroupUUIDsWorks() {
        uploadTwoV0FilesWith(differentFileGroupUUIDs: false)
    }
    
    func testUploadTwoV0FilesWithDifferentFileGroupUUIDsFails() {
        uploadTwoV0FilesWith(differentFileGroupUUIDs: true)
    }
    
   func uploadTwoV0FilesWith(nilFileGroupUUIDs: Bool) {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let deviceUUID = Foundation.UUID().uuidString
        let batchUUID = Foundation.UUID().uuidString
        
        var uploadIndex: Int32 = 1
        let uploadCount: Int32 = Int32(fileUUIDs.count)
        var addUser:AddUser = .yes
        var fileGroup: FileGroup?
        
        if !nilFileGroupUUIDs {
            fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        }
        
        guard let result1 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        addUser = .no(sharingGroupUUID: sharingGroupUUID)

        XCTAssert(result1.response?.allUploadsFinished == .uploadsNotFinished)
        
        uploadIndex += 1
        
        let result2 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, errorExpected: nilFileGroupUUIDs, fileGroup:fileGroup)
        
        if nilFileGroupUUIDs {
            XCTAssert(result2 == nil)
        }
        else {
            XCTAssert(result2?.response?.allUploadsFinished == .v0UploadsFinished)
            
            guard let fileGroup = fileGroup else {
                XCTFail()
                return
            }
            
            let fileGroupRepo = FileGroupRepository(db)
            
            let key = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fileGroup.fileGroupUUID)
            let lookupResult = fileGroupRepo.lookup(key: key, modelInit: FileGroupModel.init)

            if case .found(let model) = lookupResult,
                let fg = model as? FileGroupModel {
                XCTAssert(fg.fileGroupUUID == fileGroup.fileGroupUUID)
                XCTAssert(fg.userId != nil)
                XCTAssert(fg.owningUserId != nil)
                XCTAssert(fg.objectType == result2?.request.objectType)
                XCTAssert(fg.sharingGroupUUID == result2?.request.sharingGroupUUID)
            }
            else {
                XCTFail()
            }
        }
    }
    
    func testUploadTwoV0FilesWithNonNilFileGroupUUIDsWorks() {
        uploadTwoV0FilesWith(nilFileGroupUUIDs: false)
    }
    
    func testUploadTwoV0FilesWithNilFileGroupUUIDsFails() {
        uploadTwoV0FilesWith(nilFileGroupUUIDs: true)
    }
    
   func uploadTwoV0FilesWith(oneFileHasNilGroupUUID: Bool) {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let deviceUUID = Foundation.UUID().uuidString
        let batchUUID = Foundation.UUID().uuidString
        
        var uploadIndex: Int32 = 1
        let uploadCount: Int32 = Int32(fileUUIDs.count)
        var addUser:AddUser = .yes
        var fileGroup: FileGroup? = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        guard let result1 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }

        addUser = .no(sharingGroupUUID: sharingGroupUUID)

        XCTAssert(result1.response?.allUploadsFinished == .uploadsNotFinished)
        
        uploadIndex += 1
        if oneFileHasNilGroupUUID {
            fileGroup = nil
        }
        
        let result2 = uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUIDs[Int(uploadIndex)-1], addUser: addUser, fileLabel: UUID().uuidString, errorExpected: oneFileHasNilGroupUUID, fileGroup:fileGroup)
        
        if oneFileHasNilGroupUUID {
            XCTAssert(result2 == nil)
        }
        else {
            XCTAssert(result2?.response?.allUploadsFinished == .v0UploadsFinished)
        }
    }
    
    func testUploadTwoV0FilesBothNonNilFileGroupUUIDsWorks() {
        uploadTwoV0FilesWith(oneFileHasNilGroupUUID: false)
    }
    
    func testUploadTwoV0FilesOneNilFileGroupUUIDsFails() {
        uploadTwoV0FilesWith(oneFileHasNilGroupUUID: true)
    }
    
    // MARK: file upload, vN, 1 of 1 files.
    
    
    // TODO: Try a v0 upload with a bad change resolver name. Make sure it fails.
    
    func testUploadFileWithJSONAppMetaDataWorks() {
        let fileUUID = Foundation.UUID().uuidString
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "{ \"foo\": \"bar\" }"
        
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, appMetaData: appMetaData, fileGroup: fileGroup) else {
            XCTFail()
            return
        }
    }
    
    func runChangeResolverUploadTest(withValidV0: Bool) {
        let changeResolverName = CommentFile.changeResolverName
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
         
        let file: TestFile
        if withValidV0 {
            file = .commentFile
        }
        else {
            file = .test1
        }
        
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, errorExpected:!withValidV0, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName)
        
        XCTAssert((result != nil) == withValidV0)
    }
    
    func testUploadV0FileWithInvalidV0ChangeResolverFails() {
        runChangeResolverUploadTest(withValidV0: false)
    }
    
    func testUploadV0FileWithValidV0ChangeResolverWorks() {
        runChangeResolverUploadTest(withValidV0: true)
    }

    func runChangeResolverUploadTest(withValidChangeResolverName: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        let file: TestFile = .commentFile

        let changeResolverName: String
        if withValidChangeResolverName {
            changeResolverName = CommentFile.changeResolverName
        }
        else {
            changeResolverName = "foobar"
        }

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        let result = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, errorExpected:!withValidChangeResolverName, stringFile: file, fileGroup: fileGroup, changeResolverName: changeResolverName)
        
        XCTAssert((result != nil) == withValidChangeResolverName)
    }
    
    func testUploadV0FileWithInvalidChangeResolverNameFails() {
        runChangeResolverUploadTest(withValidChangeResolverName: false)
    }
    
    func testUploadV0FileWithValidChangeResolverNameWorks() {
        runChangeResolverUploadTest(withValidChangeResolverName: true)
    }
    
    func testRunV0UploadCheckSumTestWith(file: TestFile, errorExpected: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let testAccount:TestAccount = .primaryOwningAccount
        let fileUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        let uploadResult = uploadServerFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount:testAccount, fileLabel: UUID().uuidString, mimeType: file.mimeType.rawValue, deviceUUID:deviceUUID, fileUUID: fileUUID, cloudFolderName: ServerTestCase.cloudFolderName, errorExpected: errorExpected, file: file, fileGroup: fileGroup)
        
        XCTAssert((uploadResult == nil) == errorExpected)
    }
    
    func testUploadV0FileWithGoodCheckSumWorks() {
        testRunV0UploadCheckSumTestWith(file: .test1, errorExpected: false)
    }
    
    func testUploadV0FileWithNoCheckSumFails() {
        testRunV0UploadCheckSumTestWith(file: .testNoCheckSum, errorExpected: true)
    }
    
    func testUploadV0FileWithBadCheckSumFails() {
        testRunV0UploadCheckSumTestWith(file: .testBadCheckSum, errorExpected: true)
    }
    
    func runtestUploadWith(invalidSharingUUID: Bool) {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let upload1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = upload1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let secondSharingGroupUUID: String
        if invalidSharingUUID {
            secondSharingGroupUUID = UUID().uuidString
        }
        else {
            secondSharingGroupUUID = sharingGroupUUID
        }

        let fileGroup2 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo2")

        let upload2 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: secondSharingGroupUUID), fileLabel: UUID().uuidString, errorExpected: invalidSharingUUID, fileGroup: fileGroup2)
        
        XCTAssert((upload2 == nil) == invalidSharingUUID)
    }
    
    func testUploadWithInvalidSharingGroupUUIDFails() {
        runtestUploadWith(invalidSharingUUID: true)
    }
    
    func testUploadWithValidSharingGroupUUIDWorks() {
        runtestUploadWith(invalidSharingUUID: false)
    }
        
    func upload(sameFileTwiceInSameBatch: Bool) {
        let fileUUID = UUID().uuidString
        let deviceUUID = UUID().uuidString
        let batchUUID = UUID().uuidString

        var uploadCount:Int32 = 1
        if sameFileTwiceInSameBatch {
            uploadCount = 2
        }

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo2")

        guard let upload1 = uploadTextFile(uploadIndex: 1, uploadCount: uploadCount, batchUUID:batchUUID, deviceUUID: deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = upload1.sharingGroupUUID else {
            XCTFail()
            return
        }

        if sameFileTwiceInSameBatch {
            guard let upload2 = uploadTextFile(uploadIndex: 2, uploadCount: uploadCount, batchUUID:batchUUID, deviceUUID: deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
                XCTFail()
                return
            }
            
            XCTAssert(upload2.response?.allUploadsFinished == .duplicateFileUpload)
        }
    }
    
    func testUploadSameFileInBatchBySameDeviceIndicatesDuplicate() {
        upload(sameFileTwiceInSameBatch: true)
    }
    
    // MARK: Upload v0 file(s) and check for FileIndexClientUI record(s).
    
    func testUploadSingleV0TextFile_withFileIndexClientUI() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "example")
        let uploadResult = uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup, informAllButSelf: true)
        }
        
        guard let sharingGroupUUID = uploadResult?.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard let fileUUID = uploadResult?.fileUUID else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID)
        let lookupResult = fileIndexClientUIRepo.lookup(key: key, modelInit: FileIndexClientUI.init)
        switch lookupResult {
        case .found(let model):
            guard let model = model as? FileIndexClientUI else {
                XCTFail()
                return
            }
            
            XCTAssert(model.fileUUID == fileUUID)
        default:
            XCTFail()
            return
        }
    }
    
    // Test case: Batch with two files; use `testUploadTwoV0TextFiles` above.
    func testUploadTwoV0TextFile_withFileIndexClientUI() {
        let fileUUIDs = [Foundation.UUID().uuidString, Foundation.UUID().uuidString]
        let fileGroup = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let batchUUID = UUID().uuidString
        
        let sharingGroupUUID = uploadTwoV0Files(fileUUIDs: fileUUIDs) { addUser, deviceUUID, fileUUID, uploadIndex, uploadCount in
            return uploadTextFile(uploadIndex: uploadIndex, uploadCount: uploadCount, batchUUID: batchUUID, deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: addUser, fileLabel: UUID().uuidString, fileGroup: fileGroup, informAllButSelf: true)
        }
        
        guard sharingGroupUUID != nil else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.sharingGroup(sharingGroupUUID: sharingGroupUUID!)
        
        guard let fileIndexClientUIes = fileIndexClientUIRepo.lookupAll(key: key, modelInit: FileIndexClientUI.init) else {
            XCTFail()
            return
        }
        
        guard fileIndexClientUIes.count == 2 else {
            XCTFail("fileIndexClientUIes.count: \(fileIndexClientUIes.count)")
            return
        }
    }
    
    // https://github.com/SyncServerII/Neebla/issues/15#issuecomment-855324838
    func testUploadV0InExistingFileGroupByOtherUser_newFileLabel() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "example")
        let sharingGroupUUID = UUID().uuidString
        let owningAccount: TestAccount = .primaryOwningAccount
        
        let uploadResult = uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: owningAccount, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup, sharingGroup: sharingGroupUUID)
        }
        
        guard let deviceUUID1 = uploadResult?.deviceUUID,
            let fileUUID1 = uploadResult?.fileUUID else {
            XCTFail()
            return
        }
        
        let sharingPermission:Permission = .write
        
        // Have that newly created user create a sharing invitation.
        guard let sharingInvitationUUID = createSharingInvitation(testAccount: owningAccount, permission: sharingPermission, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let sharingAccount: TestAccount = .secondaryOwningAccount
        
        // Redeem that sharing invitation with a new user
        guard let _ = redeemSharingInvitation(sharingUser: sharingAccount, sharingInvitationUUID:sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        let uploadResult2 = uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: sharingAccount,  deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, fileGroup: fileGroup, sharingGroup: sharingGroupUUID)
        }

        guard let deviceUUID2 = uploadResult2?.deviceUUID,
            let fileUUID2 = uploadResult2?.fileUUID  else {
            XCTFail()
            return
        }
        
        guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        let key = FileIndexRepository.LookupKey.fileGroupUUID(fileGroupUUID: fileGroup.fileGroupUUID)
        
        guard let fileIndexResult = FileIndexRepository(db).lookupAll(key: key, modelInit: FileIndex.init) else {
            XCTFail()
            return
        }
        
        guard fileIndexResult.count == 2 else {
            XCTFail()
            return
        }
                
        // Read the file from cloud storage using the first user's account and make sure neither fail.
        
        let accountManager = AccountManager()
        accountManager.addAccountType(GoogleCreds.self)
        
        guard let owningUserCreds = FileController.getCreds(forUserId: fileGroupModel.owningUserId, userRepo: userRepo, accountManager: accountManager, accountDelegate: nil) else {
            XCTFail()
            return
        }
        
        guard let cloudStorage = owningUserCreds.cloudStorage(mock: nil) else {
            XCTFail()
            return
        }
        
        let options1 = CloudStorageFileNameOptions(cloudFolderName: owningUserCreds.cloudFolderName, mimeType: fileIndexResult[0].mimeType)

        let cloudFileName1 = Filename.inCloud(deviceUUID: deviceUUID1, fileUUID: fileUUID1, mimeType: fileIndexResult[0].mimeType, fileVersion: fileIndexResult[0].fileVersion)

        let exp1 = expectation(description: "download")
        
        cloudStorage.downloadFile(cloudFileName: cloudFileName1, options:options1) { result in
        
            switch result {
            case .success:
                break
            default:
                XCTFail()
                return
            }
            
            exp1.fulfill()
        }
        
        waitExpectation(timeout: 10, handler: nil)
        
        let exp2 = expectation(description: "download")

        let options2 = CloudStorageFileNameOptions(cloudFolderName: owningUserCreds.cloudFolderName, mimeType: fileIndexResult[1].mimeType)

        let cloudFileName2 = Filename.inCloud(deviceUUID: deviceUUID2, fileUUID: fileUUID2, mimeType: fileIndexResult[1].mimeType, fileVersion: fileIndexResult[1].fileVersion)
        
        cloudStorage.downloadFile(cloudFileName: cloudFileName2, options:options2) { result in
        
            switch result {
            case .success:
                break
            default:
                XCTFail()
                return
            }
            
            exp2.fulfill()
        }
        
        waitExpectation(timeout: 10, handler: nil)
    }
    
    func testUploadV0InExistingFileGroupByOtherUser_existingFileLabel() {
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "example")
        let sharingGroupUUID = UUID().uuidString
        let owningAccount: TestAccount = .primaryOwningAccount
        let fileLabel = UUID().uuidString
        
        let uploadResult = uploadSingleV0File { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: owningAccount, deviceUUID:deviceUUID, fileUUID: fileUUID, fileLabel: fileLabel, fileGroup: fileGroup, sharingGroup: sharingGroupUUID)
        }
        
        let sharingPermission:Permission = .write
        
        // Have that newly created user create a sharing invitation.
        guard let sharingInvitationUUID = createSharingInvitation(testAccount: owningAccount, permission: sharingPermission, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let sharingAccount: TestAccount = .secondaryOwningAccount
        
        // Redeem that sharing invitation with a new user
        guard let _ = redeemSharingInvitation(sharingUser: sharingAccount, sharingInvitationUUID:sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        let uploadResult2 = uploadSingleV0File(expectError: true) { deviceUUID, fileUUID, changeResolverName in
            return uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: sharingAccount,  deviceUUID:deviceUUID, fileUUID: fileUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: fileLabel, errorExpected: true, fileGroup: fileGroup, statusCodeExpected: HTTPStatusCode.conflict, sharingGroup: sharingGroupUUID)
        }
    }
}
