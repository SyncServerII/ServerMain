//
//  FileIndexClientUIRepository.swift
//  Server
//
//  Created by Christopher G Prince on 5/28/21.
//

// Which changes to files need to be marked in the client UI as downloadable?
// See https://github.com/SyncServerII/Neebla/issues/15

import Foundation
import ServerShared
import LoggerAPI

class FileIndexClientUI : NSObject, Model {
    static let fileIndexClientUIIdKey = "fileIndexClientUIId"
    var fileIndexClientUIId: Int64!
    
    static let fileUUIDKey = "fileUUID"
    var fileUUID: String!
    
    static let sharingGroupUUIDKey = "sharingGroupUUID"
    var sharingGroupUUID: String!
    
    static let fileVersionKey = "fileVersion"
    var fileVersion: FileVersionInt!
    
    static let informAllButUserIdKey = "informAllButUserId"
    var informAllButUserId: UserId!
    
    static let expiryKey = "expiry"
    var expiry:Date!
    
    // Deprecated, but needed for migration
    static let fileGroupUUIDKey = "fileGroupUUID"
    
    subscript(key:String) -> Any? {
        set {
            switch key {
            case Self.fileIndexClientUIIdKey:
                fileIndexClientUIId = newValue as? Int64
                
            case Self.fileUUIDKey:
                fileUUID = newValue as? String
                
            case Self.sharingGroupUUIDKey:
                sharingGroupUUID = newValue as? String
                
            case Self.fileVersionKey:
                fileVersion = newValue as? FileVersionInt
                
            case Self.informAllButUserIdKey:
                informAllButUserId = newValue as? UserId
                
            case Self.expiryKey:
                expiry = newValue as? Date
                
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
        case Self.expiryKey:
            return {(x:Any) -> Any? in
                return DateExtras.date(x as! String, fromFormat: .DATETIME)
            }
        
        default:
            return nil
        }
    }
}

class FileIndexClientUIRepository : Repository, RepositoryLookup, ModelIndexId {
    static var indexIdKey = FileIndexClientUI.fileIndexClientUIIdKey
    
    private(set) var db:Database!
    
    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return Self.tableName
    }
    
    static var tableName:String {
        return "FileIndexClientUI"
    }

    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "( " +
            
            "fileIndexClientUIId BIGINT NOT NULL AUTO_INCREMENT, " +
                        
            "fileUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            // There is no need to store a field with the `fileGroupUUID` here. We can join to the FileIndex and get that.
            
            "sharingGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            "fileVersion INT NOT NULL, " +
            
            // This version (change) needs to be presented to all users but this userId.
            "informAllButUserId BIGINT NOT NULL, " +
            
            "expiry DATETIME NOT NULL, " +

            // We can have multiple records for a given file version in a sharing group-- but the `informAllButUserId` field must make them unique. This is to accomodate vN uploads where multiple Uploads records create a new file version. And these uploads originate from different (informAllButUserId) users. This is the expected case in this situation: E.g., Rod and Dany make a comment at the same time and both of those uploads combine to form the new file version. NOTE: Client side we need to deal with this possibility: That we can have multiple inform records with the same file version. If at least one of them indicates that self should be informed we have to inform self.
            "UNIQUE (fileUUID, sharingGroupUUID, fileVersion, informAllButUserId), " +
            
            "UNIQUE (fileIndexClientUIId)" +
            
            ")"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        switch result {
        case .success(.alreadyPresent):
            // Migration
            if db.columnExists(FileIndexClientUI.fileGroupUUIDKey, in: tableName) == true {
                if !db.removeColumn(FileIndexClientUI.fileGroupUUIDKey, from: tableName) {
                    return .failure(.columnRemoval)
                }
            }
            
        case .success:
            break
            
        case .failure(let error):
            Log.error("Failed creating table: \(error)")
        }
        
        return result
    }
    
    private func haveNilFieldForAdd(model:FileIndexClientUI) -> Bool {
        return model.fileUUID == nil
            || model.sharingGroupUUID == nil
            || model.fileVersion == nil
            || model.informAllButUserId == nil
            || model.expiry == nil
    }
    
    // On success, returns the new `fileIndexClientUIId` value.
    func add(model:FileIndexClientUI) -> Int64? {
        if haveNilFieldForAdd(model: model) {
            Log.error("One of the model values was nil: \(model)")
            return nil
        }
        
        let insert = Database.PreparedStatement(repo: self, type: .insert)

        insert.add(fieldName: FileIndexClientUI.fileUUIDKey, value: .stringOptional(model.fileUUID))
        insert.add(fieldName: FileIndexClientUI.sharingGroupUUIDKey, value: .stringOptional(model.sharingGroupUUID))
        insert.add(fieldName: FileIndexClientUI.fileVersionKey, value: .int32Optional(model.fileVersion))
        insert.add(fieldName: FileIndexClientUI.informAllButUserIdKey, value: .int64Optional(model.informAllButUserId))

        guard let expiry = model.expiry else {
            return nil
        }
        
        let expiryValue = DateExtras.date(expiry, toFormat: .DATETIME)
        insert.add(fieldName: FileIndexClientUI.expiryKey, value: .string(expiryValue))
        
        do {
            try insert.run()
            Log.info("Sucessfully added \(tableName) row")
            return db.lastInsertId()
        }
        catch let error {
            Log.error("Failed adding \(tableName) row: \(db.errorCode()); \(db.errorMessage()); error: \(error)")
            return nil
        }
    }
    
    enum AddIfNeededResult {
        case error
        case notNeeded
        case success(id: Int64)
    }
    
    func addIfNeeded(from upload: Upload) -> AddIfNeededResult {
        guard let informAllButUserId = upload.informAllButUserId else {
            return .notNeeded
        }
        
        let model = FileIndexClientUI()
        model.fileUUID = upload.fileUUID
        model.sharingGroupUUID = upload.sharingGroupUUID
        model.fileVersion = upload.fileVersion
        model.informAllButUserId = informAllButUserId
        
        Log.debug("addIfNeeded: upload.fileUUID: \(String(describing: upload.fileUUID)); upload.sharingGroupUUID: \(String(describing: upload.sharingGroupUUID)); upload.fileVersion: \(String(describing: upload.fileVersion))")
        
        let calendar = Calendar.current
        guard let expiryDate = calendar.date(byAdding: .day, value: ServerConstants.numberOfDaysUntilInformAllButSelfExpiry, to: Date()) else {
            return .error
        }

        model.expiry = expiryDate

        guard let id = add(model: model) else {
            return .error
        }
        
        return .success(id: id)
    }
    
    func removeExpiredRecords() -> Bool {
        let removalKey = FileIndexClientUIRepository.LookupKey.staleExpiryDates

        let removalResult = retry {
            return self.remove(key: removalKey)
        }
        
        guard case .removed(_) = removalResult else {
            Log.error("Failed removing stale FileIndexClientUI records")
            return false
        }
        
        return true
    }

    enum LookupKey : CustomStringConvertible {
        case fileIndexClientUIId(Int64)
        case sharingGroup(sharingGroupUUID: String)
        case staleExpiryDates
        
        var description : String {
            switch self {
            case .fileIndexClientUIId(let id):
                return "fileIndexClientUIId(\(id))"
            case .sharingGroup(let sharingGroupUUID):
                return "sharingGroup(\(sharingGroupUUID))"
            case .staleExpiryDates:
                return "staleExpiryDates"
            }
        }
    }
    
    let dateFormat = DateExtras.DateFormat.DATETIME
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .fileIndexClientUIId(let id):
            return "fileIndexClientUIId = \(id)"
        case .sharingGroup(sharingGroupUUID: let uuid):
            return "sharingGroupUUID = '\(uuid)'"
        case .staleExpiryDates:
            let staleDateString = DateExtras.date(Date(), toFormat: dateFormat)
            return "expiry < '\(staleDateString)'"
        }
    }
}
