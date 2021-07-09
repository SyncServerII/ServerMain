//
//  SharingGroupsController_MoveFileGroups.swift
//  SharingTests
//
//  Created by Christopher G Prince on 7/3/21.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import Foundation
import ServerShared

class SharingGroupsController_MoveFileGroups: ServerTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    enum FileGroupTest {
        case badUUID
        case unknownUUID
        case knownFileGroup
        case noFileGroup
        case duplicateFileGroup
    }
    
    func runFileGroupTest(_ fileGroupTest: FileGroupTest) {
        let sharingGroupUUID = UUID().uuidString
        let deviceUUID = UUID().uuidString
        let testUser: TestAccount = .primaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
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
        
        let fileGroupUUIDs: [String]
        let errorExpected:Bool
        let fileGroupUUID = UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUID, objectType: "Foobly")
        var upload = false
        
        switch fileGroupTest {
        case .duplicateFileGroup:
            fileGroupUUIDs = [fileGroupUUID, fileGroupUUID]
            errorExpected = true
            upload = true
            
        case .noFileGroup:
            fileGroupUUIDs = []
            errorExpected = true
            
        case .badUUID:
            fileGroupUUIDs = ["Foobly"]
            errorExpected = true
            
        case .unknownUUID:
            fileGroupUUIDs = [UUID().uuidString]
            errorExpected = true
            
        case .knownFileGroup:
            fileGroupUUIDs = [fileGroupUUID]
            errorExpected = false
            upload = true
        }
        
        if upload {
            guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
                XCTFail()
                return
            }
            
            guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(fileGroupModel.sharingGroupUUID == sharingGroupUUID)
        }
        
        let result = moveFileGroups(testUser: testUser, deviceUUID: deviceUUID, sourceSharingGroupUUID: sharingGroupUUID, destinationSharingGroupUUID: sharingGroupUUID2, fileGroupUUIDs: fileGroupUUIDs, errorExpected: errorExpected)
        
        switch fileGroupTest {
        case .badUUID, .unknownUUID, .noFileGroup, .duplicateFileGroup:
            XCTAssert(result == nil)
            
        case .knownFileGroup:
            guard result != nil else {
                XCTFail()
                return
            }
            
            guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(fileGroupModel.sharingGroupUUID == sharingGroupUUID2)
        }
    }
    
    enum SharingGroupTest {
        case badSource
        case unknownSource
        case knownSourceAndDestination

        case badDestination
        case unknownDestination
        
        case sameSourceAsDestination
    }
    
    func runSharingGroupTest(_ sharingGroupTest: SharingGroupTest) {
        let sharingGroupUUID = UUID().uuidString
        let deviceUUID = UUID().uuidString
        let testUser: TestAccount = .primaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
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
        
        let fileGroupUUID = UUID().uuidString
        let fileGroupUUIDs: [String] = [fileGroupUUID]
        let errorExpected:Bool
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUID, objectType: "Foobly")
        let source: String
        var dest: String
        
        switch sharingGroupTest {
        case .badSource:
            errorExpected = true
            source = "Foobar"
            dest = sharingGroupUUID2
            
        case .unknownSource:
            errorExpected = true
            source = UUID().uuidString
            dest = sharingGroupUUID2
            
        case .knownSourceAndDestination:
            errorExpected = false
            source = sharingGroupUUID
            dest = sharingGroupUUID2
            
        case .badDestination:
            errorExpected = true
            source = sharingGroupUUID
            dest = "Foobar"
            
        case .unknownDestination:
            errorExpected = true
            source = sharingGroupUUID
            dest = UUID().uuidString
            
        case .sameSourceAsDestination:
            errorExpected = true
            source = sharingGroupUUID
            dest = sharingGroupUUID
        }

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
            XCTFail()
            return
        }
        
        guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
            XCTFail()
            return
        }
        
        XCTAssert(fileGroupModel.sharingGroupUUID == sharingGroupUUID)
        
        let result = moveFileGroups(testUser: testUser, deviceUUID: deviceUUID, sourceSharingGroupUUID: source, destinationSharingGroupUUID: dest, fileGroupUUIDs: fileGroupUUIDs, errorExpected: errorExpected)
        
        switch sharingGroupTest {
        case .badSource, .unknownSource, .badDestination, .unknownDestination, .sameSourceAsDestination:
            XCTAssert(result == nil)
            
        case .knownSourceAndDestination:
            guard result != nil else {
                XCTFail()
                return
            }
            
            guard let fileGroupModel = try? FileGroupRepository(db).getFileGroup(forFileGroupUUID: fileGroup.fileGroupUUID) else {
                XCTFail()
                return
            }
            
            XCTAssert(fileGroupModel.sharingGroupUUID == sharingGroupUUID2)
        }
    }
    
    // MARK: File groups
    
    func testBadUUIDForFileGroupInRequestFails() throws {
        runFileGroupTest(.badUUID)
    }
    
    func testUnknownUUIDForFileGroupInRequestFails() throws {
        runFileGroupTest(.unknownUUID)
    }
    
    func testKnownUUIDForFileGroupInRequestWorks() throws {
        runFileGroupTest(.knownFileGroup)
    }
    
    func testNoFileGroupsInRequestFails() throws {
        runFileGroupTest(.noFileGroup)
    }
    
    func testDuplicateFileGroupInRequestFails() {
        runFileGroupTest(.duplicateFileGroup)
    }

    // MARK: Sharing groups

    func testBadUUIDSourceSharingGroupFails() throws {
        runSharingGroupTest(.badSource)
    }
    
    func testUnknownSourceSharingGroupFails() throws {
        runSharingGroupTest(.unknownSource)
    }
    
    func testKnownSourceAndDestinationSharingGroupWorks() throws {
        runSharingGroupTest(.knownSourceAndDestination)
    }
    
    func testBadUUIDDestinationSharingGroupFails() throws {
        runSharingGroupTest(.badDestination)
    }
    
    func testUnknownDestinationSharingGroupFails() throws {
        runSharingGroupTest(.unknownDestination)
    }
    
    func testSourceIsTheSameAsTheDestinationFails() throws {
        runSharingGroupTest(.sameSourceAsDestination)
    }
    
    // MARK: Other tests

    func runSharingGroupTest(allFileGroupsInSourceSharingGroup: Bool) {
        let sharingGroupUUID = UUID().uuidString
        let deviceUUID = UUID().uuidString
        let testUser: TestAccount = .primaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser, sharingGroupUUID: sharingGroupUUID, deviceUUID:deviceUUID) else {
            XCTFail()
            return
        }

        let sharingGroup = ServerShared.SharingGroup()
        let sharingGroupUUID2 = UUID().uuidString
        
        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID, sharingGroup: sharingGroup) else {
            XCTFail()
            return
        }

        let sharingGroup3 = ServerShared.SharingGroup()
        let sharingGroupUUID3 = UUID().uuidString

        guard createSharingGroup(sharingGroupUUID: sharingGroupUUID3, deviceUUID:deviceUUID, sharingGroup: sharingGroup3) else {
            XCTFail()
            return
        }
        
        let fileGroupUUID = UUID().uuidString
        let fileGroupUUID2 = UUID().uuidString

        let fileGroupUUIDs: [String]
        let errorExpected: Bool
        
        if allFileGroupsInSourceSharingGroup {
            fileGroupUUIDs = [fileGroupUUID]
            errorExpected = false
        }
        else {
            fileGroupUUIDs = [fileGroupUUID, fileGroupUUID2]
            errorExpected = true
        }

        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUID, objectType: "Foobly")
        let fileGroup2 = FileGroup(fileGroupUUID: fileGroupUUID2, objectType: "Foobly2")

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
            XCTFail()
            return
        }

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, deviceUUID:deviceUUID, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID3), fileLabel: UUID().uuidString, fileGroup: fileGroup2) else {
            XCTFail()
            return
        }

        let result = moveFileGroups(testUser: testUser, deviceUUID: deviceUUID, sourceSharingGroupUUID: sharingGroupUUID, destinationSharingGroupUUID: sharingGroupUUID2, fileGroupUUIDs: fileGroupUUIDs, errorExpected: errorExpected)
        if errorExpected {
            XCTAssert(result == nil)
        }
        else {
            XCTAssert(result != nil)
        }
    }

    func testNotAllFileGroupsInSourceSharingGroupFails() throws {
        runSharingGroupTest(allFileGroupsInSourceSharingGroup: false)
    }

    func testAllFileGroupsInSourceSharingGroupWorks() throws {
        runSharingGroupTest(allFileGroupsInSourceSharingGroup: true)
    }
    
    func runTest(allFileGroupOwnersInDestSharingGroup: Bool) {
        let sharingGroupUUID1 = UUID().uuidString
        let sharingGroupUUID2 = UUID().uuidString
        
        let deviceUUID1 = UUID().uuidString
        let deviceUUID2 = UUID().uuidString

        let testUser1: TestAccount = .primaryOwningAccount
        let testUser2: TestAccount = .secondaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID1, deviceUUID:deviceUUID1) else {
            XCTFail()
            return
        }
        
        guard let _ = addNewUser(testAccount: testUser2, sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID2) else {
            XCTFail()
            return
        }
        
        let sharingGroup3 = ServerShared.SharingGroup()
        let sharingGroupUUID3 = UUID().uuidString

        guard createSharingGroup(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID3, deviceUUID:deviceUUID1, sharingGroup: sharingGroup3) else {
            XCTFail()
            return
        }
        
        guard let sharingInvitationUUID = createSharingInvitation(testAccount: testUser1, permission: .write, sharingGroupUUID: sharingGroupUUID1) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser: testUser2, sharingInvitationUUID: sharingInvitationUUID) else {
            XCTFail()
            return
        }
        
        if allFileGroupOwnersInDestSharingGroup {
            guard let sharingInvitationUUID = createSharingInvitation(testAccount: testUser1, permission: .write, sharingGroupUUID: sharingGroupUUID3) else {
                XCTFail()
                return
            }
            
            guard let _ = redeemSharingInvitation(sharingUser: testUser2, sharingInvitationUUID: sharingInvitationUUID) else {
                XCTFail()
                return
            }
        }
        
        let fileGroupUUI1 = UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUI1, objectType: "Foobly")
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: testUser2, deviceUUID:deviceUUID2, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
            XCTFail()
            return
        }
        
        let fileGroups = [fileGroupUUI1]
        
        guard let response = moveFileGroups(testUser: testUser1, deviceUUID: deviceUUID1, sourceSharingGroupUUID: sharingGroupUUID1, destinationSharingGroupUUID: sharingGroupUUID3, fileGroupUUIDs: fileGroups, errorExpected: false) else {
            XCTFail()
            return
        }
        
        if allFileGroupOwnersInDestSharingGroup {
            XCTAssert(response.result == .success)
        }
        else {
            XCTAssert(response.result == .failedWithNotAllOwnersInTarget)
        }
    }
    
    func testNotAllFileGroupOwnersInDestSharingGroup() {
        runTest(allFileGroupOwnersInDestSharingGroup: false)
    }

    func testAllFileGroupOwnersInDestSharingGroup() {
        runTest(allFileGroupOwnersInDestSharingGroup: true)
    }

    enum MoveAsUser {
        case nonAdminInDest
        case nonAdminInSource
        case adminInBoth
    }
    
    func runTest(moveAsUser: MoveAsUser) {
        let sharingGroupUUID1 = UUID().uuidString
        let sharingGroupUUID2 = UUID().uuidString
        
        let deviceUUID1 = UUID().uuidString
        let deviceUUID2 = UUID().uuidString

        let testUser1: TestAccount = .primaryOwningAccount
        let testUser2: TestAccount = .secondaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID1, deviceUUID:deviceUUID1) else {
            XCTFail()
            return
        }
        
        guard let _ = addNewUser(testAccount: testUser2, sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID2) else {
            XCTFail()
            return
        }
        
        let sharingGroup3 = ServerShared.SharingGroup()
        let sharingGroupUUID3 = UUID().uuidString

        guard createSharingGroup(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID3, deviceUUID:deviceUUID1, sharingGroup: sharingGroup3) else {
            XCTFail()
            return
        }
        
        var errorExpected = false

        var sourcePermission: Permission = .admin
        if moveAsUser == .nonAdminInSource {
            sourcePermission = .write
            errorExpected = true
        }
        
        guard let sharingInvitationUUID1 = createSharingInvitation(testAccount: testUser1, permission: sourcePermission, sharingGroupUUID: sharingGroupUUID1) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser: testUser2, sharingInvitationUUID: sharingInvitationUUID1) else {
            XCTFail()
            return
        }

        var destPermission: Permission = .admin
        if moveAsUser == .nonAdminInDest {
            destPermission = .write
            errorExpected = true
        }
        
        guard let sharingInvitationUUID2 = createSharingInvitation(testAccount: testUser1, permission: destPermission, sharingGroupUUID: sharingGroupUUID3) else {
            XCTFail()
            return
        }
        
        guard let _ = redeemSharingInvitation(sharingUser: testUser2, sharingInvitationUUID: sharingInvitationUUID2) else {
            XCTFail()
            return
        }
        
        let fileGroupUUI1 = UUID().uuidString
        let fileGroup = FileGroup(fileGroupUUID: fileGroupUUI1, objectType: "Foobly")
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: testUser2, deviceUUID:deviceUUID2, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: UUID().uuidString, fileGroup: fileGroup) else {
            XCTFail()
            return
        }
        
        let fileGroups = [fileGroupUUI1]
        
        let response = moveFileGroups(testUser: testUser2, deviceUUID: deviceUUID2, sourceSharingGroupUUID: sharingGroupUUID1, destinationSharingGroupUUID: sharingGroupUUID3, fileGroupUUIDs: fileGroups, errorExpected: errorExpected)
        
        switch moveAsUser {
        case .nonAdminInSource, .nonAdminInDest:
            XCTAssert(response == nil)
        case .adminInBoth:
            XCTAssert(response != nil)
        }
    }
    
    func testMoveAsNonAdminUserForDestFails() {
        runTest(moveAsUser: .nonAdminInDest)
    }
    
    func testMoveAsNonAdminUserForSourceFails() {
        runTest(moveAsUser: .nonAdminInSource)
    }
 
    func testMoveAsAdminUserForBothWorks() {
        runTest(moveAsUser: .adminInBoth)
    }
    
    func testMultipleFileGroupsToSuccessfullyMoveWorks() throws {
        let sharingGroupUUID1 = UUID().uuidString
        let sharingGroupUUID2 = UUID().uuidString
        let deviceUUID1 = UUID().uuidString
        let testUser1: TestAccount = .primaryOwningAccount

        guard let _ = addNewUser(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID1, deviceUUID:deviceUUID1) else {
            XCTFail()
            return
        }
                
        let sharingGroup2 = ServerShared.SharingGroup()

        guard createSharingGroup(testAccount: testUser1, sharingGroupUUID: sharingGroupUUID2, deviceUUID:deviceUUID1, sharingGroup: sharingGroup2) else {
            XCTFail()
            return
        }
        
        let fileGroupUUI1 = UUID().uuidString
        let fileGroup1 = FileGroup(fileGroupUUID: fileGroupUUI1, objectType: "Foobly")
        let fileGroupUUI2 = UUID().uuidString
        let fileGroup2 = FileGroup(fileGroupUUID: fileGroupUUI2, objectType: "Foobly2")
        
        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: testUser1, deviceUUID:deviceUUID1, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: UUID().uuidString, fileGroup: fileGroup1) else {
            XCTFail()
            return
        }

        guard let _ = uploadTextFile(uploadIndex: 1, uploadCount: 1, batchUUID: UUID().uuidString, testAccount: testUser1, deviceUUID:deviceUUID1, fileUUID: UUID().uuidString, addUser: .no(sharingGroupUUID: sharingGroupUUID1), fileLabel: UUID().uuidString, fileGroup: fileGroup2) else {
            XCTFail()
            return
        }
        
        let fileGroups = [fileGroupUUI1, fileGroupUUI2]
        
        let response = moveFileGroups(testUser: testUser1, deviceUUID: deviceUUID1, sourceSharingGroupUUID: sharingGroupUUID1, destinationSharingGroupUUID: sharingGroupUUID2, fileGroupUUIDs: fileGroups, errorExpected: false)
        XCTAssert(response != nil)
    }
}

extension SharingGroupsController_MoveFileGroups {
    func moveFileGroups(testUser:TestAccount, deviceUUID:String = Foundation.UUID().uuidString, sourceSharingGroupUUID: String, destinationSharingGroupUUID: String, fileGroupUUIDs: [String], errorExpected:Bool=false) -> MoveFileGroupsResponse? {
    
        var result:MoveFileGroupsResponse?
        
        self.performServerTest(testAccount:testUser) { [weak self] expectation, accountCreds in
            guard let self = self else { return }
            guard let accessToken = accountCreds.accessToken else {
                XCTFail()
                expectation.fulfill()
                return
            }
            
            let headers = self.setupHeaders(testUser: testUser, accessToken: accessToken, deviceUUID:deviceUUID)
            
            let request = MoveFileGroupsRequest()
            request.sourceSharingGroupUUID = sourceSharingGroupUUID
            request.destinationSharingGroupUUID = destinationSharingGroupUUID
            request.fileGroupUUIDs = fileGroupUUIDs
            
            guard let data = try? JSONEncoder().encode(request) else {
                XCTFail()
                expectation.fulfill()
                return
            }
            
            self.performRequest(route: ServerEndpoints.moveFileGroupsFromSourceSharingGroupToDest, headers: headers, urlParameters: nil, body:data) { response, dict in
                Log.info("Status code: \(String(describing: response?.statusCode))")
                
                if errorExpected {
                    XCTAssert(response?.statusCode != .OK, "Worked on request!")
                }
                else {
                    XCTAssert(response?.statusCode == .OK, "Did not work on request")
                    
                    if let dict = dict,
                        let response = try? MoveFileGroupsResponse.decode(dict) {
                        result = response
                    }
                    else {
                        XCTFail("\(dict)")
                    }
                }
                
                expectation.fulfill()
            }
        }
        
        return result
    }
}
