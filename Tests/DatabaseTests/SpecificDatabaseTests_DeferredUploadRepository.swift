//
//  SpecificDatabaseTests_DeferredUploadRepository.swift
//  Server
//
//  Created by Christopher Prince on 7/11/20
//
//

import XCTest
@testable import Server
@testable import TestsCommon
import LoggerAPI
import HeliumLogger
import Foundation
import ServerShared

class SpecificDatabaseTests_DeferredUploadRepository: ServerTestCase {
    var repo: DeferredUploadRepository!
    
    override func setUp() {
        super.setUp()
        repo = DeferredUploadRepository(db)
    }
    
    func doAddDeferredUpload(userId: UserId, status: DeferredUploadStatus, sharingGroupUUID: String, batchUUID: String?, fileGroupUUID: String? = nil) -> DeferredUpload? {
        let deferredUpload = DeferredUpload()

        deferredUpload.status = status
        deferredUpload.fileGroupUUID = fileGroupUUID
        deferredUpload.sharingGroupUUID = sharingGroupUUID
        deferredUpload.userId = userId
        deferredUpload.batchUUID = batchUUID
        
        let result = repo.add(deferredUpload)
        
        var deferredUploadId:Int64?
        switch result {
        case .success(deferredUploadId: let id):
            deferredUploadId = id
        
        default:
            return nil
        }
        
        deferredUpload.deferredUploadId = deferredUploadId
        
        return deferredUpload
    }
    
    func testAddDeferredUploadWorks() {
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: Foundation.UUID().uuidString, batchUUID: Foundation.UUID().uuidString) else {
            XCTFail()
            return
        }
    }
    
    func testUpdateDeferredUploadWithValidFieldsWorks() {
        let fileGroupUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        
        guard let deferredUpload = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }
                
        let newStatus = DeferredUploadStatus.completed
        deferredUpload.status = newStatus
        
        guard repo.update(deferredUpload) else {
            XCTFail()
            return
        }
        
        guard let id = deferredUpload.deferredUploadId else {
            XCTFail()
            return
        }
        
        let key = DeferredUploadRepository.LookupKey.deferredUploadId(id)
        let result = repo.lookup(key: key, modelInit: DeferredUpload.init)
        switch result {
        case .found(let model):
            guard let model = model as? DeferredUpload else {
                XCTFail()
                return
            }
            
            XCTAssert(model.deferredUploadId == id)
            XCTAssert(model.status == newStatus)
            XCTAssert(model.fileGroupUUID == fileGroupUUID)
            XCTAssert(model.sharingGroupUUID == sharingGroupUUID)
        default:
            XCTFail()
        }
    }
    
    func testUpdateDeferredUploadWithBatchUUIDWorks() {
        let fileGroupUUID = Foundation.UUID().uuidString
        let sharingGroupUUID = Foundation.UUID().uuidString
        let batchUUID = Foundation.UUID().uuidString
        
        guard let deferredUpload = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: batchUUID, fileGroupUUID: fileGroupUUID) else {
            XCTFail()
            return
        }

        guard let deferredUploadId = deferredUpload.deferredUploadId else {
            XCTFail()
            return
        }
        
        let newStatus = DeferredUploadStatus.completed
        deferredUpload.status = newStatus
        
        // Should work with just the batchUUID and not the deferredUploadId to key the update
        deferredUpload.deferredUploadId = nil
        
        guard repo.update(deferredUpload) else {
            XCTFail()
            return
        }
        
        let key1 = DeferredUploadRepository.LookupKey.deferredAndBatch(deferredUploadId: nil, batchUUID: batchUUID)
        let result1 = repo.lookup(key: key1, modelInit: DeferredUpload.init)
        switch result1 {
        case .found(let model):
            guard let model = model as? DeferredUpload else {
                XCTFail()
                return
            }
            
            XCTAssert(model.deferredUploadId == deferredUploadId)
            XCTAssert(model.status == newStatus)
            XCTAssert(model.fileGroupUUID == fileGroupUUID)
            XCTAssert(model.sharingGroupUUID == sharingGroupUUID)
            XCTAssert(model.batchUUID == batchUUID)

        default:
            XCTFail()
            return
        }
        
        let key2 = DeferredUploadRepository.LookupKey.deferredAndBatch(deferredUploadId: deferredUploadId, batchUUID: batchUUID)
        let result2 = repo.lookup(key: key2, modelInit: DeferredUpload.init)
        switch result2 {
        case .found(let model):
            guard let model = model as? DeferredUpload else {
                XCTFail()
                return
            }
            
            XCTAssert(model.deferredUploadId == deferredUploadId)
            XCTAssert(model.status == newStatus)
            XCTAssert(model.fileGroupUUID == fileGroupUUID)
            XCTAssert(model.sharingGroupUUID == sharingGroupUUID)
            XCTAssert(model.batchUUID == batchUUID)

        default:
            XCTFail()
            return
        }
    }

    func testUpdateDeferredUploadWithNilStatusFails() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let deferredUpload = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        deferredUpload.status = nil
        
        guard !repo.update(deferredUpload) else {
            XCTFail()
            return
        }
    }
    
    // This doesn't fail because it has a batchUUID with which to do a query.
    func testUpdateDeferredUploadWithNilIdAndBatchDoesNotFail() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let deferredUpload = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: Foundation.UUID().uuidString) else {
            XCTFail()
            return
        }
        
        deferredUpload.deferredUploadId = nil
        
        guard repo.update(deferredUpload) else {
            XCTFail()
            return
        }
    }
    
    // This *does* fail because it has neither deferredUploadId nor a batchUUID with which to do the query.
    func testUpdateDeferredUploadWithNilIdAndNilBatchFails() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let deferredUpload = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        deferredUpload.deferredUploadId = nil
        
        guard !repo.update(deferredUpload) else {
            XCTFail()
            return
        }
    }
    
    func testSelectWithNoRowsWorks() {
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        XCTAssert(result.count == 0)
    }
    
    func testSelectWithOneRowWorks() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        XCTAssert(result.count == 1)
    }
    
    func testSelectWithTwoRowsWorks() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        XCTAssert(result.count == 2)
    }
    
    func testSelectWithTwoRowsButOnlyOnePendingWorks() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let _ = doAddDeferredUpload(userId: 1, status: .completed, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        XCTAssert(result.count == 1)
    }
    
    func testDeferredUploadWithNilBatchUUID() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: nil) else {
            XCTFail()
            return
        }
        
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        guard result.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(result[0].batchUUID == nil)
    }
    
    func testDeferredUploadWithNonNilBatchUUID() {
        let sharingGroupUUID = Foundation.UUID().uuidString
        let batchUUID = Foundation.UUID().uuidString

        guard let _ = doAddDeferredUpload(userId: 1, status: .pendingChange, sharingGroupUUID: sharingGroupUUID, batchUUID: batchUUID) else {
            XCTFail()
            return
        }
        
        guard let result = repo.select(rowsWithStatus: [.pendingChange]) else {
            XCTFail()
            return
        }
        
        guard result.count == 1 else {
            XCTFail()
            return
        }
        
        XCTAssert(result[0].batchUUID == batchUUID)
    }
}
