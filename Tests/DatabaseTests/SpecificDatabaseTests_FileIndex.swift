//
//  SpecificDatabaseTests.swift
//  Server
//
//  Created by Christopher Prince on 12/18/16.
//
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Credentials
import CredentialsGoogle
import Foundation
import ServerShared
import ServerAccount

class SpecificDatabaseTests_FileIndex: ServerTestCase {
    var accountManager: AccountManager!
    var userRepo: UserRepository!
    var fileIndexClientUI: FileIndexClientUIRepository!

    var accountDelegate: AccountDelegate!
    
    override func setUp() {
        super.setUp()
        userRepo = UserRepository(db)
        fileIndexClientUI = FileIndexClientUIRepository(db)

        accountManager = AccountManager()
        accountDelegate = UserRepository.AccountDelegateHandler(userRepository: userRepo, accountManager: accountManager)
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testAddFileIndex() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        
        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        let sharingGroupUUID = UUID().uuidString
        guard let _ = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true) else {
            XCTFail()
            return
        }
    }
    
    func testAddFileIndexWithChangeResolver() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        
        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        let sharingGroupUUID = UUID().uuidString
        guard let _ = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true, changeResolverName: "Foobar") else {
            XCTFail()
            return
        }
    }

    func testUpdateFileIndexWithNoChanges() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        
        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        let sharingGroupUUID = UUID().uuidString
        guard let fileIndex = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true) else {
            XCTFail()
            return
        }
        
        XCTAssert(FileIndexRepository(db).update(fileIndex: fileIndex))
    }
    
    func testUpdateFileIndexWithAChange() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        // 6/12/19; Just added the JSON validation parameter. I have *no* idea how this was working before this. It ought to have required the server to be running for it to work.
        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        guard let fileIndex = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true) else {
            XCTFail()
            return
        }
        
        fileIndex.fileVersion = 2
        XCTAssert(FileIndexRepository(db).update(fileIndex: fileIndex))
    }
    
    func testUpdateFileIndexFailsWithoutFileIndexId() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        guard let fileIndex = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true) else {
            XCTFail()
            return
        }
        fileIndex.fileIndexId = nil
        XCTAssert(!FileIndexRepository(db).update(fileIndex: fileIndex))
    }
    
    func testUpdateUploadSucceedsWithNilAppMetaData() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        guard let fileIndex = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true) else {
            XCTFail()
            return
        }
        
        fileIndex.appMetaData = nil
        XCTAssert(FileIndexRepository(db).update(fileIndex: fileIndex))
    }
    
    func testLookupFromFileIndex() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString
        let changeResolverName = "Foobar"
        
        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        guard let fileIndex1 = doAddFileIndex(userId:userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: true, changeResolverName: changeResolverName) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).lookup(key: .fileIndexId(fileIndex1.fileIndexId), modelInit: FileIndex.init)
        switch result {
        case .error(let error):
            XCTFail("\(error)")
            
        case .found(let object):
            let fileIndex2 = object as! FileIndex
            XCTAssert(fileIndex1.lastUploadedCheckSum != nil && fileIndex1.lastUploadedCheckSum == fileIndex2.lastUploadedCheckSum)
            XCTAssert(fileIndex1.deleted != nil && fileIndex1.deleted == fileIndex2.deleted)
            XCTAssert(fileIndex1.fileUUID != nil && fileIndex1.fileUUID == fileIndex2.fileUUID)
            XCTAssert(fileIndex1.deviceUUID != nil && fileIndex1.deviceUUID == fileIndex2.deviceUUID)

            XCTAssert(fileIndex1.fileVersion != nil && fileIndex1.fileVersion == fileIndex2.fileVersion)
            XCTAssert(fileIndex1.mimeType != nil && fileIndex1.mimeType == fileIndex2.mimeType)
            XCTAssert(fileIndex1.userId != nil && fileIndex1.userId == fileIndex2.userId)
            XCTAssert(fileIndex1.appMetaData != nil && fileIndex1.appMetaData == fileIndex2.appMetaData)
            XCTAssert(fileIndex1.sharingGroupUUID != nil && fileIndex1.sharingGroupUUID == fileIndex2.sharingGroupUUID)
            
            XCTAssert(fileIndex1.objectType != nil && fileIndex1.objectType == fileIndex2.objectType)
            XCTAssert(fileIndex1.fileGroupUUID != nil && fileIndex1.fileGroupUUID == fileIndex2.fileGroupUUID)

            XCTAssert(fileIndex2.changeResolverName == changeResolverName)

        case .noObjectFound:
            XCTFail("No Upload Found")
        }
    }

    func testFileIndexWithNoFiles() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail("Bad credentialsId!")
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .admin, owningUserId: nil) else {
            XCTFail()
            return
        }
        
        let fileIndexResult = FileIndexRepository(db).fileIndex(forSharingGroupUUID: sharingGroupUUID)
        switch fileIndexResult {
        case .fileIndex(let fileIndex):
            XCTAssert(fileIndex.count == 0)
        case .error(_):
            XCTFail()
        }
    }

    func testFileIndexWithOneFile() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndexInserted = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        let fileIndexResult = FileIndexRepository(db).fileIndex(forSharingGroupUUID: sharingGroupUUID)
        switch fileIndexResult {
        case .fileIndex(let fileIndex):
            guard fileIndex.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(fileIndexInserted.fileUUID == fileIndex[0].fileUUID)
            XCTAssert(fileIndexInserted.fileVersion == fileIndex[0].fileVersion)
            XCTAssert(fileIndexInserted.mimeType == fileIndex[0].mimeType)
            XCTAssert(fileIndexInserted.deleted == fileIndex[0].deleted)
            XCTAssert(fileIndex[0].cloudStorageType == AccountScheme.google.cloudStorageType)
            
        case .error(_):
            XCTFail()
        }
    }
    
    func testGetGroupSummary_withNoGroupSummary() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        // There should be no group summary here because there are no rows in `FileIndexClientUIRepository` for this sharingGroup.
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            XCTAssert(summary == nil)
        }
    }
    
    func addFileIndexClientUIRecord(userId: UserId, fileVersion:FileVersionInt, fileUUID: String, sharingGroupUUID: String) -> FileIndexClientUI? {
        let model = FileIndexClientUI()
        
        model.fileUUID = fileUUID
        model.sharingGroupUUID = sharingGroupUUID
        model.fileVersion = fileVersion
        model.informAllButUserId = userId
        model.expiry = Date()
        
        guard let result = fileIndexClientUI.add(model: model) else {
            XCTFail()
            return nil
        }
        
        model.fileIndexClientUIId = result
        return model
    }
    
    func testGetGroupSummary_withOtherThanRequestingUserId() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId+1, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard let inform = summary[0].inform, inform.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .self)
        }
    }
    
    func testGetGroupSummary_withRequestingUserId() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard let inform = summary[0].inform, inform.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .others)
        }
    }
    
    // Also with multiple FileIndex rows.
    func testGetGroupSummary_withRequestingUserId2() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard let inform = summary[0].inform, inform.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .others)
        }
    }
    
    // Also with multiple FileIndex rows, with the same fileGroupUUID
    func testGetGroupSummary_withRequestingUserId3() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false, fileGroupUUID: fileGroupUUID, fileLabel: "file2") else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard let inform = summary[0].inform, inform.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .others)
        }
    }
    
    // Also with multiple FileIndex rows, with the same fileGroupUUID,
    // and multiple versions.
    func testGetGroupSummary_withRequestingUserId4() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false, fileGroupUUID: fileGroupUUID, fileLabel: "file2") else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 1, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard var inform = summary[0].inform, inform.count == 2 else {
                XCTFail()
                return
            }
            
            inform.sort { i1, i2 in
                i1.fileVersion < i2.fileVersion
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .others)
            
            XCTAssert(inform[1].fileUUID == fileUUID)
            XCTAssert(inform[1].fileVersion == 1)
            XCTAssert(inform[1].inform == .others)
        }
    }
    
    // One record with requesting userId another with a different userId
    func testGetGroupSummary_withRequestingUserId4_oneOther() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false, fileGroupUUID: fileGroupUUID, fileLabel: "file2") else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId+1, fileVersion: 1, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(!summary[0].deleted)
            XCTAssert(summary[0].fileGroupUUID == fileGroupUUID)
            
            guard var inform = summary[0].inform, inform.count == 2 else {
                XCTFail()
                return
            }
            
            inform.sort { i1, i2 in
                i1.fileVersion < i2.fileVersion
            }
            
            XCTAssert(inform[0].fileUUID == fileUUID)
            XCTAssert(inform[0].fileVersion == 0)
            XCTAssert(inform[0].inform == .others)
            
            XCTAssert(inform[1].fileUUID == fileUUID)
            XCTAssert(inform[1].fileVersion == 1)
            XCTAssert(inform[1].inform == .self)
        }
    }
    
    // Two files each with versions that the requesting user needs to be informed about
    func testGetGroupSummary_withRequestingUserId5() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        guard let fileIndex1 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }

        guard let fileUUID = fileIndex1.fileUUID,
            let fileGroupUUID = fileIndex1.fileGroupUUID else {
            XCTFail()
            return
        }

        guard let fileIndex2 = doAddFileIndex(userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let fileUUID2 = fileIndex2.fileUUID,
            let fileGroupUUID2 = fileIndex2.fileGroupUUID else {
            XCTFail()
            return
        }

        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 0, fileUUID: fileUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = addFileIndexClientUIRecord(userId: userId, fileVersion: 1, fileUUID: fileUUID2, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let result = FileIndexRepository(db).getGroupSummary(forSharingGroupUUID: sharingGroupUUID, requestingUserId: userId)
        switch result {
        case .error:
            XCTFail()
            return
        case .summary(let summary):
            guard let summary = summary, summary.count == 2 else {
                XCTFail()
                return
            }
            
            let filter1 = summary.filter { $0.fileGroupUUID == fileGroupUUID }
            guard filter1.count == 1,
                let inform1 = filter1[0].inform,
                inform1.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform1[0].fileVersion == 0, "filter1[0].fileVersion: \(inform1[0].fileVersion)")
            XCTAssert(inform1[0].fileUUID == fileUUID)
            XCTAssert(inform1[0].inform == .others)

            let filter2 = summary.filter { $0.fileGroupUUID == fileGroupUUID2 }
            guard filter2.count == 1,
                let inform2 = filter2[0].inform,
                inform2.count == 1 else {
                XCTFail()
                return
            }
            
            XCTAssert(inform2[0].fileVersion == 1)
            XCTAssert(inform2[0].fileUUID == fileUUID2)
            XCTAssert(inform2[0].inform == .others)
        }
    }
    
    func testGetMostRecentDate_withNoData() {
        let sharingGroupUUID = UUID()
        let result = FileIndexRepository(db).getMostRecentDate(forSharingGroupUUID: sharingGroupUUID.uuidString)
        XCTAssert(result == nil)
    }
    
    func testGetMostRecentDate_withOneFileIndexRow_onlyCreationDate() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        let date = Date()
        guard let _ = doAddFileIndex(creationDate: date, updateDate: nil, userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let result = FileIndexRepository(db).getMostRecentDate(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(DateExtras.equals(result, date))
    }
    
    func testGetMostRecentDate_withOneFileIndexRow_bothDates() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        let creationDate = Date()
        
        let calendar = Calendar.current
        guard let updateDate = calendar.date(byAdding: .day, value: 1, to: creationDate) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(creationDate: creationDate, updateDate: updateDate, userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let result = FileIndexRepository(db).getMostRecentDate(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(DateExtras.equals(result, updateDate))
    }
    
    func testGetMostRecentDate_withOneFileIndexRow_bothDates_otherOrder() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }

        let updateDate = Date()
        
        let calendar = Calendar.current
        guard let creationDate = calendar.date(byAdding: .day, value: 1, to: updateDate) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(creationDate: creationDate, updateDate: updateDate, userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let result = FileIndexRepository(db).getMostRecentDate(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(DateExtras.equals(result, creationDate))
    }

    func testGetMostRecentDate_withTwoIndexRows() {
        let user1 = User()
        user1.username = "Chris"
        user1.accountType = AccountScheme.google.accountName
        user1.creds = "{\"accessToken\": \"SomeAccessTokenValue1\"}"
        user1.credsId = "100"
        let sharingGroupUUID = UUID().uuidString

        guard let userId = userRepo.add(user: user1, accountManager: accountManager, accountDelegate: accountDelegate, validateJSON: false) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupRepository(db).add(sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard case .success = SharingGroupUserRepository(db).add(sharingGroupUUID: sharingGroupUUID, userId: userId, permission: .read, owningUserId: nil) else {
            XCTFail()
            return
        }
        
        let calendar = Calendar.current
        guard let creationDate1 = calendar.date(byAdding: .day, value: 1, to: Date()) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(creationDate: creationDate1, updateDate: nil, userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let creationDate2 = calendar.date(byAdding: .day, value: 2, to: Date()) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddFileIndex(creationDate: creationDate2, updateDate: nil, userId: userId, sharingGroupUUID: sharingGroupUUID, createSharingGroup: false) else {
            XCTFail()
            return
        }
        
        guard let result = FileIndexRepository(db).getMostRecentDate(forSharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(DateExtras.equals(result, creationDate2))
    }
}

