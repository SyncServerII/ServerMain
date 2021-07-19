//
//  SharingGroupUserRepository.swift
//  Server
//
//  Created by Christopher G Prince on 6/24/18.
//

// What users are in specific sharing groups?

import Foundation
import LoggerAPI
import ServerShared

typealias SharingGroupUserId = Int64

class SharingGroupUser : NSObject, Model {
    static let sharingGroupUserIdKey = "sharingGroupUserId"
    var sharingGroupUserId: SharingGroupUserId!
    
    // Each record in this table relates a sharing group...
    static let sharingGroupUUIDKey = "sharingGroupUUID"
    var sharingGroupUUID: String!
    
    // ... to a user.
    static let userIdKey = "userId"
    var userId: UserId!
    
    // Only when the current user (identified by the userId) is a sharing user, this gives the userId that is the owner of the data for this sharing group.
    static let owningUserIdKey = "owningUserId"
    var owningUserId:UserId?

    // The permissions that the user has in regards to the sharing group. The user can read (anyone's data), can upload (to their own or others storage), and invite others to join the group.
    static let permissionKey = "permission"
    var permission:Permission?
    
    // When a user is removed from a sharing group, we don't actually remove the row from the table. That leads to client difficulties-- see https://github.com/SyncServerII/Neebla/issues/12
    // Instead, we're marking the row as deleted.
    static let deletedKey = "deleted"
    var deleted:Bool!

    subscript(key:String) -> Any? {
        set {
            switch key {
            case SharingGroupUser.sharingGroupUserIdKey:
                sharingGroupUserId = newValue as! SharingGroupUserId?
            
            case SharingGroupUser.userIdKey:
                userId = newValue as! UserId?
                
            case SharingGroupUser.sharingGroupUUIDKey:
                sharingGroupUUID = newValue as! String?
                
            case SharingGroupUser.permissionKey:
                permission = newValue as! Permission?
                
            case SharingGroupUser.owningUserIdKey:
                owningUserId = newValue as! UserId?

            case SharingGroupUser.deletedKey:
                deleted = newValue as? Bool
                
            default:
                Log.error("Did not find key: \(key)")
                assert(false)
            }
        }
        
        get {
            return getValue(forKey: key)
        }
    }
    
    func typeConvertersToModel(propertyName:String) -> ((_ propertyValue:Any) -> Any?)? {
        switch propertyName {
            case SharingGroupUser.deletedKey:
                return {(x:Any) -> Any? in
                    return (x as? Int8) == 1
                }
            case SharingGroupUser.permissionKey:
                return {(x:Any) -> Any? in
                    return Permission(rawValue: x as! String)
                }
            default:
                return nil
        }
    }
    
    required override init() {
        super.init()
    }
}

class SharingGroupUserRepository : Repository, RepositoryLookup {
    private(set) var db:Database!
    
    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return SharingGroupUserRepository.tableName
    }
    
    static var tableName:String {
        return "SharingGroupUser"
    }
    
    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "(sharingGroupUserId BIGINT NOT NULL AUTO_INCREMENT, " +
        
            "sharingGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            "userId BIGINT NOT NULL, " +
            
            // NULL for only owning users; sharing users must have non-NULL value.
            "owningUserId BIGINT, " +
            
            "permission VARCHAR(\(Permission.maxStringLength())), " +
            
            // true iff the user no longer has access to the sharing group.
            "deleted BOOL NOT NULL DEFAULT FALSE, " +

            "FOREIGN KEY (owningUserId) REFERENCES \(UserRepository.tableName)(\(User.userIdKey)), " +
            "FOREIGN KEY (userId) REFERENCES \(UserRepository.tableName)(\(User.userIdKey)), " +
            "FOREIGN KEY (sharingGroupUUID) REFERENCES \(SharingGroupRepository.tableName)(\(SharingGroup.sharingGroupUUIDKey)), " +

            "UNIQUE (sharingGroupUUID, userId), " +
            "UNIQUE (sharingGroupUserId))"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        
        switch result {
        case .success(.alreadyPresent):
            // Table was already there. Do we need to update it?
            // Evolution 1: Is the deleted column present?
            if db.columnExists(SharingGroupUser.deletedKey, in: tableName) == false {
                if !db.addColumn("\(SharingGroupUser.deletedKey) BOOL NOT NULL DEFAULT FALSE", to: tableName) {
                    return .failure(.columnCreation)
                }
            }
            
        default:
            break
        }
        
        return result
    }
    
    enum LookupKey : CustomStringConvertible {
        case sharingGroupUserId(SharingGroupUserId)
        
        // If deleted is nil, it's not used as a constraint.
        case primaryKeys(sharingGroupUUID: String, userId: UserId, deleted: Bool?)
        
        case userId(UserId)
        case sharingGroupUUID(String, deleted: Bool)
        case owningUserId(UserId)
        case owningUserAndSharingGroup(owningUserId: UserId, uuid: String)
        
        var description : String {
            switch self {
            case .sharingGroupUserId(let sharingGroupUserId):
                return "sharingGroupUserId(\(sharingGroupUserId))"
            case .primaryKeys(sharingGroupUUID: let sharingGroupUUID, userId: let userId, deleted: let deleted):
                return "primaryKeys(\(sharingGroupUUID), \(userId), \(String(describing: deleted))"
            case .userId(let userId):
                return "userId(\(userId))"
            case .sharingGroupUUID(let sharingGroupUUID, let deleted):
                return "sharingGroupUUID(\(sharingGroupUUID); deleted: \(deleted))"
            case .owningUserId(let owningUserId):
                return "owningUserId(\(owningUserId))"
            case .owningUserAndSharingGroup(owningUserId: let owningUserId, let sharingGroupUUID):
                return "owningUserId(\(owningUserId), \(sharingGroupUUID)"
            }
        }
    }
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .sharingGroupUserId(let sharingGroupUserId):
            return "sharingGroupUserId = \(sharingGroupUserId)"
        case .primaryKeys(sharingGroupUUID: let sharingGroupUUID, userId: let userId, deleted: let deleted):
            var deletedConstraint = ""
            if let deleted = deleted {
                deletedConstraint = "AND deleted = \(deleted)"
            }
            return "sharingGroupUUID = '\(sharingGroupUUID)' AND userId = \(userId) \(deletedConstraint)"
        case .userId(let userId):
            return "userId = \(userId)"
        case .sharingGroupUUID(let sharingGroupUUID, let deleted):
            return "sharingGroupUUID = '\(sharingGroupUUID)' AND deleted = \(deleted)"
        case .owningUserId(let owningUserId):
            return "owningUserId = \(owningUserId)"
        case .owningUserAndSharingGroup(owningUserId: let owningUserId, let sharingGroupUUID):
            return "owningUserId = \(owningUserId) AND sharingGroupUUID = '\(sharingGroupUUID)'"
        }
    }
    
    enum AddResult {
        case success(SharingGroupUserId)
        case error(String)
    }
    
    func add(sharingGroupUUID: String, userId: UserId, permission: Permission, owningUserId: UserId?) -> AddResult {
        let owningUserIdValue = owningUserId == nil ? "NULL" : "\(owningUserId!)"
        let query = "INSERT INTO \(tableName) (sharingGroupUUID, userId, permission, owningUserId) VALUES('\(sharingGroupUUID)', \(userId), '\(permission.rawValue)', \(owningUserIdValue));"
        
        if db.query(statement: query) {
            Log.info("Sucessfully created sharing user group")
            return .success(db.lastInsertId())
        }
        else {
            let error = db.error
            Log.error("Could not insert into \(tableName): \(error)")
            return .error(error)
        }
    }
    
    func reAdd(sharingGroupUUID: String, userId: UserId, with permission: Permission, owningUserId: UserId?) -> Bool {

        let owningUserIdValue = owningUserId == nil ? "NULL" : "\(owningUserId!)"
        
        let query = "UPDATE \(tableName) SET " +
            "permission = '\(permission.rawValue)', " +
            "owningUserId = \(owningUserIdValue), " +
            "deleted = false" +
            " WHERE " +
            "userId = \(userId) and sharingGroupUUID = '\(sharingGroupUUID)' "
        
        if db.query(statement: query) {
            Log.info("Sucessfully created sharing user group")
            return true
        }
        else {
            let error = db.error
            Log.error("Could not insert into \(tableName): \(error)")
            return false
        }
    }
    
    // includeRemovedUsers iff users that have been removed from the sharing group are included in result
    func sharingGroupUsers(forSharingGroupUUID sharingGroupUUID: String, includeRemovedUsers: Bool) -> [ServerShared.SharingGroupUser]? {
        guard let users: [User] = sharingGroupUsers(forSharingGroupUUID: sharingGroupUUID, includeRemovedUsers: includeRemovedUsers) else {
            return nil
        }
        
        let result = users.map { user -> ServerShared.SharingGroupUser in
            let sharingGroupUser = ServerShared.SharingGroupUser()
            sharingGroupUser.name = user.username
            sharingGroupUser.userId = user.userId
            sharingGroupUser.deleted = user.deleted
            return sharingGroupUser
        }
        
        return result
    }
    
    // includeRemovedUsers iff users that have been removed from the sharing group are included in result; returns nil on error
    func sharingGroupUsers(forSharingGroupUUID sharingGroupUUID: String, includeRemovedUsers: Bool) -> [User]? {
        
        var onlyCurrentUsers = ""
        if !includeRemovedUsers {
            onlyCurrentUsers = "and \(tableName).\(SharingGroupUser.deletedKey) = false"
        }
        
        let query = "select \(UserRepository.tableName).\(User.usernameKey),  \(UserRepository.tableName).\(User.userIdKey), \(UserRepository.tableName).\(User.pushNotificationTopicKey), \(tableName).\(SharingGroupUser.deletedKey) from \(tableName), \(UserRepository.tableName) where \(tableName).userId = \(UserRepository.tableName).userId and \(tableName).sharingGroupUUID = '\(sharingGroupUUID)' \(onlyCurrentUsers)"
        return sharingGroupUsers(forSelectQuery: query)
    }
    
    private func sharingGroupUsers(forSelectQuery selectQuery: String) -> [User]? {
        guard let select = Select(db:db, query: selectQuery, modelInit: User.init, ignoreErrors:false) else {
            Log.error("Failed on Select: query: \(selectQuery)")
            return nil
        }
        
        var result:[User] = []
        
        select.forEachRow { rowModel in
            let rowModel = rowModel as! User
            result.append(rowModel)
        }
        
        if select.forEachRowStatus == nil {
            return result
        }
        else {
            Log.error("Failed on forEachRowStatus: \(select.forEachRowStatus!)")
            return nil
        }
    }
    
    // To deal with deleting a user account-- any other users that have its user id as their owningUserId must have that owningUserId set to NULL. Don't just remove the invited/sharing user from SharingGroupUsers-- why not let them still download from the sharing group?
    func resetOwningUserIds(key: LookupKey) -> Bool {
        let query = "UPDATE \(tableName) SET owningUserId = NULL WHERE " + lookupConstraint(key: key)
        
        if db.query(statement: query) {
            let numberUpdates = db.numberAffectedRows()
            Log.info("\(numberUpdates) users had their owningUserId set to NULL.")
            return true
        }
        else {
            let error = db.error
            Log.error("Could not update row(s) for \(tableName): \(error)")
            return false
        }
    }
}

