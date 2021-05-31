//
//  SpecificDatabaseTests_FileIndexClientUIRepository.swift
//  DatabaseTests
//
//  Created by Christopher G Prince on 5/29/21.
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared

class SpecificDatabaseTests_FileIndexClientUIRepository: ServerTestCase {
    var repo: FileIndexClientUIRepository!

    override func setUp() {
        super.setUp()
        repo = FileIndexClientUIRepository(db)
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testAddRecord() throws {
        let model = FileIndexClientUI()

        let fileVersion:FileVersionInt = 12
        let userId:UserId = 54
        let fileUUID = UUID().uuidString
        let sharingGroupUUID = UUID().uuidString
        
        model.fileUUID = fileUUID
        model.sharingGroupUUID = sharingGroupUUID
        model.fileVersion = fileVersion
        model.informAllButUserId = userId
        model.expiry = Date()
        
        guard let result = repo.add(model: model) else {
            XCTFail()
            return
        }
        
        let key = FileIndexClientUIRepository.LookupKey.fileIndexClientUIId(result)
        let lookupResult = repo.lookup(key: key, modelInit: FileIndexClientUI.init)
        
        let fileIndexClientUI: FileIndexClientUI
        
        switch lookupResult {
        case .found(let model):
            guard let model = model as? FileIndexClientUI else {
                XCTFail()
                return
            }
            
            fileIndexClientUI = model

        default:
            XCTFail()
            return
        }

        XCTAssert(fileIndexClientUI.fileUUID == fileUUID)
        XCTAssert(fileIndexClientUI.sharingGroupUUID == sharingGroupUUID)
        XCTAssert(fileIndexClientUI.fileVersion == fileVersion)
        XCTAssert(fileIndexClientUI.informAllButUserId == userId)
        XCTAssert(fileIndexClientUI.expiry != nil)
    }
}
