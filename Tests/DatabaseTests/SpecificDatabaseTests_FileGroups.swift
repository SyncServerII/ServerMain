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
        let fg = FileGroupModel()
        fg.fileGroupUUID = UUID().uuidString
        fg.userId = UserId(10)
        fg.objectType = "Foobar"
        fg.sharingGroupUUID = UUID().uuidString
        
        guard let resultId = fileGroupRepo.add(model: fg) else {
            XCTFail()
            return
        }
        
        let key = FileGroupRepository.LookupKey.fileGroupId(resultId)

        let lookupResult = fileGroupRepo.lookup(key: key, modelInit: FileGroupModel.init)

        if case .found(let model) = lookupResult,
            let fg2 = model as? FileGroupModel {
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
        let fg = FileGroupModel()
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

        let lookupResult = fileGroupRepo.lookup(key: key, modelInit: FileGroupModel.init)

        if case .found(let model) = lookupResult,
            let fg2 = model as? FileGroupModel {
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

        let lookupResult2 = fileGroupRepo.lookup(key: key2, modelInit: FileGroupModel.init)

        if case .found(let model2) = lookupResult2,
            let fg3 = model2 as? FileGroupModel {
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
    
    func testLookupAllFileGroups_singleFileGroup() {
        let fileGroupRepo = FileGroupRepository(db)
        let fg = FileGroupModel()
        fg.fileGroupUUID = UUID().uuidString
        fg.userId = UserId(10)
        fg.owningUserId = UserId(20)
        fg.objectType = "Foobar"
        fg.sharingGroupUUID = UUID().uuidString
        
        guard let resultId = fileGroupRepo.add(model: fg) else {
            XCTFail()
            return
        }
        
        let key = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fg.fileGroupUUID)
        guard let results = fileGroupRepo.lookupAll(keys: [key], modelInit: FileGroupModel.init) else {
            XCTFail()
            return
        }
        
        guard results.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(results[0].fileGroupUUID == fg.fileGroupUUID)
    }
    
    func testLookupAllFileGroups_multipleFileGroups() {
        let fileGroupRepo = FileGroupRepository(db)
        let fg = FileGroupModel()
        fg.fileGroupUUID = UUID().uuidString
        fg.userId = UserId(10)
        fg.owningUserId = UserId(20)
        fg.objectType = "Foobar"
        fg.sharingGroupUUID = UUID().uuidString
        
        guard let resultId = fileGroupRepo.add(model: fg) else {
            XCTFail()
            return
        }
        
        let fg2 = FileGroupModel()
        fg2.fileGroupUUID = UUID().uuidString
        fg2.userId = UserId(10)
        fg2.owningUserId = UserId(20)
        fg2.objectType = "Foobar"
        fg2.sharingGroupUUID = UUID().uuidString
        
        guard let resultId2 = fileGroupRepo.add(model: fg2) else {
            XCTFail()
            return
        }
        
        let fg3 = FileGroupModel()
        fg3.fileGroupUUID = UUID().uuidString
        fg3.userId = UserId(10)
        fg3.owningUserId = UserId(20)
        fg3.objectType = "Foobar"
        fg3.sharingGroupUUID = UUID().uuidString
        
        guard let resultId3 = fileGroupRepo.add(model: fg3) else {
            XCTFail()
            return
        }
        
        let key1 = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fg.fileGroupUUID)
        let key2 = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fg2.fileGroupUUID)
        guard let results = fileGroupRepo.lookupAll(keys: [key1, key2], modelInit: FileGroupModel.init) else {
            XCTFail()
            return
        }
        
        guard results.count == 2 else {
            XCTFail()
            return
        }
        
        let filter1 = results.filter { $0.fileGroupUUID == fg.fileGroupUUID }
        let filter2 = results.filter { $0.fileGroupUUID == fg2.fileGroupUUID }
        guard filter1.count == 1, filter2.count == 1 else {
            XCTFail()
            return
        }
    }
}
