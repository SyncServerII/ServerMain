//
//  StaleVersionRepository.swift
//  Server
//
//  Created by Christopher G Prince on 2/15/21.
//

// Record of stale file versions -- that will be deleted after they expire.

import Foundation
import LoggerAPI
import ServerShared

typealias StaleVersionId = Int64

class StaleVersion : NSObject, Model {
    static let staleVersionIdKey = "staleVersionId"
    var staleVersionId: StaleVersionId!
    
    static let fileIndexIdKey = "fileIndexId"
    var fileIndexId: FileIndexId!
    
    static let fileUUIDKey = "fileUUID"
    var fileUUID: String!
    
    static let sharingGroupUUIDKey = "sharingGroupUUID"
    var sharingGroupUUID:String!
    
    // The stale version
    static let fileVersionKey = "fileVersion"
    var fileVersion: FileVersionInt!
    
    // The time/date after which the stale file version needs to be removed.
    static let expiryDateKey = "expiryDate"
    var expiryDate:Date!
    
    static var initialExpiryDate:Date {
        let oneDay:TimeInterval = 60 * 60 * 24
        return Date().addingTimeInterval(oneDay)
    }
    
    subscript(key:String) -> Any? {
        set {
            switch key {
            case StaleVersion.staleVersionIdKey:
                staleVersionId = newValue as? StaleVersionId

            case StaleVersion.fileIndexIdKey:
                fileIndexId = newValue as? FileIndexId
                
            case StaleVersion.fileUUIDKey:
                fileUUID = newValue as? String

            case StaleVersion.sharingGroupUUIDKey:
                sharingGroupUUID = newValue as? String

            case StaleVersion.fileVersionKey:
                fileVersion = newValue as? FileVersionInt
                
            case StaleVersion.expiryDateKey:
                expiryDate = newValue as? Date
                
            default:
                Log.debug("key: \(key)")
                assert(false)
            }
        }
        
        get {
            return getValue(forKey: key)
        }
    }
    
    required override init() {
        super.init()
    }
    
    func typeConvertersToModel(propertyName:String) -> ((_ propertyValue:Any) -> Any?)? {
        switch propertyName {            
        case StaleVersion.expiryDateKey:
            return {(x:Any) -> Any? in
                guard let x = x as? String else {
                    return nil
                }
                return DateExtras.date(x, fromFormat: .DATETIME)
            }
        
        default:
            return nil
        }
    }
}

class StaleVersionRepository : Repository, RepositoryLookup, ModelIndexId {
    static let indexIdKey = StaleVersion.staleVersionIdKey
    private(set) var db:Database!

    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return StaleVersionRepository.tableName
    }
    
    static var tableName:String {
        return "StaleVersion"
    }
    
    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "(staleVersionId BIGINT NOT NULL AUTO_INCREMENT, " +

            // From FileIndex
            "fileIndexId BIGINT NOT NULL, " +

            // From FileIndex
            "fileUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
                
            // From FileIndex
            "sharingGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +

            // From FileIndex
            "fileVersion INT NOT NULL, " +

            "expiryDate DATETIME NOT NULL," +

            "UNIQUE (staleVersionId))"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        switch result {
        case .success(.alreadyPresent):
            break

        default:
            break
        }
        
        return result
    }
    
    private func basicFieldCheck(staleVersion:StaleVersion) -> Bool {
        return staleVersion.sharingGroupUUID == nil ||
        staleVersion.fileUUID == nil ||
        staleVersion.fileVersion == nil ||
        staleVersion.expiryDate == nil ||
        staleVersion.fileIndexId == nil
    }
    
    enum AddResult: RetryRequest {
        case success(staleVersionId:Int64)
        case duplicateEntry
        case aModelValueWasNil
        case otherError(String)
        
        case deadlock
        case waitTimeout
        
        var shouldRetry: Bool {
            if case .deadlock = self {
                return true
            }
            if case .waitTimeout = self {
                return true
            }
            else {
                return false
            }
        }
    }
    
    // staleVersionId in the model is ignored and the automatically generated staleVersionId is returned if the add is successful. On success, the record is modified with this staleVersionId.
    func add(staleVersion:StaleVersion) -> AddResult {
        if basicFieldCheck(staleVersion: staleVersion) {
            Log.error("One of the model values was nil!")
            return .aModelValueWasNil
        }
        
        let insert = Database.PreparedStatement(repo: self, type: .insert)

        insert.add(fieldName: StaleVersion.fileIndexIdKey, value: .int64(staleVersion.fileIndexId))
        insert.add(fieldName: StaleVersion.fileUUIDKey, value: .string(staleVersion.fileUUID))
        insert.add(fieldName: StaleVersion.sharingGroupUUIDKey, value: .string(staleVersion.sharingGroupUUID))
        insert.add(fieldName: StaleVersion.fileVersionKey, value: .int32(staleVersion.fileVersion))
        
        if let expiryDate = staleVersion.expiryDate {
            let expiryDateValue = DateExtras.date(expiryDate, toFormat: .DATETIME)
            insert.add(fieldName: StaleVersion.expiryDateKey, value: .string(expiryDateValue))
        }

        do {
            try insert.run()
            Log.info("Sucessfully created StaleVersion row")
            let staleVersionId = db.lastInsertId()
            staleVersion.staleVersionId = staleVersionId
            return .success(staleVersionId: staleVersionId)
        }
        catch (let error) {
            Log.info("Failed inserting StaleVersion row: \(db.errorCode()); \(db.errorMessage())")
            
            if db.errorCode() == Database.deadlockError {
                return .deadlock
            }
            else if db.errorCode() == Database.lockWaitTimeout {
                return .waitTimeout
            }
            else if db.errorCode() == Database.duplicateEntryForKey {
                return .duplicateEntry
            }
            else {
                let message = "Could not insert into \(tableName): \(error)"
                Log.error(message)
                return .otherError(message)
            }
        }
    }
    
    enum LookupKey : CustomStringConvertible {
        case uuids(fileUUID:String, sharingGroupUUID: String, fileVersion: FileVersionInt)
        case needingDeletion
        
        var description : String {
            switch self {
            case .uuids(let fileUUID, let sharingGroupUUID, let fileVersion):
                return "uuids(fileUUID: \(fileUUID); sharingGroupUUID: \(sharingGroupUUID); fileVersion: \(fileVersion)"
            case .needingDeletion:
                return "needingDeletion"
            }
        }
    }
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .uuids(let fileUUID, let sharingGroupUUID, let fileVersion):
            return "fileUUID = '\(fileUUID)' && sharingGroupUUID = '\(sharingGroupUUID)' && fileVersion = \(fileVersion)"
        case .needingDeletion:
            let staleDateString = DateExtras.date(Date(), toFormat: .DATETIME)
            return "expiryDate < '\(staleDateString)'"
        }
    }
}
