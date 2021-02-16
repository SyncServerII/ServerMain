//
//  SpecificDatabaseTests_StaleVersion.swift
//  DatabaseTests
//
//  Created by Christopher G Prince on 2/15/21.
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
import ServerGoogleAccount
import ServerAccount

class SpecificDatabaseTests_StaleVersion: ServerTestCase {
    override func setUp() {
        super.setUp()
        if case .failure = StaleVersionRepository(db).upcreate() {
            XCTFail()
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func doAddStaleVersion(fileUUID: String, deviceUUID: String, fileVersion: FileVersionInt, fileIndexId: FileIndexId, expiryDate: Date) -> StaleVersion? {
        let staleVersion = StaleVersion()
        
        staleVersion.fileUUID = fileUUID
        staleVersion.deviceUUID = deviceUUID
        staleVersion.fileVersion = fileVersion
        staleVersion.expiryDate = expiryDate
        staleVersion.fileIndexId = fileIndexId

        let result = StaleVersionRepository(db).add(staleVersion: staleVersion)
        
        var staleVersionId:Int64?
        switch result {
        case .success(staleVersionId: let id):
            staleVersionId = id
        
        default:
            XCTFail()
            return nil
        }
        
        guard staleVersion.staleVersionId == staleVersionId else {
            XCTFail()
            return nil
        }
        
        return staleVersion
    }
    
    func testAddSingleUpload() {
        guard let _ = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: Date()) else {
            XCTFail()
            return
        }
    }
    
    func testLookupFromStaleVersion() {
        guard let staleVersion = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: Date()) else {
            XCTFail()
            return
        }
        
        let lookupKey = StaleVersionRepository.LookupKey.uuids(fileUUID: staleVersion.fileUUID, deviceUUID: staleVersion.deviceUUID)
        let result = StaleVersionRepository(db).lookup(key: lookupKey, modelInit: StaleVersion.init)
        
        switch result {
        case .error(let error):
            XCTFail("\(error)")
            return
            
        case .found(let object):
            guard let staleVersionResult = object as? StaleVersion else {
                XCTFail()
                return
            }
            
            XCTAssert(staleVersionResult.fileUUID == staleVersion.fileUUID)
            XCTAssert(staleVersionResult.deviceUUID == staleVersion.deviceUUID)
            XCTAssert(DateExtras.equals(staleVersionResult.expiryDate, staleVersion.expiryDate))
            XCTAssert(staleVersionResult.fileVersion == staleVersion.fileVersion)
            XCTAssert(staleVersionResult.fileIndexId == staleVersion.fileIndexId)
           
        case .noObjectFound:
            XCTFail("No StaleVersion Found")
            return
        }
    }
    
    func testRemoveExpired_NoneExpectedToBeRemoved() {
        let expiry = Date().addingTimeInterval(100)
        
        guard let _ = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: expiry) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: expiry) else {
            XCTFail()
            return
        }
        
        let lookupKey = StaleVersionRepository.LookupKey.needingDeletion
        let result = StaleVersionRepository(db).remove(key: lookupKey)
        switch result {
        case .removed(let numberRows):
            XCTAssert(numberRows == 0)
            
        default:
            XCTFail()
        }
    }
    
    func testRemoveExpired_OneExpectedToBeRemoved() {
        guard let _ = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: Date().addingTimeInterval(100)) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddStaleVersion(fileUUID: UUID().uuidString, deviceUUID: UUID().uuidString, fileVersion: 1, fileIndexId: 2, expiryDate: Date().addingTimeInterval(-100)) else {
            XCTFail()
            return
        }
        
        let lookupKey = StaleVersionRepository.LookupKey.needingDeletion
        let result = StaleVersionRepository(db).remove(key: lookupKey)
        switch result {
        case .removed(let numberRows):
            XCTAssert(numberRows == 1)
            
        default:
            XCTFail()
        }
    }
}
