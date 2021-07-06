//
//  FileController_FinishUploadsTests.swift
//  FileControllerTests
//
//  Created by Christopher G Prince on 7/23/20.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared
import Kitura
import Credentials
import ChangeResolvers

struct Params: FinishUploadsParameters {
    var repos: Repositories!
    let currentSignedInUser: User?
}

struct UploaderFake: UploaderProtocol {
    func run() throws {
        delegate?.run(completed: self, error: nil)
    }
    
    weak var delegate: UploaderDelegate?
}

class FileController_FinishUploadsTests: ServerTestCase, UploaderCommon {
    var accountManager: AccountManager!
    //var uploader: UploaderProtocol!
    var runCompleted:((Swift.Error?)->())?
    
    override func setUp() {
        super.setUp()
        
        accountManager = AccountManager()
        _ = accountManager.setupAccounts(credentials: Credentials())
        
        let resolverManager = ChangeResolverManager()
        do {
            try resolverManager.setupResolvers()
        } catch let error {
            XCTFail("\(error)")
            return
        }
        
        runCompleted = nil
    }
    
    func testUploadWithNilFileGroupFails() throws {
        let fileUUID1 = Foundation.UUID().uuidString
        let deviceUUID = Foundation.UUID().uuidString
        let changeResolverName = CommentFile.changeResolverName
        
        let result1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, errorExpected: true, stringFile: .commentFile, changeResolverName: changeResolverName)
        XCTAssert(result1 == nil)
    }
    
    enum FinishUploadsWithFileGroupsTest: Equatable {
        case oneFileGroup
        case twoFileGroups
    }
    
    func runFinishUploadsWithFileGroups(test: FinishUploadsWithFileGroupsTest) throws {
        let fileUUID1 = Foundation.UUID().uuidString
        let fileUUID2 = Foundation.UUID().uuidString
        
        let fileGroup1 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        let fileGroup2 = FileGroup(fileGroupUUID: Foundation.UUID().uuidString, objectType: "Foo")
        
        let deviceUUID = Foundation.UUID().uuidString
        let repos = Repositories(db: db)
        let changeResolverName = CommentFile.changeResolverName
        let fakeUploader = UploaderFake(delegate: self)
        
        // upload v0 files
        
        guard let result1 = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID1, fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: fileGroup1, changeResolverName: changeResolverName),
            let sharingGroupUUID = result1.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        let secondFileGroup: FileGroup
        switch test {
        case .oneFileGroup:
            secondFileGroup = fileGroup1
        case .twoFileGroups:
            secondFileGroup = fileGroup2
        }
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: Foundation.UUID().uuidString, deviceUUID:deviceUUID, fileUUID: fileUUID2, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, stringFile: .commentFile, fileGroup: secondFileGroup, changeResolverName: changeResolverName) else {
            XCTFail()
            return
        }
        
        guard let userId = result1.uploadingUserId else {
            XCTFail()
            return
        }
        
        let key = UserRepository.LookupKey.userId(userId)
        guard case .found(let model) = repos.user.lookup(key: key, modelInit: User.init),
            let user = model as? User else {
            XCTFail()
            return
        }
        
        let batchUUID2 = UUID().uuidString
        
        let params = Params(repos: repos, currentSignedInUser: user)
        guard let finishUploads = FinishUploadFiles(batchUUID: batchUUID2, fileOwnerUserId: userId, sharingGroupUUID: sharingGroupUUID, objectType: fileGroup1.objectType, deviceUUID: deviceUUID, uploader:fakeUploader, params: params) else {
            XCTFail()
            return
        }
        
        let comment1 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)
        let comment2 = ExampleComment(messageString: "Example", id: Foundation.UUID().uuidString)

        // We don't add DeferredUpload's here-- these get added by FinishUploads
        
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID1, fileGroup: fileGroup1, sharingGroupUUID: sharingGroupUUID, userId: userId, updateContents: comment1.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID2) else {
            XCTFail()
            return
        }
        
        guard let _ = createUploadForTextFile(deviceUUID: deviceUUID, fileUUID: fileUUID2, fileGroup: secondFileGroup, sharingGroupUUID: sharingGroupUUID, userId: userId, updateContents: comment2.updateContents, uploadCount: 1, uploadIndex: 1, batchUUID: batchUUID2) else {
            XCTFail()
            return
        }
        
        switch test {
        case .oneFileGroup:
            guard case .deferred = try? finishUploads.finish() else {
                XCTFail()
                return
            }
        case .twoFileGroups:
            guard case .error = try? finishUploads.finish() else {
                XCTFail()
                return
            }
        }
    }
    
    func testFinishUploadsWithTwoFileDifferentGroupsFails() throws {
        try runFinishUploadsWithFileGroups(test: .twoFileGroups)
    }
    
    func testFinishUploadsWithOneFileGroupWorks() throws {
        guard let uploadCount = UploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        guard let deferredCount = DeferredUploadRepository(db).count() else {
            XCTFail()
            return
        }
        
        try runFinishUploadsWithFileGroups(test: .oneFileGroup)
        
        XCTAssert(UploadRepository(db).count() == uploadCount + 2)
        XCTAssert(DeferredUploadRepository(db).count() == deferredCount + 1)
    }
}

extension FileController_FinishUploadsTests: UploaderDelegate {
    func run(completed: UploaderProtocol, error: Error?) {
    }
}
