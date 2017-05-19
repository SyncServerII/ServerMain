//
//  DatabaseModelTests.swift
//  Server
//
//  Created by Christopher Prince on 5/2/17.
//
//

import XCTest
@testable import Server
import LoggerAPI
import HeliumLogger
import PerfectLib
import Foundation

class DatabaseModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testDeviceUUID() {
        let deviceUUID = DeviceUUID(userId: 0, deviceUUID: PerfectLib.UUID().string)
        let newDeviceUUID = PerfectLib.UUID().string
        let newUserId = Int64(10)
        
        deviceUUID[DeviceUUID.deviceUUIDKey] = newDeviceUUID
        deviceUUID[DeviceUUID.userIdKey] = newUserId
        
        XCTAssert(deviceUUID.deviceUUID == newDeviceUUID)
        XCTAssert(deviceUUID.userId == newUserId)

        deviceUUID[DeviceUUID.deviceUUIDKey] = nil
        deviceUUID[DeviceUUID.userIdKey] = nil
        
        XCTAssert(deviceUUID.deviceUUID == nil)
        XCTAssert(deviceUUID.userId == nil)
    }
    
    func testLock() {
        let lock = Lock(userId: 0, deviceUUID: PerfectLib.UUID().string)
        lock[Lock.deviceUUIDKey] = PerfectLib.UUID().string
        
        let newDate = Date()
        let newUserId = Int64(5)
        let newDeviceUUID = PerfectLib.UUID().string
        
        lock[Lock.expiryKey] = newDate
        lock[Lock.userIdKey] = newUserId
        lock[Lock.deviceUUIDKey] = newDeviceUUID
        
        XCTAssert(lock.deviceUUID == newDeviceUUID)
        XCTAssert(lock.userId == newUserId)
        XCTAssert(lock.expiry.compare(newDate) == .orderedSame)
        
        lock[Lock.expiryKey] = nil
        lock[Lock.userIdKey] = nil
        lock[Lock.deviceUUIDKey] = nil
        
        XCTAssert(lock.deviceUUID == nil)
        XCTAssert(lock.userId == nil)
        XCTAssert(lock.expiry == nil)
    }
    
    func testMasterVersion() {
        let masterVersion = MasterVersion()
        
        let newUserId = Int64(805)
        let newMasterVersion = MasterVersionInt(100)
        
        masterVersion[MasterVersion.userIdKey] = newUserId
        masterVersion[MasterVersion.masterVersionKey] = newMasterVersion
        
        XCTAssert(masterVersion.userId == newUserId)
        XCTAssert(masterVersion.masterVersion == newMasterVersion)

        masterVersion[MasterVersion.userIdKey] = nil
        masterVersion[MasterVersion.masterVersionKey] = nil
        
        XCTAssert(masterVersion.userId == nil)
        XCTAssert(masterVersion.masterVersion == nil)
    }
    
    func testSharingInvitation() {
        let sharingInvitation = SharingInvitation()
        
        let newSharingInvitationUUID = PerfectLib.UUID().string
        let newExpiry = Date()
        let newOwningUserId = UserId(342)
        let newSharingPermission:SharingPermission = .read
        
        sharingInvitation[SharingInvitation.sharingInvitationUUIDKey] = newSharingInvitationUUID
        sharingInvitation[SharingInvitation.expiryKey] = newExpiry
        sharingInvitation[SharingInvitation.owningUserIdKey] = newOwningUserId
        sharingInvitation[SharingInvitation.sharingPermissionKey] = newSharingPermission
        
        XCTAssert(sharingInvitation.sharingInvitationUUID == newSharingInvitationUUID)
        XCTAssert(sharingInvitation.expiry == newExpiry)
        XCTAssert(sharingInvitation.owningUserId == newOwningUserId)
        XCTAssert(sharingInvitation.sharingPermission == newSharingPermission)

        sharingInvitation[SharingInvitation.sharingInvitationUUIDKey] = nil
        sharingInvitation[SharingInvitation.expiryKey] = nil
        sharingInvitation[SharingInvitation.owningUserIdKey] = nil
        sharingInvitation[SharingInvitation.sharingPermissionKey] = nil
        
        XCTAssert(sharingInvitation.sharingInvitationUUID == nil)
        XCTAssert(sharingInvitation.expiry == nil)
        XCTAssert(sharingInvitation.owningUserId == nil)
        XCTAssert(sharingInvitation.sharingPermission == nil)
    }
    
    func testUser() {
        let user = User()
        
        let newUserId = UserId(43287)
        let newUsername = "foobar"
        let newUserType:UserType = .sharing
        let newOwningUserId = UserId(321)
        let newSharingPermission:SharingPermission = .write
        let newAccountType: AccountType = .Google
        let newCredsId = "d392y2t3"
        let newCreds = "fd9eu23y4"
        
        user[User.userIdKey] = newUserId
        user[User.usernameKey] = newUsername
        user[User.userTypeKey] = newUserType
        user[User.owningUserIdKey] = newOwningUserId
        user[User.sharingPermissionKey] = newSharingPermission
        user[User.accountTypeKey] = newAccountType
        user[User.credsIdKey] = newCredsId
        user[User.credsKey] = newCreds
        
        XCTAssert(user.userId == newUserId)
        XCTAssert(user.username == newUsername)
        XCTAssert(user.userType == newUserType)
        XCTAssert(user.owningUserId == newOwningUserId)
        XCTAssert(user.sharingPermission == newSharingPermission)
        
        // Swift Compiler issues.
        // XCTAssert(user.accountType == newAccountType)
        
        if user.accountType != newAccountType {
            XCTFail()
        }
        
        XCTAssert(user.credsId == newCredsId)
        XCTAssert(user.creds == newCreds)
        
        user[User.userIdKey] = nil
        user[User.usernameKey] = nil
        user[User.userTypeKey] = nil
        user[User.owningUserIdKey] = nil
        user[User.sharingPermissionKey] = nil
        user[User.accountTypeKey] = nil
        user[User.credsIdKey] = nil
        user[User.credsKey] = nil
        
        XCTAssert(user.userId == nil)
        XCTAssert(user.username == nil)
        XCTAssert(user.userType == nil)
        XCTAssert(user.owningUserId == nil)
        XCTAssert(user.sharingPermission == nil)
        XCTAssert(user.accountType == nil)
        XCTAssert(user.credsId == nil)
        XCTAssert(user.creds == nil)
    }
    
    func testFileIndex() {
        let fileIndex = FileIndex()

        let newFileIndexId = FileIndexId(334)
        let newFileUUID = PerfectLib.UUID().string
        let newDeviceUUID = PerfectLib.UUID().string
        let newUserId = UserId(3226453)
        let newMimeType = "text/plain"
        let newCloudFolderName = "someFolderName"
        let newAppMetaData = "whatever"
        let newDeleted = false
        let newFileVersion = FileVersionInt(100)
        let newFileSizeBytes = Int64(322)
        
        fileIndex[FileIndex.fileIndexIdKey] = newFileIndexId
        fileIndex[FileIndex.fileUUIDKey] = newFileUUID
        fileIndex[FileIndex.deviceUUIDKey] = newDeviceUUID
        fileIndex[FileIndex.userIdKey] = newUserId
        fileIndex[FileIndex.mimeTypeKey] = newMimeType
        fileIndex[FileIndex.cloudFolderNameKey] = newCloudFolderName
        fileIndex[FileIndex.appMetaDataKey] = newAppMetaData
        fileIndex[FileIndex.deletedKey] = newDeleted
        fileIndex[FileIndex.fileVersionKey] = newFileVersion
        fileIndex[FileIndex.fileSizeBytesKey] = newFileSizeBytes
        
        XCTAssert(fileIndex.fileIndexId == newFileIndexId)
        XCTAssert(fileIndex.fileUUID == newFileUUID)
        XCTAssert(fileIndex.deviceUUID == newDeviceUUID)
        XCTAssert(fileIndex.userId == newUserId)
        XCTAssert(fileIndex.mimeType == newMimeType)
        XCTAssert(fileIndex.cloudFolderName == newCloudFolderName)
        XCTAssert(fileIndex.appMetaData == newAppMetaData)
        XCTAssert(fileIndex.deleted == newDeleted)
        XCTAssert(fileIndex.fileVersion == newFileVersion)
        XCTAssert(fileIndex.fileSizeBytes == newFileSizeBytes)
        
        fileIndex[FileIndex.fileIndexIdKey] = nil
        fileIndex[FileIndex.fileUUIDKey] = nil
        fileIndex[FileIndex.deviceUUIDKey] = nil
        fileIndex[FileIndex.userIdKey] = nil
        fileIndex[FileIndex.mimeTypeKey] = nil
        fileIndex[FileIndex.cloudFolderNameKey] = nil
        fileIndex[FileIndex.appMetaDataKey] = nil
        fileIndex[FileIndex.deletedKey] = nil
        fileIndex[FileIndex.fileVersionKey] = nil
        fileIndex[FileIndex.fileSizeBytesKey] = nil
        
        XCTAssert(fileIndex.fileIndexId == nil)
        XCTAssert(fileIndex.fileUUID == nil)
        XCTAssert(fileIndex.deviceUUID == nil)
        XCTAssert(fileIndex.userId == nil)
        XCTAssert(fileIndex.mimeType == nil)
        XCTAssert(fileIndex.cloudFolderName == nil)
        XCTAssert(fileIndex.appMetaData == nil)
        XCTAssert(fileIndex.deleted == nil)
        XCTAssert(fileIndex.fileVersion == nil)
        XCTAssert(fileIndex.fileSizeBytes == nil)
    }
    
    func testUpload() {
        let upload = Upload()
        
        let uploadId = Int64(3300)
        let fileUUID = PerfectLib.UUID().string
        let userId = UserId(43)
        let fileVersion = FileVersionInt(322)
        let deviceUUID = PerfectLib.UUID().string
        let state:UploadState = .toDeleteFromFileIndex
        let appMetaData = "arba"
        let fileSizeBytes = Int64(4211)
        let mimeType = "text/plain"
        let cloudFolderName = "folder"
        
        upload[Upload.uploadIdKey] = uploadId
        upload[Upload.fileUUIDKey] = fileUUID
        upload[Upload.userIdKey] = userId
        upload[Upload.fileVersionKey] = fileVersion
        upload[Upload.deviceUUIDKey] = deviceUUID
        upload[Upload.stateKey] = state
        upload[Upload.appMetaDataKey] = appMetaData
        upload[Upload.fileSizeBytesKey] = fileSizeBytes
        upload[Upload.mimeTypeKey] = mimeType
        upload[Upload.cloudFolderNameKey] = cloudFolderName
        
        XCTAssert(upload.uploadId == uploadId)
        XCTAssert(upload.fileUUID == fileUUID)
        XCTAssert(upload.userId == userId)
        XCTAssert(upload.fileVersion == fileVersion)
        XCTAssert(upload.deviceUUID == deviceUUID)
        XCTAssert(upload.state == state)
        XCTAssert(upload.appMetaData == appMetaData)
        XCTAssert(upload.fileSizeBytes == fileSizeBytes)
        XCTAssert(upload.mimeType == mimeType)
        XCTAssert(upload.cloudFolderName == cloudFolderName)

        upload[Upload.uploadIdKey] = nil
        upload[Upload.fileUUIDKey] = nil
        upload[Upload.userIdKey] = nil
        upload[Upload.fileVersionKey] = nil
        upload[Upload.deviceUUIDKey] = nil
        upload[Upload.stateKey] = nil
        upload[Upload.appMetaDataKey] = nil
        upload[Upload.fileSizeBytesKey] = nil
        upload[Upload.mimeTypeKey] = nil
        upload[Upload.cloudFolderNameKey] = nil
        
        XCTAssert(upload.uploadId == nil)
        XCTAssert(upload.fileUUID == nil)
        XCTAssert(upload.userId == nil)
        XCTAssert(upload.fileVersion == nil)
        XCTAssert(upload.deviceUUID == nil)
        XCTAssert(upload.state == nil)
        XCTAssert(upload.appMetaData == nil)
        XCTAssert(upload.fileSizeBytes == nil)
        XCTAssert(upload.mimeType == nil)
        XCTAssert(upload.cloudFolderName == nil)
    }
}

extension DatabaseModelTests {
    static var allTests : [(String, (DatabaseModelTests) -> () throws -> Void)] {
        return [
            ("testDeviceUUID", testDeviceUUID),
            ("testLock", testLock),
            ("testMasterVersion", testMasterVersion),
            ("testSharingInvitation", testSharingInvitation),
            ("testUser", testUser),
            ("testFileIndex", testFileIndex),
            ("testUpload", testUpload),
        ]
    }
}