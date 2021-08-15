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
// Due to a naming conflict, this is called `FileGroupModel` and not `FileGroup`.

class FileGroupModel : NSObject, Model {
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
    
    // If the user has cloud storage, this will be the same as `userId`. If the user doesn't have cloud storage, it will be the user that sponsored the cloud storage for the social user.
    static let owningUserIdKey = "owningUserId"
    var owningUserId:UserId!
    
    // When "deleted", file groups are not fully removed from the system. Their files are not removed from cloud storage; the file group is just marked as deleted.
    static let deletedKey = "deleted"
    var deleted:Bool!
    
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
                
            case Self.deletedKey:
                deleted = newValue as? Bool
                
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
            case FileGroupModel.deletedKey:
                return {(x:Any) -> Any? in
                    return (x as? Int8) == 1
                }
            
            default:
                return nil
        }
    }
}

class FileGroupRepository : Repository, RepositoryLookup, ModelIndexId {
    static var indexIdKey = FileGroupModel.fileGroupIdKey
    
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
            
            // Not letting this field be NULL as a convenience. It's considerably easier for joins and other access to *always* have a known field that is the owning user id.
            "owningUserId BIGINT NOT NULL, " +
            
            // true iff file group has been marked as deleted.
            "deleted BOOL NOT NULL DEFAULT FALSE, " +

            "UNIQUE (fileGroupUUID), " +
            
            "UNIQUE (fileGroupId)" +
            
            ")"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        switch result {
        case .success(.alreadyPresent):
            if db.columnExists(FileGroupModel.deletedKey, in: tableName) == false {
                if !db.addColumn("\(FileGroupModel.deletedKey) BOOL NOT NULL DEFAULT FALSE", to: tableName) {
                    return .failure(.columnCreation)
                }
            }
            
        case .success:
            break
            
        case .failure(let error):
            Log.error("Failed creating table: \(error)")
        }
        
        return result
    }
    
    private func haveNilFieldForAdd(model:FileGroupModel) -> Bool {
        return model.fileGroupUUID == nil
            || model.objectType == nil
            || model.sharingGroupUUID == nil
            || model.userId == nil
            || model.owningUserId == nil
            || model.deleted == nil
    }
    
    // On success, returns the new `fileGroupId` value.
    func add(model:FileGroupModel) -> Int64? {
        if haveNilFieldForAdd(model: model) {
            Log.error("One of the model values was nil: \(model)")
            return nil
        }
        
        let insert = Database.PreparedStatement(repo: self, type: .insert)

        insert.add(fieldName: FileGroupModel.fileGroupUUIDKey, value: .string(model.fileGroupUUID))
        insert.add(fieldName: FileGroupModel.userIdKey, value: .int64(model.userId))
        insert.add(fieldName: FileGroupModel.objectTypeKey, value: .string(model.objectType))
        insert.add(fieldName: FileGroupModel.sharingGroupUUIDKey, value: .string(model.sharingGroupUUID))
        insert.add(fieldName: FileGroupModel.deletedKey, value: .bool(model.deleted))
        
        insert.add(fieldName: FileGroupModel.owningUserIdKey, value: .int64Optional(model.owningUserId))
        
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
        case sharingGroupUUID(sharingGroupUUID: String)
        case userIdAndSharingGroup(userId: UserId, sharingGroupUUID: String)
        case userId(userId: UserId)
        
        var description : String {
            switch self {
            case .fileGroupId(let id):
                return "fileGroupId(\(id))"
            case .fileGroupUUID(let fileGroupUUID):
                return "fileGroupUUID(\(fileGroupUUID))"
            case .sharingGroupUUID(let sharingGroupUUID):
                return "sharingGroupUUID(\(sharingGroupUUID))"
            case .userIdAndSharingGroup(let userId, let sharingGroupUUID):
                return "userId(\(userId)); sharingGroupUUID(\(sharingGroupUUID))"
            case .userId(let userId):
                return "userId(\(userId))"
            }
        }
    }
        
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .fileGroupId(let id):
            return "fileGroupId = \(id)"
        case .fileGroupUUID(fileGroupUUID: let uuid):
            return "fileGroupUUID = '\(uuid)'"
        case .sharingGroupUUID(sharingGroupUUID: let uuid):
            return "sharingGroupUUID = '\(uuid)'"
        case .userIdAndSharingGroup(let userId, let sharingGroupUUID):
            return "userId = \(userId) and sharingGroupUUID = '\(sharingGroupUUID)'"
        case .userId(let userId):
            return "userId = \(userId)"
        }
    }
}

extension FileGroupRepository {
    enum FileGroupRepositoryError: Error {
        case failedFileGroupLookup
    }
    
    func getFileGroup(forFileGroupUUID fileGroupUUID: String) throws -> FileGroupModel {
        let fileGroupKey = Self.LookupKey.fileGroupUUID(fileGroupUUID: fileGroupUUID)
        guard let fileGroups = lookupAll(key: fileGroupKey, modelInit: FileGroupModel.init),
            fileGroups.count == 1 else {
            throw FileGroupRepositoryError.failedFileGroupLookup
        }
        
        return fileGroups[0]
    }
    
    func updateFileGroups(_ fileGroupUUIDs: [String], sourceSharingGroupUUID: String, destinationSharingGroupUUID: String) -> Bool {
    
        guard fileGroupUUIDs.count > 0 else {
            return false
        }
        
        let fileGroups = fileGroupUUIDs.map { "'\($0)'" }.joined(separator: ", ")

        let query = """
            UPDATE \(tableName)
            SET
                sharingGroupUUID = '\(destinationSharingGroupUUID)'
            WHERE
                sharingGroupUUID = '\(sourceSharingGroupUUID)'
            and
                fileGroupUUID in (\(fileGroups))
            and deleted = 0
        """
        
        if db.query(statement: query) {
            guard fileGroupUUIDs.count == db.numberAffectedRows() else {
            Log.error("Did not have <= \(fileGroupUUIDs.count) row updated: \(db.numberAffectedRows())")
                return false
            }
            return true
        }
        else {
            let error = db.error
            Log.error("Could not update \(tableName): \(error)")
            return false
        }
    }
    
    // Returns nil on error; number of rows marked otherwise.
    // 8/5/20: Just added the "and \(FileGroupModel.deletedKey) = 0"-- which should ensure that the update can not occur twice, successfully, in a race.
    func markAsDeleted(key:LookupKey) -> Int64? {
        let query = "UPDATE \(tableName) SET \(FileGroupModel.deletedKey) = 1 WHERE " + lookupConstraint(key: key) + " and \(FileGroupModel.deletedKey) = 0"
        if db.query(statement: query) {
            let numberRows = db.numberAffectedRows()
            Log.debug("Number rows: \(numberRows) for query: \(query)")
            return numberRows
        }
        else {
            let error = db.error
            Log.error("Could not mark file group(s) as deleted in \(tableName): \(error)")
            return nil
        }
    }
}
