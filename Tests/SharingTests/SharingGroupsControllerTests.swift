//
//  SharingGroupsControllerTests.swift
//  ServerTests
//
//  Created by Christopher G Prince on 7/15/18.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import Foundation
import ServerShared

class SharingGroupsControllerTests: ServerTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCreateSharingGroupWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString

        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
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
        
        guard let (_, sharingGroups) = getIndex() else {
            XCTFail()
            return
        }
        
        let filtered = sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID2}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].sharingGroupName == sharingGroup.sharingGroupName)
    }
    
    func testThatNonOwningUserCannotCreateASharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString

        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        let sharingInvitationUUID:String! = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let testAccount:TestAccount = .nonOwningSharingAccount
        guard let _ = redeemSharingInvitation(sharingUser: testAccount, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        let deviceUUID2 = Foundation.UUID().uuidString
        let sharingGroupUUID2 = Foundation.UUID().uuidString

        createSharingGroup(testAccount: testAccount, sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID2, errorExpected: true)
    }
    
    func testNewlyCreatedSharingGroupHasNoFiles() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString

        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingGroup = ServerShared.SharingGroup()
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        let sharingGroupUUID2 = Foundation.UUID().uuidString

        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }
        
        guard let (files, sharingGroups) = getIndex(sharingGroupUUID: sharingGroupUUID2) else {
            XCTFail()
            return
        }
        
        guard files != nil && files?.count == 0 else {
            XCTFail()
            return
        }
        
        guard sharingGroups.count == 2 else {
            XCTFail()
            return
        }
        
        sharingGroups.forEach { sharingGroup in
            guard let deleted = sharingGroup.deleted else {
                XCTFail()
                return
            }
            XCTAssert(!deleted)
            XCTAssert(sharingGroup.permission == .admin)
        }
        
        let filtered = sharingGroups.filter {$0.sharingGroupUUID == sharingGroupUUID2}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].sharingGroupName == sharingGroup.sharingGroupName)
        
        guard let users = filtered[0].sharingGroupUsers, users.count == 1, users[0].name != nil, users[0].name.count > 0 else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroupWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString

        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingGroup = ServerShared.SharingGroup()
        sharingGroup.sharingGroupUUID = sharingGroupUUID
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        guard updateSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }
    }
    
    // MARK: Remove sharing groups
    
    // `_only` is just for filtering: To run this test by itself.
    func testRemoveSharingGroupWorks_only() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let key1 = SharingGroupRepository.LookupKey.sharingGroupUUID(sharingGroupUUID)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        guard sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        guard let count = SharingGroupUserRepository(db).count(),
            count == 1 else {
            XCTFail()
            return
        }
        
        guard let userId = addUserResponse.userId else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2 , modelInit: SharingGroupUser.init)
        guard case .found(let model2) = result2,
            let sharingGroupUser = model2 as? Server.SharingGroupUser else {
            XCTFail()
            return
        }
        
        guard sharingGroupUser.deleted else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWorks_filesMarkedAsDeleted() {
        let deviceUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        // Can't do a file index because no one is left in the sharing group. So, just look up in the db directly.
        
        guard let fileGroupUUID = uploadResult.request.fileGroupUUID else {
            XCTFail()
            return
        }
        
        guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileGroupModel.deleted)
    }
    
    func indexReportsSharingGroupDeleted(remove: Bool) {
        let deviceUUID = Foundation.UUID().uuidString

        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        
        guard let uploadResult = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        if remove {
            guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
                XCTFail()
                return
            }
        }
        
        guard let (_, sharingGroups) = getIndex(testAccount:.primaryOwningAccount, deviceUUID:deviceUUID),
            sharingGroups.count == 1 else {
            XCTFail()
            return
        }
        
        let filtered = sharingGroups.filter { $0.sharingGroupUUID == sharingGroupUUID}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }

        XCTAssert(filtered[0].deleted == remove)
    }
    
    func testRemoveSharingGroupWorks_indexReportsSharingGroupDeleted() {
        indexReportsSharingGroupDeleted(remove: true)
    }

    func testDoNotRemoveSharingGroupWorks_indexReportsSharingGroupNotDeleted() {
        indexReportsSharingGroupDeleted(remove: false)
    }
    
    func testRemoveSharingGroupWorks_multipleUsersRemovedFromSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        let sharingInvitationUUID:String! = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let count = SharingGroupUserRepository(db).count(),
            count == 2 else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWorks_cannotThenInviteSomeoneToThatGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID, errorExpected: true)
        XCTAssert(result == nil)
    }
    
    func testRemoveSharingGroupWorks_cannotThenUploadFileToThatSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")
        
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, errorExpected:true, fileGroup: fileGroup)
    }
    
    func testRemoveSharingGroupWorks_cannotThenDoDoneUploads() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
    }
    
    func testRemoveSharingGroupWorks_cannotDeleteFile() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")

        guard let uploadResult = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup), let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let uploadDeletionRequest = UploadDeletionRequest()
        uploadDeletionRequest.fileGroupUUID = uploadResult.request.fileGroupUUID
        uploadDeletionRequest.sharingGroupUUID = sharingGroupUUID
        
        let result = uploadDeletion(uploadDeletionRequest: uploadDeletionRequest, deviceUUID: deviceUUID, addUser: false, expectError: true, expectingUploaderToRun: false)
        XCTAssert(result == nil)
    }
    
    func testRemoveSharingGroupWorks_downloadAppMetaDataFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let appMetaData = "Foo"
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")

        guard let uploadResult = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, appMetaData: appMetaData, fileGroup: fileGroup), let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        downloadAppMetaData(deviceUUID: deviceUUID, fileUUID: uploadResult.request.fileUUID, sharingGroupUUID: sharingGroupUUID, expectedError: true)
    }
    
    func testRemoveSharingGroupWorks_downloadFileFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")

        guard let uploadResult = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup),
            let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
    }
    
    func testUpdateSharingGroupForDeletedSharingGroupFails() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeSharingGroup(deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
                
        let sharingGroup = ServerShared.SharingGroup()
        sharingGroup.sharingGroupUUID = sharingGroupUUID
        sharingGroup.sharingGroupName = "Louisiana Guys"
        
        let result = updateSharingGroup(deviceUUID:deviceUUID, sharingGroup: sharingGroup, expectFailure: true)
        XCTAssert(result == false)
    }
    
    // MARK: Remove user from sharing group
    
    func testRemoveUserFromSharingGroup_lastUserInSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let key1 = SharingGroupRepository.LookupKey.sharingGroupUUID(sharingGroupUUID)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        guard sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        guard let userId = addUserResponse.userId else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2, modelInit: SharingGroupUser.init)
        guard case .found(let model2) = result2,
            let sharingGroupUser = model2 as? Server.SharingGroupUser else {
            XCTFail()
            return
        }
        
        XCTAssert(sharingGroupUser.deleted)
    }
    
    func testRemoveUserFromSharingGroup_notLastUserInSharingGroup() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let addUserResponse = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        let sharingInvitationUUID:String! = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let key1 = SharingGroupRepository.LookupKey.sharingGroupUUID(sharingGroupUUID)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        // Still one user in sharing group-- should not be deleted.
        guard !sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        guard let userId = addUserResponse.userId else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2 , modelInit: SharingGroupUser.init)
        guard case .found(let model2) = result2,
            let sharingGroupUser = model2 as? Server.SharingGroupUser else {
            XCTFail()
            return
        }
        
        XCTAssert(sharingGroupUser.deleted)
    }
    
    // When user has files in the sharing group-- those should be marked as deleted.
    func testRemoveUserFromSharingGroup_userHasFiles() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")

        guard let uploadResult = uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileLabel: UUID().uuidString, fileGroup: fileGroup), let sharingGroupUUID = uploadResult.sharingGroupUUID else {
            XCTFail()
            return
        }

        // Need a second user as a member of the sharing group so we can do a file index on the sharing group after the first user is removed.
        let sharingInvitationUUID:String! = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let (files, _) = getIndex(testAccount: sharingUser, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let filtered = files!.filter {$0.fileUUID == uploadResult.request.fileUUID}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].deleted == true)
    }
    
    // When owning user has sharing users in sharing group: Those should no longer be able to upload to the sharing group.
    func testRemoveUserFromSharingGroup_owningUserHasSharingUsers() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let owningUser:TestAccount = .primaryOwningAccount
        let fileGroup = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foobar")
        
        guard let _ = self.addNewUser(testAccount: owningUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID:String! = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: owningUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let result = uploadTextFile(batchUUID: UUID().uuidString, testAccount: sharingUser, owningAccountType: owningUser.scheme.accountName, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID), fileLabel: UUID().uuidString, errorExpected: true, fileGroup: fileGroup)
        XCTAssert(result == nil)
    }
    
    // Also want to make sure that the user we remove from the sharing group is *not* the last user in the sharing group so the sharing group is not removed.
    func removeUserFromSharingGroup_thenTryEndpoint(usingThatSharingGroup: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        let sharingInvitationUUID:String! = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        guard let redeemSharingInvitationResponse = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }

        let key1 = SharingGroupRepository.LookupKey.sharingGroupUUID(sharingGroupUUID)
        let result1 = SharingGroupRepository(db).lookup(key: key1, modelInit: SharingGroup.init)
        guard case .found(let model) = result1, let sharingGroup = model as? Server.SharingGroup else {
            XCTFail()
            return
        }
        
        // Still one user in sharing group-- should not be deleted.
        guard !sharingGroup.deleted else {
            XCTFail()
            return
        }
        
        guard let userId = redeemSharingInvitationResponse.userId else {
            XCTFail()
            return
        }
        
        let key2 = SharingGroupUserRepository.LookupKey.userId(userId)
        let result2 = SharingGroupUserRepository(db).lookup(key: key2 , modelInit: SharingGroupUser.init)
        guard case .found(let model2) = result2,
            let sharingGroupUser = model2 as? Server.SharingGroupUser else {
            XCTFail()
            return
        }
        
        guard sharingGroupUser.deleted else {
            XCTFail()
            return
        }
        
        // Try another endpoint using `sharingUser` -- want to make sure an endpoint not using the sharing group works, but that an endpoint using the sharing group doesn't work.
        
        if usingThatSharingGroup {
            getIndex(testUser: sharingUser, deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID, errorExpected: true)
        }
        else {
            getIndex(testUser: sharingUser, deviceUUID: deviceUUID)
        }
    }

    func testRemoveUserFromSharingGroup_thenDoNotTryEndpointUsingThatSharingGroup() {
        removeUserFromSharingGroup_thenTryEndpoint(usingThatSharingGroup: false)
    }
    
    func testRemoveUserFromSharingGroup_thenTryEndpointUsingThatSharingGroup() {
        removeUserFromSharingGroup_thenTryEndpoint(usingThatSharingGroup: true)
    }
    
    func testInterleavedUploadsToDifferentSharingGroupsWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID1 = Foundation.UUID().uuidString
        let fileGroup1 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        let fileGroup2 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo2")

        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID1, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingGroup = ServerShared.SharingGroup()
        let sharingGroupUUID2 = UUID().uuidString
        
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }

        uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID1), fileLabel: UUID().uuidString, fileGroup: fileGroup1)

        uploadTextFile(batchUUID: UUID().uuidString, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID2), fileLabel: UUID().uuidString, fileGroup: fileGroup2)
    }
    
    func testRemoveUserFromSharingGroup_thenReAddUser() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let owningUser:TestAccount = .primaryOwningAccount
        guard let _ = self.addNewUser(testAccount: owningUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID2 = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID2 != nil else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID2) else {
            XCTFail()
            return
        }
    }
    
    func testRemoveUserFromSharingGroup_thenReAddUserAndUploadFile() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let owningUser:TestAccount = .primaryOwningAccount
        let fileGroup1 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")

        guard let _ = self.addNewUser(testAccount: owningUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let sharingInvitationUUID2 = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID2) else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(batchUUID: UUID().uuidString, testAccount: sharingUser, owningAccountType: owningUser.scheme.accountName, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID), fileLabel: UUID().uuidString, errorExpected: false, fileGroup: fileGroup1) else {
            XCTFail()
            return
        }
    }
    
    func testRemoveUserFromSharingGroup_thenReAddUserAndIndex() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let owningUser:TestAccount = .primaryOwningAccount
        guard let _ = self.addNewUser(testAccount: owningUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let sharingInvitationUUID2 = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID2) else {
            XCTFail()
            return
        }
        
        getIndex(testUser: sharingUser, deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID)
    }
    
    // I want to be able to re-add a user to a sharing group after they have been removed. Test will look like this: a) redeem invite to sharing group, b) add a file to that sharing group, c) remove yourself from the sharing group, d) redeem another invite to that sharing group, e) make sure there are no files present in the sharing group, f) add a file to the sharing group.
    func testRemoveUserFromSharingGroup_uploadFileAfterReAdd() {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let owningUser:TestAccount = .primaryOwningAccount
        let fileGroup1 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo")
        let fileGroup2 = FileGroup(fileGroupUUID: UUID().uuidString, objectType: "Foo2")

        guard let _ = self.addNewUser(testAccount: owningUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }
        
        let sharingInvitationUUID = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID)
        guard sharingInvitationUUID != nil else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .nonOwningSharingAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }

        guard let _ = uploadTextFile(batchUUID: UUID().uuidString, testAccount: sharingUser, owningAccountType: owningUser.scheme.accountName, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID), fileLabel: UUID().uuidString, errorExpected: false, fileGroup: fileGroup1) else {
            XCTFail()
            return
        }
        
        guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let sharingInvitationUUID2 = createSharingInvitation(testAccount: owningUser, permission: .write, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID2) else {
            XCTFail()
            return
        }
        
        // Make sure there is one file in the sharing group.
        guard let (fileInfo, _) = getIndex(testAccount:sharingUser, deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID),
            fileInfo?.count == 1 else {
            XCTFail()
            return
        }
        
        guard let _ = uploadTextFile(batchUUID: UUID().uuidString, testAccount: sharingUser, owningAccountType: owningUser.scheme.accountName, deviceUUID:deviceUUID, addUser: .no(sharingGroupUUID:sharingGroupUUID), fileLabel: UUID().uuidString, errorExpected: false, fileGroup: fileGroup2) else {
            XCTFail()
            return
        }
        
        // Make sure there are two files.
        guard let (fileInfo2, _) = getIndex(testAccount:sharingUser, deviceUUID:deviceUUID, sharingGroupUUID: sharingGroupUUID),
            fileInfo2?.count == 2 else {
            XCTFail()
            return
        }
    }
    
    func indexReportsSharingGroup(removeUser: Bool) {
        let deviceUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = self.addNewUser(sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        guard let sharingInvitationUUID = createSharingInvitation(permission: .read, sharingGroupUUID:sharingGroupUUID) else {
            XCTFail()
            return
        }
        
        let sharingUser: TestAccount = .secondaryOwningAccount
        
        guard let _ = redeemSharingInvitation(sharingUser:sharingUser, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        if removeUser {
            guard removeUserFromSharingGroup(testAccount: sharingUser, deviceUUID: deviceUUID, sharingGroupUUID: sharingGroupUUID) else {
                XCTFail()
                return
            }
        }
        
        // Sync/index should still report the sharing group
        guard let (_, sharingGroups) = getIndex(testAccount:sharingUser, deviceUUID:deviceUUID),
            sharingGroups.count == 1 else {
            XCTFail()
            return
        }
        
        let filtered = sharingGroups.filter { $0.sharingGroupUUID == sharingGroupUUID}
        guard filtered.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(filtered[0].deleted == removeUser)
    }
    
    func testRemoveUserFromSharingGroup_indexReportsSharingGroup() {
        indexReportsSharingGroup(removeUser: true)
    }
    
    func testDoNotRemoveUserFromSharingGroup_indexReportsSharingGroup() {
        indexReportsSharingGroup(removeUser: false)
    }
}
