//
//  FileIndexRepository.swift
//  Server
//
//  Created by Christopher Prince on 1/21/17.
//
//

// Meta data for files currently in cloud storage.

import Foundation
import LoggerAPI
import ServerShared
import ChangeResolvers
import ServerAccount

typealias FileIndexId = Int64

class FileIndex : NSObject, Model {
    
    static let fileIndexIdKey = "fileIndexId"
    var fileIndexId: FileIndexId!
    
    static let fileUUIDKey = "fileUUID"
    var fileUUID: String!
    
    static let deviceUUIDKey = "deviceUUID"
    var deviceUUID:String!
    
    // Reference into FileGroup table.
    static let fileGroupUUIDKey = "fileGroupUUID"
    // As of https://github.com/SyncServerII/Neebla/issues/23, all files have to be associated with a file group.
    var fileGroupUUID:String!
    
    static let creationDateKey = "creationDate"
    // We don't give the `creationDate` when updating the fileIndex for versions > 0.
    var creationDate:Date?
    
    static let updateDateKey = "updateDate"
    var updateDate:Date!
    
    static let mimeTypeKey = "mimeType"
    var mimeType: String!
    
    // Nil only if files are static and changes cannot be applied.
    static let changeResolverNameKey = "changeResolverName"
    var changeResolverName: String?
    
    static let appMetaDataKey = "appMetaData"
    var appMetaData: String?
    
    // When "deleted" files are not fully removed from the system. They are removed from cloud storage, but just marked as deleted in the FileIndex. This effectively also marks the containing file group as deleted.
    static let deletedKey = "deleted"
    var deleted:Bool!
    
    static let fileVersionKey = "fileVersion"
    var fileVersion: FileVersionInt!
    
    static let lastUploadedCheckSumKey = "lastUploadedCheckSum"
    var lastUploadedCheckSum: String?

    static let fileLabelKey = "fileLabel"
    var fileLabel: String!
    
    // MARK: For queries; not in this table.
    
    static let accountTypeKey = "accountType"
    var accountType: String!
    
    static let querySharingGroupUUIDKey = "sharingGroupUUID"
    var querySharingGroupUUID: String!
    
    static let queryOwningUserIdKey = "owningUserId"
    var queryOwningUserId: UserId!
    
    static let queryObjectTypeKey = "objectType"
    var queryObjectType:String?
    
    subscript(key:String) -> Any? {
        set {
            switch key {
            case FileIndex.fileIndexIdKey:
                fileIndexId = newValue as! FileIndexId?

            case FileIndex.fileUUIDKey:
                fileUUID = newValue as! String?

            case FileIndex.fileGroupUUIDKey:
                fileGroupUUID = newValue as! String?

            case FileIndex.queryObjectTypeKey:
                queryObjectType = newValue as? String
                
            case FileIndex.querySharingGroupUUIDKey:
                querySharingGroupUUID = newValue as! String?
                
            case FileIndex.deviceUUIDKey:
                deviceUUID = newValue as! String?
                
            case FileIndex.creationDateKey:
                creationDate = newValue as! Date?

            case FileIndex.updateDateKey:
                updateDate = newValue as! Date?
                
            case FileIndex.queryOwningUserIdKey:
                queryOwningUserId = newValue as! UserId?
                
            case FileIndex.mimeTypeKey:
                mimeType = newValue as! String?
                
            case FileIndex.appMetaDataKey:
                appMetaData = newValue as! String?
            
            case FileIndex.deletedKey:
                deleted = newValue as! Bool?
                
            case FileIndex.fileVersionKey:
                fileVersion = newValue as! FileVersionInt?
                
            case FileIndex.lastUploadedCheckSumKey:
                lastUploadedCheckSum = newValue as! String?
                
            case FileIndex.changeResolverNameKey:
                changeResolverName = newValue as? String

            case FileIndex.fileLabelKey:
                fileLabel = newValue as? String
                
            case User.accountTypeKey:
                accountType = newValue as! String?
                
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
            case FileIndex.deletedKey:
                return {(x:Any) -> Any? in
                    return (x as! Int8) == 1
                }
            
            case FileIndex.creationDateKey:
                return {(x:Any) -> Any? in
                    return DateExtras.date(x as! String, fromFormat: .DATETIME)
                }

            case FileIndex.updateDateKey:
                return {(x:Any) -> Any? in
                    return DateExtras.date(x as! String, fromFormat: .DATETIME)
                }
            
            default:
                return nil
        }
    }
    
    override var description : String {
        return "fileIndexId: \(String(describing: fileIndexId)); fileUUID: \(String(describing: fileUUID)); deviceUUID: \(deviceUUID ?? ""); creationDate: \(String(describing: creationDate)); updateDate: \(String(describing: updateDate)); mimeTypeKey: \(String(describing: mimeType)); appMetaData: \(String(describing: appMetaData)); deleted: \(String(describing: deleted)); fileVersion: \(String(describing: fileVersion)); lastUploadedCheckSum: \(String(describing: lastUploadedCheckSum))"
    }
}

class FileIndexRepository : Repository, RepositoryLookup, ModelIndexId {
    static let indexIdKey = FileIndex.fileIndexIdKey
    
    enum Errors: Swift.Error {
        case couldNotLookupFileUUID
    }

    private(set) var db:Database!
    
    required init(_ db:Database) {
        self.db = db
    }
    
    var tableName:String {
        return FileIndexRepository.tableName
    }
    
    static var tableName:String {
        return "FileIndex"
    }
    
    static let uniqueFileLabelConstraintName = "UniqueFileLabel"
    static let uniqueFileLabelConstraint = "UNIQUE (fileGroupUUID, fileLabel)"
    
    func upcreate() -> Database.TableUpcreateResult {
        let createColumns =
            "(fileIndexId BIGINT NOT NULL AUTO_INCREMENT, " +
                        
            // permanent reference to file (assigned by app)
            "fileUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            // identifies a specific mobile device (assigned by app)
            // This plays a different role than it did in the Upload table. Here, it forms part of the filename in cloud storage, and thus must be retained. We will ignore this field otherwise, i.e., we will not have two entries in this table for the same userId, fileUUID pair.
            "deviceUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +
            
            // Identifies a group of files (assigned by app).
            // Reference to FileGroup table.
            "fileGroupUUID VARCHAR(\(Database.uuidLength)) NOT NULL, " +

            // Not saying "NOT NULL" here only because in the first deployed version of the database, I didn't have these dates.
            "creationDate DATETIME," +
            "updateDate DATETIME," +

            // MIME type of the file
            "mimeType VARCHAR(\(Database.maxMimeTypeLength)) NOT NULL, " +

            // App-specific meta data
            "appMetaData TEXT, " +

            "fileLabel VARCHAR(\(FileLabel.maxLength)) NOT NULL, " +
            
            // true if file has been deleted, false if not.
            "deleted BOOL NOT NULL, " +
            
            "fileVersion INT NOT NULL, " +

            // I've left this as NULL-able for now to deal with migration-- systems in production prior to 10/27/18. In general, this should not be null.
            "lastUploadedCheckSum TEXT, " +
            
            "changeResolverName VARCHAR(\(ChangeResolverConstants.maxChangeResolverNameLength)), " +

            // Because file label's must be unique within file group's.
            "CONSTRAINT \(Self.uniqueFileLabelConstraintName) \(Self.uniqueFileLabelConstraint), " +

            // I used to have a constraint for fileUUID's to be unique within sharing groups. I no longer have a sharing group UUID in this table though. So just make them unique now within file group UUID.
            "UNIQUE (fileUUID, fileGroupUUID), " +

            "UNIQUE (fileIndexId))"
        
        let result = db.createTableIfNeeded(tableName: "\(tableName)", columnCreateQuery: createColumns)
        switch result {
        case .success(.alreadyPresent):
            // Table was already there. Do we need to update it?
            // Evolution 1: Are creationDate and updateDate present? If not, add them.
            if db.columnExists(Upload.creationDateKey, in: tableName) == false {
                if !db.addColumn("\(Upload.creationDateKey) DATETIME", to: tableName) {
                    return .failure(.columnCreation)
                }
            }
            if db.columnExists(Upload.updateDateKey, in: tableName) == false {
                if !db.addColumn("\(Upload.updateDateKey) DATETIME", to: tableName) {
                    return .failure(.columnCreation)
                }
            }
            
            // 2/25/18; Evolution 2: Remove the cloudFolderName column
            let cloudFolderNameKey = "cloudFolderName"
            if db.columnExists(cloudFolderNameKey, in: tableName) == true {
                if !db.removeColumn(cloudFolderNameKey, from: tableName) {
                    return .failure(.columnRemoval)
                }
            }
            
            // 4/19/18; Evolution 4: Add in fileGroupUUID
            if db.columnExists(FileIndex.fileGroupUUIDKey, in: tableName) == false {
                if !db.addColumn("\(FileIndex.fileGroupUUIDKey) VARCHAR(\(Database.uuidLength))", to: tableName) {
                    return .failure(.columnCreation)
                }
            }
            
            // 7/15/20; Evolution 5
            if db.columnExists(FileIndex.changeResolverNameKey, in: tableName) == false {
                if !db.addColumn("\(FileIndex.changeResolverNameKey) VARCHAR(\(ChangeResolverConstants.maxChangeResolverNameLength))", to: tableName) {
                    return .failure(.columnCreation)
                }
            }

            if db.columnExists(FileIndex.fileLabelKey, in: tableName) == false {
                if !db.addColumn("\(FileIndex.fileLabelKey) VARCHAR(\(FileLabel.maxLength))", to: tableName) {
                    return .failure(.columnCreation)
                }
            }

            if db.namedConstraintExists(Self.uniqueFileLabelConstraintName, in: tableName) == false {
                if !db.createConstraint(constraint:
                    "\(Self.uniqueFileLabelConstraintName) \(Self.uniqueFileLabelConstraint)", tableName: tableName) {
                    return .failure(.constraintCreation)
                }
            }
            
        default:
            break
        }
        
        return result
    }
    
    private func haveNilFieldForAdd(fileIndex:FileIndex) -> Bool {
        return fileIndex.fileUUID == nil || fileIndex.mimeType == nil || fileIndex.deviceUUID == nil || fileIndex.deleted == nil || fileIndex.fileVersion == nil || fileIndex.lastUploadedCheckSum == nil || fileIndex.creationDate == nil || fileIndex.fileLabel == nil || fileIndex.fileGroupUUID == nil
        // Not including `updateDate` here: It should be nil in a record creation as we're not updating we're creating.
    }
    
    enum AddFileIndexResponse: RetryRequest {
        case success(uploadId: Int64)
        case error
        case deadlock
        
        var shouldRetry: Bool {
            if case .deadlock = self {
                return true
            }
            else {
                return false
            }
        }
    }
    
    // uploadId in the model is ignored and the automatically generated uploadId is returned if the add is successful.
    func add(fileIndex:FileIndex) -> AddFileIndexResponse {
        if haveNilFieldForAdd(fileIndex: fileIndex) {
            Log.error("One of the model values was nil: \(fileIndex)")
            return .error
        }
        
        let insert = Database.PreparedStatement(repo: self, type: .insert)

        insert.add(fieldName: FileIndex.fileVersionKey, value: .int32Optional(fileIndex.fileVersion))
        
        insert.add(fieldName: FileIndex.deletedKey, value: .boolOptional(fileIndex.deleted))

        insert.add(fieldName: FileIndex.fileGroupUUIDKey, value: .string(fileIndex.fileGroupUUID))
        
        insert.add(fieldName: FileIndex.appMetaDataKey, value: .stringOptional(fileIndex.appMetaData))
        insert.add(fieldName: FileIndex.fileUUIDKey, value: .stringOptional(fileIndex.fileUUID))
        insert.add(fieldName: FileIndex.deviceUUIDKey, value: .stringOptional(fileIndex.deviceUUID))
        insert.add(fieldName: FileIndex.mimeTypeKey, value: .stringOptional(fileIndex.mimeType))
        insert.add(fieldName: FileIndex.lastUploadedCheckSumKey, value: .stringOptional(fileIndex.lastUploadedCheckSum))
        insert.add(fieldName: FileIndex.changeResolverNameKey, value: .stringOptional(fileIndex.changeResolverName))

        if let creationDate = fileIndex.creationDate {
            let creationDateValue = DateExtras.date(creationDate, toFormat: .DATETIME)
            insert.add(fieldName: FileIndex.creationDateKey, value: .string(creationDateValue))
        }
        
        if let updateDate = fileIndex.updateDate {
            let updateDateValue = DateExtras.date(updateDate, toFormat: .DATETIME)
            insert.add(fieldName: FileIndex.updateDateKey, value: .string(updateDateValue))
        }
        
        insert.add(fieldName: FileIndex.fileLabelKey, value: .stringOptional(fileIndex.fileLabel))
        
        do {
            try insert.run()
            Log.info("Sucessfully created \(tableName) row")
            return .success(uploadId: db.lastInsertId())
        }
        catch (let error) {
            Log.info("Failed inserting \(tableName) row: \(db.errorCode()); \(db.errorMessage())")
            
            if db.errorCode() == Database.deadlockError {
                return .deadlock
            }
            else {
                let message = "Could not insert into \(tableName): \(error)"
                Log.error(message)
                return .error
            }
        }
    }
    
    private func haveNilFieldForUpdate(fileIndex:FileIndex, updateType: UpdateType) -> Bool {
        // OWNER
        // Allowing a nil userId for update because the v0 owner of a file is always the owner of the file. i.e., for v1, v2 etc. of a file, we don't update the userId.
        let result = fileIndex.fileUUID == nil || fileIndex.deleted == nil
        
        switch updateType {
        case .uploadDeletion:
            return result || fileIndex.fileVersion == nil
            
        case .uploadAppMetaData:
            return result
            
        case .uploadFile:
            return result || fileIndex.fileVersion == nil || fileIndex.deviceUUID == nil
        }
    }
    
    enum UpdateType {
        case uploadFile
        case uploadDeletion
        
        // DEPRECATED
        case uploadAppMetaData
    }
    
    // The FileIndex model *must* have a fileIndexId
    // OWNER: userId is ignored in the fileIndex-- the v0 owner is the permanent owner.
    func update(fileIndex:FileIndex, updateType: UpdateType = .uploadFile) -> Bool {
        if fileIndex.fileIndexId == nil ||
            haveNilFieldForUpdate(fileIndex: fileIndex, updateType:updateType) {
            Log.error("One of the model values was nil: \(fileIndex)")
            return false
        }
        
        // TODO: *2* Seems like we could use an encoding here to deal with sql injection issues.
        let appMetaDataField = getUpdateFieldSetter(fieldValue: fileIndex.appMetaData, fieldName: FileIndex.appMetaDataKey)
        
        let lastUploadedCheckSumField = getUpdateFieldSetter(fieldValue: fileIndex.lastUploadedCheckSum, fieldName: FileIndex.lastUploadedCheckSumKey)
        
        let mimeTypeField = getUpdateFieldSetter(fieldValue: fileIndex.mimeType, fieldName: FileIndex.mimeTypeKey)

        let deviceUUIDField = getUpdateFieldSetter(fieldValue: fileIndex.deviceUUID, fieldName: FileIndex.deviceUUIDKey)
        
        let fileVersionField = getUpdateFieldSetter(fieldValue: fileIndex.fileVersion, fieldName: FileIndex.fileVersionKey, fieldIsString: false)
        
        let fileGroupUUIDField = getUpdateFieldSetter(fieldValue: fileIndex.fileGroupUUID, fieldName: FileIndex.fileGroupUUIDKey)

        var updateDateValue:String?
        if fileIndex.updateDate != nil {
            updateDateValue = DateExtras.date(fileIndex.updateDate, toFormat: .DATETIME)
        }
        let updateDateField = getUpdateFieldSetter(fieldValue: updateDateValue, fieldName: FileIndex.updateDateKey)
        
        let changeResolverNameField = getUpdateFieldSetter(fieldValue: fileIndex.changeResolverName, fieldName: FileIndex.changeResolverNameKey)
        
        let deletedValue = fileIndex.deleted == true ? 1 : 0
        
        let query = "UPDATE \(tableName) SET \(FileIndex.fileUUIDKey)='\(fileIndex.fileUUID!)', \(FileIndex.deletedKey)=\(deletedValue) \(appMetaDataField) \(lastUploadedCheckSumField) \(mimeTypeField) \(deviceUUIDField) \(updateDateField) \(fileVersionField) \(fileGroupUUIDField) \(changeResolverNameField) WHERE \(FileIndex.fileIndexIdKey)=\(fileIndex.fileIndexId!)"
        
        if db.query(statement: query) {
            // "When using UPDATE, MySQL will not update columns where the new value is the same as the old value. This creates the possibility that mysql_affected_rows may not actually equal the number of rows matched, only the number of rows that were literally affected by the query." From: https://dev.mysql.com/doc/apis-php/en/apis-php-function.mysql-affected-rows.html
            if db.numberAffectedRows() <= 1 {
                return true
            }
            else {
                Log.error("Did not have <= 1 row updated: \(db.numberAffectedRows())")
                return false
            }
        }
        else {
            let error = db.error
            Log.error("Could not update \(tableName): \(error)")
            return false
        }
    }

    enum LookupKey : CustomStringConvertible {
        case fileIndexId(Int64)
        case primaryKey(fileUUID:String)
        case fileGroupUUID(fileGroupUUID: String)
        case fileGroupUUIDAndFileLabel(fileGroupUUID: String, fileLabel: String)
        
        var description : String {
            switch self {
            case .fileIndexId(let fileIndexId):
                return "fileIndexId(\(fileIndexId))"
            case .primaryKey(let fileUUID):
                return "fileUUID(\(fileUUID))"
            case .fileGroupUUID(let fileGroupUUID):
                return "fileGroupUUID(\(fileGroupUUID)"
            case .fileGroupUUIDAndFileLabel(fileGroupUUID: let fileGroupUUID, fileLabel: let fileLabel):
                return "fileGroupUUID(\(fileGroupUUID); fileLabel(\(fileLabel))"
            }
        }
    }
    
    func lookupConstraint(key:LookupKey) -> String {
        switch key {
        case .fileIndexId(let fileIndexId):
            return "fileIndexId = \(fileIndexId)"
        case .primaryKey(let fileUUID):
            return "fileUUID = '\(fileUUID)'"
        case .fileGroupUUID(let fileGroupUUID):
            return "fileGroupUUID = '\(fileGroupUUID)'"
        case .fileGroupUUIDAndFileLabel(let fileGroupUUID, let fileLabel):
            return "fileGroupUUID = '\(fileGroupUUID)' AND fileLabel = '\(fileLabel)'"
        }
    }
    
    /* For each entry in Upload for the userId/deviceUUID that is in the uploaded state, we need to do the following:
    
        1) If there is no file in the FileIndex for the userId/fileUUID, then a new entry needs to be inserted into the FileIndex. This should be version 0 of the file. The deviceUUID is taken from the device uploading the file.
        2) If there is already a file in the FileIndex for the userId/fileUUID, then the version number we have in Uploads should be the version number in the FileIndex + 1 (if not, it is an error). Update the FileIndex with the new info from Upload, if no error. More specifically, the deviceUUID of the uploading device will replace that currently in the FileIndex-- because the new file in cloud storage is named:
                <fileUUID>.<Uploading-deviceUUID>.<fileVersion>
            where <fileVersion> is the new file version, and
                <Uploading-deviceUUID> is the device UUID of the uploading device.
    */

    enum TransferUploadsResult {
        case success(numberUploadsTransferred: Int32)
        case failure(RequestHandler.FailureResult?)
    }
    
    enum EffectiveOwningUser {
        case success(UserId)
        case failure(RequestHandler.FailureResult)
    }
         
    // This is for v0 uploads only.
    func transferUploads(uploadUserId: UserId, fileOwnerUserId: UserId, batchUUID: String, sharingGroupUUID: String, uploadingDeviceUUID:String, uploadRepo:UploadRepository, fileIndexClientUIRepo: FileIndexClientUIRepository) -> TransferUploadsResult {
        
        var error = false
        var numberTransferred:Int32 = 0
        
        // [1] Fetch the uploaded files for the user, device, and sharing group.
        guard let uploadSelect = uploadRepo.select(forUserId: uploadUserId, batchUUID: batchUUID, sharingGroupUUID: sharingGroupUUID, deviceUUID: uploadingDeviceUUID) else {
            return .failure(nil)
        }
        
        uploadSelect.forEachRow { [weak self] rowModel in
            guard let self = self else {
                error = true
                return
            }
            
            if error {
                return
            }
            
            let upload = rowModel as! Upload
            
            // This will a) mark the FileIndex entry as deleted for toDeleteFromFileIndex, and b) mark it as not deleted for *both* uploadingUndelete and uploading files. So, effectively, it does part of our upload undelete for us.
            let uploadDeletion = upload.state == .deleteSingleFile

            let fileIndex = FileIndex()
            fileIndex.lastUploadedCheckSum = upload.lastUploadedCheckSum
            fileIndex.deleted = uploadDeletion
            fileIndex.fileUUID = upload.fileUUID
            
            // If this an uploadDeletion, it seems inappropriate to update the deviceUUID in the file index-- all we're doing is marking it as deleted.
            if !uploadDeletion {
                // Using `uploadingDeviceUUID` here, but equivalently use upload.deviceUUID-- they are the same. See [1] above.
                assert(uploadingDeviceUUID == upload.deviceUUID)
                fileIndex.deviceUUID = uploadingDeviceUUID
            }
            
            fileIndex.mimeType = upload.mimeType
            fileIndex.appMetaData = upload.appMetaData
            fileIndex.fileGroupUUID = upload.fileGroupUUID

            if upload.state == .v0UploadCompleteFile {
                fileIndex.fileVersion = 0
                fileIndex.creationDate = upload.creationDate
                fileIndex.changeResolverName = upload.changeResolverName
                
                // The fileLabel does not change over time.
                fileIndex.fileLabel = upload.fileLabel
            }
            else {
                // We're only using this for v0 file uploads.
                Log.error("Not v0UploadCompleteFile")
                error = true
                return
            }
            
            fileIndex.updateDate = upload.updateDate
            
            let key = LookupKey.primaryKey(fileUUID: upload.fileUUID)
            let result = self.lookup(key: key, modelInit: FileIndex.init)
            
            switch result {
            case .error(_):
                error = true
                return
                
            case .found(let object):
                let existingFileIndex = object as! FileIndex

                if uploadDeletion {
                    guard upload.fileVersion == existingFileIndex.fileVersion else {
                        Log.error("Did not specify current version of file in upload deletion!")
                        error = true
                        return
                    }
                }
                else {
                    guard upload.fileVersion == (existingFileIndex.fileVersion + 1) else {
                        Log.error("Did not have next version of file!")
                        error = true
                        return
                    }
                }

                fileIndex.fileIndexId = existingFileIndex.fileIndexId
                
                var updateType:UpdateType = .uploadFile
                if uploadDeletion {
                    updateType = .uploadDeletion
                }
                
                guard self.update(fileIndex: fileIndex, updateType: updateType) else {
                    Log.error("Could not update FileIndex!")
                    error = true
                    return
                }
                
            case .noObjectFound:
                if uploadDeletion {
                    Log.error("Attempting to delete a file not present in the file index: \(key)!")
                    error = true
                    return
                }
                else {
                    guard upload.state == .v0UploadCompleteFile else {
                        Log.error("Did not have version 0 of file!")
                        error = true
                        return
                    }
                    
                    let result = self.retry(request: {
                        self.add(fileIndex: fileIndex)
                    })
                    
                    switch result {
                    case .success:
                        break
                    case .deadlock, .error:
                        Log.error("Could not add new FileIndex!")
                        error = true
                        return
                    }
                }
            }

            // This is for v0. Assign that to upload.
            upload.fileVersion = 0
            let addIfNeededResult = fileIndexClientUIRepo.addIfNeeded(from: upload)
            switch addIfNeededResult {
            case .error:
                Log.error("transferUploads: Failed on adding record to fileIndexClientUIRepo")
                error = true
                return
            case .notNeeded, .success:
                break
            }
            
            numberTransferred += 1
        }
        
        if error {
            return .failure(nil)
        }
        
        if uploadSelect.forEachRowStatus == nil {
            return .success(numberUploadsTransferred: numberTransferred)
        }
        else {
            return .failure(nil)
        }
    }
    
    // Returns nil on error; number of rows marked otherwise.
    // 8/5/20: Just added the "and \(FileIndex.deletedKey) = 0"-- which should ensure that the update can not occur twice, successfully, in a race.
    func markFilesAsDeleted(key:LookupKey) -> Int64? {
        let query = "UPDATE \(tableName) SET \(FileIndex.deletedKey)=1 WHERE " + lookupConstraint(key: key) + " and \(FileIndex.deletedKey) = 0"
        if db.query(statement: query) {
            let numberRows = db.numberAffectedRows()
            Log.debug("Number rows: \(numberRows) for query: \(query)")
            return numberRows
        }
        else {
            let error = db.error
            Log.error("Could not mark files as deleted in \(tableName): \(error)")
            return nil
        }
    }
    
    enum FileIndexResult {
    case fileIndex([FileInfo])
    case error(String)
    }
    
    // Does not return FileIndex rows where the user has been deleted and those rows have been marked as deleted.
    func fileIndex(forSharingGroupUUID sharingGroupUUID: String) -> FileIndexResult {
        let query = """
            select
                \(tableName).*,
                \(UserRepository.tableName).accountType,
                \(FileGroupRepository.tableName).\(FileGroupModel.objectTypeKey),
                \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey),
                \(FileGroupRepository.tableName).\(FileGroupModel.owningUserIdKey)
            from \(tableName), \(UserRepository.tableName), \(FileGroupRepository.tableName)
            where
                \(tableName).fileGroupUUID = \(FileGroupRepository.tableName).\(FileGroupModel.fileGroupUUIDKey)
                and \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey) = '\(sharingGroupUUID)'
                and \(FileGroupRepository.tableName).\(FileGroupModel.owningUserIdKey) = \(UserRepository.tableName).userId
        """
        
        return fileIndex(forSelectQuery: query)
    }
    
    private func fileIndex(forSelectQuery selectQuery: String) -> FileIndexResult {
        guard let select = Select(db:db, query: selectQuery, modelInit: FileIndex.init, ignoreErrors:false) else {
            return .error("Failed on Select!")
        }
        
        var result:[FileInfo] = []
        var error:FileIndexResult!
        
        select.forEachRow { rowModel in
            if let _ = error {
                return
            }
            
            let rowModel = rowModel as! FileIndex

            let fileInfo = FileInfo()
            fileInfo.fileUUID = rowModel.fileUUID
            fileInfo.deviceUUID = rowModel.deviceUUID
            fileInfo.fileVersion = rowModel.fileVersion
            fileInfo.deleted = rowModel.deleted
            fileInfo.mimeType = rowModel.mimeType
            fileInfo.creationDate = rowModel.creationDate
            fileInfo.updateDate = rowModel.updateDate
            fileInfo.fileGroupUUID = rowModel.fileGroupUUID
            fileInfo.owningUserId = rowModel.queryOwningUserId
            fileInfo.sharingGroupUUID = rowModel.querySharingGroupUUID
            fileInfo.objectType = rowModel.queryObjectType
            fileInfo.changeResolverName = rowModel.changeResolverName
            fileInfo.appMetaData = rowModel.appMetaData
            fileInfo.fileLabel = rowModel.fileLabel
            
            guard let accountType = rowModel.accountType,
                let accountScheme = AccountScheme(.accountName(accountType)),
                let cloudStorageType = accountScheme.cloudStorageType else {
                    error = .error("Failed getting cloud storage type for fileUUID: \(String(describing: rowModel.fileUUID))")
                return
            }
            
            fileInfo.cloudStorageType = cloudStorageType

            result.append(fileInfo)
        }
        
        if let error = error {
            return error
        }
        
        if select.forEachRowStatus == nil {
            return .fileIndex(result)
        }
        else {
            return .error("\(select.forEachRowStatus!)")
        }
    }
    
    func fileIndex(forFileGroupUUID fileGroupUUID: String) -> FileIndexResult {
        // We are returning information about the owning user (e.g., the accountType of the owning user-- so we can later know the type of cloud storage). Hence the reference to owningUserId key below.
                
        let query = """
            select
                \(tableName).*,
                \(FileGroupRepository.tableName).\(FileGroupModel.objectTypeKey),
                \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey),
                \(FileGroupRepository.tableName).\(FileGroupModel.owningUserIdKey),
                \(UserRepository.tableName).accountType
            from \(tableName), \(UserRepository.tableName), \(FileGroupRepository.tableName)
            where
            \(tableName).fileGroupUUID = \(FileGroupRepository.tableName).\(FileGroupModel.fileGroupUUIDKey)
            and \(FileGroupRepository.tableName).\(FileGroupModel.owningUserIdKey) = \(UserRepository.tableName).\(User.userIdKey)
            and \(tableName).fileGroupUUID = '\(fileGroupUUID)'
        """
        
        return fileIndex(forSelectQuery: query)
    }
    
    func getFileIndex(forFileUUID fileUUID: String) throws -> FileIndex {
        let key = Self.LookupKey.primaryKey(fileUUID: fileUUID)
        let result = lookup(key: key, modelInit: FileIndex.init)
        guard case .found(let model) = result,
            let fileIndex = model as? FileIndex else {
            throw Errors.couldNotLookupFileUUID
        }
        
        return fileIndex
    }
    
    enum GetGroupSummaryResult {
        case error
        case summary([FileGroupSummary]?)
    }
    
    // `requestingUserId` is the UserId of the user doing the FileIndex request.
    func getGroupSummary(forSharingGroupUUID sharingGroupUUID: String, requestingUserId: UserId) -> GetGroupSummaryResult {
            
        // [2] In this query, I only want results that affect "self". In the client we only want to deal changes that affect the current signed in user, or `self`. This is the reason for the constraint:
        // \(FileIndexClientUIRepository.tableName).\(FileIndexClientUI.fileUUIDKey) <> \(requestingUserId)
        // Note that this comparison is in terms of (a) the user making the request, and (b) the `informAllButUserId` user. And it's specifically *not* in terms of the `userId` from the FileIndex row. Since the `userId` in FileIndex is the *owning* user if we used the owning user id we couldn't deal with social users. We also couldn't deal with changes made to files by non-owning users.

        let selectQuery = """
        select \(tableName).\(FileIndex.deletedKey),
            \(tableName).\(FileIndex.fileGroupUUIDKey),
            \(FileIndexClientUIRepository.tableName).\(FileIndexClientUI.fileVersionKey),
            \(tableName).\(FileIndex.fileUUIDKey)
        from \(tableName), \(FileIndexClientUIRepository.tableName), \(FileGroupRepository.tableName)
        where
            \(FileGroupRepository.tableName).\(FileGroupModel.fileGroupUUIDKey)
                = \(tableName).\(FileIndex.fileGroupUUIDKey)
            and \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey)
                = '\(sharingGroupUUID)'
            and \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey)
                = \(FileIndexClientUIRepository.tableName).\(FileIndexClientUI.sharingGroupUUIDKey)
            and \(tableName).\(FileIndex.fileUUIDKey) = \(FileIndexClientUIRepository.tableName).\(FileIndexClientUI.fileUUIDKey)
            and \(FileIndexClientUIRepository.tableName).\(FileIndexClientUI.informAllButUserIdKey) <> \(requestingUserId)
        """

        guard let select = Select(db:db, query: selectQuery, modelInit: FileIndex.init, ignoreErrors:false) else {
            Log.error("Failed on select: \(selectQuery)")
            return .error
        }
        
        var models = [FileIndex]()

        select.forEachRow { rowModel in
            guard let rowModel = rowModel as? FileIndex else {
                Log.error("Bad row model!")
                return
            }
            
            models += [rowModel]
        }
        
        guard select.forEachRowStatus == nil else {
            return .error
        }
        
        let fileGroups = Partition.array(models, using: \FileIndex.fileGroupUUID)
        
        guard fileGroups.count > 0 else {
            return .summary(nil)
        }
        
        var result = [FileGroupSummary]()
        for fileGroup in fileGroups {
            guard fileGroup.count > 0 else {
                continue
            }
            
            let summary = FileGroupSummary()
            summary.deleted = fileGroup[0].deleted ?? false
            summary.fileGroupUUID = fileGroup[0].fileGroupUUID

            var fileGroupSummaryInform = [FileGroupSummary.Inform]()
            
            for model in fileGroup {                
                guard let fileVersion = model.fileVersion,
                    let fileUUID = model.fileUUID else {
                    Log.error("Nil model.fileVersion")
                    continue
                }
                
                // This must be `self` because of [2] above.
                let whoToInform: FileGroupSummary.Inform.WhoToInform = .self
                
                let inform = FileGroupSummary.Inform(fileVersion: fileVersion, fileUUID: fileUUID, inform: whoToInform)
                
                fileGroupSummaryInform += [inform]
            }
            
            // There may not be any `FileGroupSummary.Inform`'s to add. I.e., no presentation to exclude.
            if fileGroupSummaryInform.count > 0 {
                summary.inform = fileGroupSummaryInform
            }

            result += [summary]
        }
        
        return .summary(result)
    }
    
    func getMostRecentDate(forSharingGroupUUID sharingGroupUUID: String) -> Date? {
        let selectQuery = """
            select
                MAX(\(tableName).\(FileIndex.creationDateKey)) AS \(FileIndex.creationDateKey),
                MAX(\(tableName).\(FileIndex.updateDateKey)) AS \(FileIndex.updateDateKey)
            from \(tableName), \(FileGroupRepository.tableName)
            where
                \(FileGroupRepository.tableName).\(FileGroupModel.fileGroupUUIDKey)
                    = \(tableName).\(FileIndex.fileGroupUUIDKey)
                and \(FileGroupRepository.tableName).\(FileGroupModel.sharingGroupUUIDKey)
                    = '\(sharingGroupUUID)'
        """
        
        guard let select = Select(db:db, query: selectQuery, modelInit: FileIndex.init, ignoreErrors:false) else {
            Log.error("Failed on select: \(selectQuery)")
            return nil
        }
        
        var maxDateResult: Date?

        select.forEachRow { rowModel in
            guard maxDateResult == nil else {
                Log.error("More than one row!")
                return
            }
            
            guard let rowModel = rowModel as? FileIndex else {
                Log.error("Bad row model!")
                return
            }

            maxDateResult = rowModel.creationDate
            
            if let maxUpdateDate = rowModel.updateDate {
                if let result = maxDateResult {
                    maxDateResult = max(maxUpdateDate, result)
                }
                else {
                    maxDateResult = maxUpdateDate
                }
            }
        }
        
        return maxDateResult
    }
}
