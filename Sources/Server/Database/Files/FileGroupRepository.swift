//
//  FileGroupRepository.swift
//  Server
//
//  Created by Christopher G Prince on 7/3/21.
//

import Foundation
import ServerShared
import LoggerAPI

// See https://github.com/SyncServerII/Neebla/issues/23#issuecomment-873467928 for why I finally had to add this table.

class FileGroups : NSObject, Model {
    static let fileGroupIdKey = "fileGroupId"
    var fileGroupId: Int64!
    
    static let fileGroupUUIDKey = "fileGroupUUID"
    var fileGroupUUID: String!
    
    static let objectTypeKey = "objectType"
    var objectType:String!
    
    // Currently allowing files to be in exactly one sharing group.
    static let sharingGroupUUIDKey = "sharingGroupUUID"
    var sharingGroupUUID: String!
    
    // The user that created & uploaded the file group, the first time.
    static let userIdKey = "userId"
    var userId: UserId!
    
    // Only when the current user (identified by the userId) is a sharing user, this gives the userId that is the owner of the data for this file group.
    static let owningUserIdKey = "owningUserId"
    var owningUserId:UserId?
    
    subscript(key:String) -> Any? {
        set {
            switch key {
            case Self.fileGroupIdKey:
                fileGroupId = newValue as? Int64
                
            case Self.fileGroupUUIDKey:
                fileGroupUUID = newValue as? String
                
            case Self.objectTypeKey:
                objectType = newValue as? String
 
             case Self.sharingGroupUUIDKey:
                sharingGroupUUID = newValue as? String
                
            case Self.userIdKey:
                userId = newValue as? UserId
                
            case Self.owningUserIdKey:
                owningUserId = newValue as? UserId
                
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
}

class FileGroupRepository : Repository, RepositoryLookup, ModelIndexId {
    static var indexIdKey = FileGroups.fileGroupIdKey
    
    private(set) var db:Database!
    
    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return Self.tableName
    }
    
    static var tableName:String {
        return "FileGroup"
    }

    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "( " +
            
            "fileGroupId BIGINT NOT NULL AUTO_INCREMENT, " +
                        
            "fileGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            "objectType VARCHAR(\(FileGroup.maxLengthObjectTypeName)) NOT NULL, " +
            
            "sharingGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
                                    
            "userId BIGINT NOT NULL, " +
            
            "owningUserId BIGINT, " +

            "UNIQUE (fileGroupUUID), " +
            
            "UNIQUE (fileGroupId)" +
            
            ")"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        switch result {
        case .success(.alreadyPresent):
            break
            
        case .success:
            break
            
        case .failure(let error):
            Log.error("Failed creating table: \(error)")
        }
        
        return result
    }
    
    private func haveNilFieldForAdd(model:FileGroups) -> Bool {
        return model.fileGroupUUID == nil
            || model.objectType == nil
            || model.sharingGroupUUID == nil
            || model.userId == nil
    }
    
    // On success, returns the new `fileGroupId` value.
    func add(model:FileGroups) -> Int64? {
        if haveNilFieldForAdd(model: model) {
            Log.error("One of the model values was nil: \(model)")
            return nil
        }
        
        let insert = Database.PreparedStatement(repo: self, type: .insert)

        insert.add(fieldName: FileGroups.fileGroupUUIDKey, value: .string(model.fileGroupUUID))
        insert.add(fieldName: FileGroups.userIdKey, value: .int64(model.userId))
        insert.add(fieldName: FileGroups.objectTypeKey, value: .string(model.objectType))
        insert.add(fieldName: FileGroups.sharingGroupUUIDKey, value: .string(model.sharingGroupUUID))
        
        insert.add(fieldName: FileGroups.owningUserIdKey, value: .int64Optional(model.owningUserId))
        
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

    enum LookupKey : CustomStringConvertible {
        case fileGroupId(Int64)
        case fileGroupUUID(fileGroupUUID: String)
        
        var description : String {
            switch self {
            case .fileGroupId(let id):
                return "fileGroupId(\(id))"
            case .fileGroupUUID(let fileGroupUUID):
                return "fileGroupUUID(\(fileGroupUUID))"
            }
        }
    }
        
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .fileGroupId(let id):
            return "fileGroupId = \(id)"
        case .fileGroupUUID(fileGroupUUID: let uuid):
            return "fileGroupUUID = '\(uuid)'"
        }
    }
}
