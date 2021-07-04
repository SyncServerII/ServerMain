//
//  SpecificDatabaseTests_FileGroups.swift
//  DatabaseTests
//
//  Created by Christopher G Prince on 7/3/21.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Credentials
import Foundation
import ServerShared

class SpecificDatabaseTests_FileGroups: ServerTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testAddFileGroupWithoutOwningUserId() throws {
        let fileGroupRepo = FileGroupRepository(db)
        let fg = FileGroups()
        fg.fileGroupUUID = UUID().uuidString
        fg.userId = UserId(10)
        fg.objectType = "Foobar"
        fg.sharingGroupUUID = UUID().uuidString
        
        guard let resultId = fileGroupRepo.add(model: fg) else {
            XCTFail()
            return
        }
        
        let key = FileGroupRepository.LookupKey.fileGroupId(resultId)

        let lookupResult = fileGroupRepo.lookup(key: key, modelInit: FileGroups.init)

        if case .found(let model) = lookupResult,
            let fg2 = model as? FileGroups {
            XCTAssert(fg2.fileGroupUUID == fg.fileGroupUUID)
            XCTAssert(fg2.userId == fg.userId)
            XCTAssert(fg2.owningUserId == nil)
            XCTAssert(fg2.objectType == fg.objectType)
            XCTAssert(fg2.sharingGroupUUID == fg.sharingGroupUUID)
            XCTAssert(fg2.owningUserId == nil)
        }
        else {
            XCTFail()
        }
    }
    
    func testAddFileGroupWithOwningUserId() throws {
        let fileGroupRepo = FileGroupRepository(db)
        let fg = FileGroups()
        fg.fileGroupUUID = UUID().uuidString
        fg.userId = UserId(10)
        fg.owningUserId = UserId(20)
        fg.objectType = "Foobar"
        fg.sharingGroupUUID = UUID().uuidString
        
        guard let resultId = fileGroupRepo.add(model: fg) else {
            XCTFail()
            return
        }
        
        let key = FileGroupRepository.LookupKey.fileGroupId(resultId)

        let lookupResult = fileGroupRepo.lookup(key: key, modelInit: FileGroups.init)

        if case .found(let model) = lookupResult,
            let fg2 = model as? FileGroups {
            XCTAssert(fg2.fileGroupUUID == fg.fileGroupUUID)
            XCTAssert(fg2.userId == fg.userId)
            XCTAssert(fg2.owningUserId == fg.owningUserId)
            XCTAssert(fg2.objectType == fg.objectType)
            XCTAssert(fg2.sharingGroupUUID == fg.sharingGroupUUID)
        }
        else {
            XCTFail()
        }
        
        let key2 = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fg.fileGroupUUID)

        let lookupResult2 = fileGroupRepo.lookup(key: key2, modelInit: FileGroups.init)

        if case .found(let model2) = lookupResult2,
            let fg3 = model2 as? FileGroups {
            XCTAssert(fg3.fileGroupUUID == fg.fileGroupUUID)
            XCTAssert(fg3.userId == fg.userId)
            XCTAssert(fg3.owningUserId == fg.owningUserId)
            XCTAssert(fg3.objectType == fg.objectType)
            XCTAssert(fg3.sharingGroupUUID == fg.sharingGroupUUID)
        }
        else {
            XCTFail()
        }
    }
}
