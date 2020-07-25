//
//  ApplyDeferredUploads.swift
//  Server
//
//  Created by Christopher G Prince on 7/18/20.
//

import Foundation
import ServerAccount
import ChangeResolvers
import ServerShared
import LoggerAPI

// Each DeferredUpload corresponds to one or more Upload record.
/* Here's the algorithm:
    0) Open the database transaction.
    1) Need to get the Account for the owner for this fileGroupUUID.
    2) let allUploads = all of the Upload records corresponding to these DeferredUpload's.
    3) let fileUUIDs = the set of unique fileUUID's within allUploads.
    4) let uploads(fileUUID) be the set of Upload's for a given fileUUID within fileUUIDs, i.e., within allUploads.
    5) for fileUUID in fileUUIDs {
         let uploadsForFileUUID = uploads(fileUUID)
         Get the change resolver for this fileUUID from the FileIndex
         Read the file indicated by fileUUID from cloud storage.
         for upload in uploadsForFileUUID {
           Apply the change in upload to the file data using the change resolver.
         }
         Write the file data for the updated file back to cloud storage.
       }
    6) Do the update of the FileIndex based on these DeferredUpload records.
    7) Remove these DeferredUpload from the database.
    8) End the database transaction.
 */

// Process a group of deferred uploads, for a single fileGroupUUID; all DeferredUploads given must have the fileGroupUUID given. The file group must be in the given sharing group. ie., all deferred uploads will have this sharingGroupUUID.
// Call the `run` method to kick this off. Once this succeeds, it removes the DeferredUpload's. It does the datatabase operations within a transaction.
// NOTE: Currently this statement of consistency applies at the database level, but not at the file level. If this fails mid-way through processing, new file versions may be present. We need to put in some code to deal with a restart which itself doesn't fail if the a new file version is present. Perhaps overwrite it?
class ApplyDeferredUploads {
    enum Errors: Error {
        case notAllInGroupHaveSameFileGroupUUID
        case deferredUploadIds
        case couldNotGetAllUploads
        case couldNotGetFileUUIDs
        case failedRemovingDeferredUpload
        case couldNotLookupFileUUID
        case couldNotGetOwningUserCreds
        case couldNotConvertToCloudStorage
        case couldNotLookupResolverName
        case couldNotLookupResolver
        case failedStartingTransaction
        case couldNotCommit
        case failedSetupForApplyChangesToSingleFile(String)
        case unknownResolverType
        case couldNotGetDeviceUUID
        case downloadError(DownloadResult)
        case failedInitializingWholeFileReplacer
        case noContentsForUpload
        case failedAddingChange(Error)
        case failedGettingReplacerData
        case failedUploadingNewFileVersion
        case failedUpdatingFileIndex
        case failedRemovingUploadRow
    }
    
    let sharingGroupUUID: String
    let fileGroupUUID: String
    let deferredUploads: [DeferredUpload]
    let db: Database
    let allUploads: [Upload]
    let fileIndexRepo: FileIndexRepository
    let accountManager: AccountManager
    let resolverManager: ChangeResolverManager
    let fileUUIDs: [String]
    let uploadRepo:UploadRepository
    let deferredUploadRepo:DeferredUploadRepository
    var fileDeletions = [FileDeletion]()
    
    init?(sharingGroupUUID: String, fileGroupUUID: String, deferredUploads: [DeferredUpload], accountManager: AccountManager, resolverManager: ChangeResolverManager, db: Database) throws {
        self.sharingGroupUUID = sharingGroupUUID
        self.fileGroupUUID = fileGroupUUID
        self.deferredUploads = deferredUploads
        self.db = db
        self.accountManager = accountManager
        self.resolverManager = resolverManager
        self.fileIndexRepo = FileIndexRepository(db)
        self.uploadRepo = UploadRepository(db)
        self.deferredUploadRepo = DeferredUploadRepository(db)
        
        guard deferredUploads.count > 0 else {
            return nil
        }
        
        guard (deferredUploads.filter {$0.fileGroupUUID == fileGroupUUID}).count == deferredUploads.count else {
            throw Errors.notAllInGroupHaveSameFileGroupUUID
        }
        
        let deferredUploadIds = deferredUploads.compactMap{$0.deferredUploadId}
        guard deferredUploads.count == deferredUploadIds.count else {
            throw Errors.deferredUploadIds
        }
        
        guard let allUploads = UploadRepository(db).select(forDeferredUploadIds: deferredUploadIds) else {
            throw Errors.couldNotGetAllUploads
        }
        self.allUploads = allUploads
        
        let fileUUIDs = allUploads.compactMap{$0.fileUUID}
        guard fileUUIDs.count == allUploads.count else {
            throw Errors.couldNotGetFileUUIDs
        }
        
        // Now that we have the fileUUIDs, we need to make sure they are unique.
        self.fileUUIDs = Array(Set<String>(fileUUIDs))
    }
    
    func cleanup(completion: @escaping (Error?)->()) {
        for deferredUpload in deferredUploads {
            let key = DeferredUploadRepository.LookupKey.deferredUploadId(deferredUpload.deferredUploadId)
            let result = deferredUploadRepo.retry {
                return self.deferredUploadRepo.remove(key: key)
            }
            guard case .removed(numberRows: let numberRows) = result,
                numberRows == 1 else {
                completion(Errors.failedRemovingDeferredUpload)
                return
            }
        }
        
        FileDeletion.apply(deletions: fileDeletions) { _ in
            completion(nil)
        }
    }
    
    func uploads(fileUUID: String) -> [Upload] {
        return allUploads.filter{$0.fileUUID == fileUUID}
    }

    func getFileIndex(forFileUUID fileUUID: String) throws -> FileIndex {
        let key = FileIndexRepository.LookupKey.primaryKeys(sharingGroupUUID: sharingGroupUUID, fileUUID: fileUUID)
        let result = fileIndexRepo.lookup(key: key, modelInit: FileIndex.init)
        guard case .found(let model) = result,
            let fileIndex = model as? FileIndex else {
            throw Errors.couldNotLookupFileUUID
        }
        
        return fileIndex
    }
    
    func getCloudStorage(forFileUUID fileUUID: String, usingFileIndex fileIndex: FileIndex) throws -> (Account, CloudStorage) {
        guard let owningUserCreds = FileController.getCreds(forUserId: fileIndex.userId, from: db, accountManager: accountManager) else {
            throw Errors.couldNotGetOwningUserCreds
        }
        
        guard let cloudStorage = owningUserCreds as? CloudStorage else {
            throw Errors.couldNotConvertToCloudStorage
        }
        
        return (owningUserCreds, cloudStorage)
    }
    
    func changeResolver(forFileUUID fileUUID: String, usingFileIndex fileIndex: FileIndex) throws -> ChangeResolver.Type {
        guard let changeResolverName = fileIndex.changeResolverName else {
            Log.error("couldNotLookupResolverName")
            throw Errors.couldNotLookupResolverName
        }
        
        guard let resolverType = resolverManager.getResolverType(changeResolverName) else {
            Log.error("couldNotLookupResolver")
            throw Errors.couldNotLookupResolver
        }
        
        return resolverType
    }
    
    // Apply changes to all fileUUIDs. This deals with database transactions.
    func run(completion: @escaping (Error?)->()) {
        guard db.startTransaction() else {
            completion(Errors.failedStartingTransaction)
            return
        }
        
        func apply(fileUUID: String, completion: @escaping (Swift.Result<Void, Error>) -> ()) {
            Log.debug("applyChangesToSingleFile: \(fileUUID)")

            applyChangesToSingleFile(fileUUID: fileUUID) { error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                completion(.success(()))
            }
        }
        
        let result = fileUUIDs.synchronouslyRun(apply: apply)
        switch result {
        case .success:
            guard self.db.commit() else {
                completion(Errors.couldNotCommit)
                return
            }
            
            Log.info("About to start cleanup.")
            self.cleanup(completion: completion)
            
        case .failure(let error):
            _ = self.db.rollback()
            completion(error)
        }
    }
    
    func applyChangesToSingleFile(fileUUID: String, completion: @escaping (Error?)->()) {
        let uploadsForFileUUID = uploads(fileUUID: fileUUID)
        
        guard let fileIndex = try? getFileIndex(forFileUUID: fileUUID) else {
            completion(Errors.failedSetupForApplyChangesToSingleFile("FileIndex"))
            return
        }
        
        guard let resolver = try? changeResolver(forFileUUID: fileUUID, usingFileIndex: fileIndex) else {
            completion(Errors.failedSetupForApplyChangesToSingleFile("Resolver"))
            return
        }
        
        guard let (owningCreds, cloudStorage) = try? getCloudStorage(forFileUUID: fileUUID, usingFileIndex: fileIndex) else {
            completion(Errors.failedSetupForApplyChangesToSingleFile("getCloudStorage"))
            return
        }
        
        // Only a single type of change resolver protocol so far. Need changes here when we add another.
        guard let wholeFileReplacer = resolver as? WholeFileReplacer.Type else {
            completion(Errors.unknownResolverType)
            return
        }
        
        // We're applying changes and creating the next version of the file
        let nextVersion = fileIndex.fileVersion + 1
        
        guard let deviceUUID = fileIndex.deviceUUID else {
            completion(Errors.couldNotGetDeviceUUID)
            return
        }
        
        let currentCloudFileName = Filename.inCloud(deviceUUID:deviceUUID, fileUUID: fileUUID, mimeType:fileIndex.mimeType, fileVersion: fileIndex.fileVersion)
        let options = CloudStorageFileNameOptions(cloudFolderName: owningCreds.cloudFolderName, mimeType: fileIndex.mimeType)
        
        Log.debug("downloadFile: \(currentCloudFileName)")
        cloudStorage.downloadFile(cloudFileName: currentCloudFileName, options: options) { downloadResult in
            guard case .success(data: let fileContents, checkSum: _) = downloadResult else {
                completion(Errors.downloadError(downloadResult))
                return
            }
            
            guard var replacer = try? wholeFileReplacer.init(with: fileContents) else {
                completion(Errors.failedInitializingWholeFileReplacer)
                return
            }
            
            for upload in uploadsForFileUUID {
                guard let changeData = upload.uploadContents else {
                    completion(Errors.noContentsForUpload)
                    return
                }
                
                do {
                    try replacer.add(newRecord: changeData)
                } catch let error {
                    completion(Errors.failedAddingChange(error))
                    return
                }
            }
            
            guard let replacementFileContents = try? replacer.getData() else {
                completion(Errors.failedGettingReplacerData)
                return
            }
            
            let nextCloudFileName = Filename.inCloud(deviceUUID:deviceUUID, fileUUID: fileUUID, mimeType:fileIndex.mimeType, fileVersion: nextVersion)

            Log.debug("uploadFile: \(nextCloudFileName)")

            cloudStorage.uploadFile(cloudFileName: nextCloudFileName, data: replacementFileContents, options: options) {[unowned self] uploadResult in
                guard case .success(let checkSum) = uploadResult else {
                    completion(Errors.failedUploadingNewFileVersion)
                    return
                }
                
                fileIndex.lastUploadedCheckSum = checkSum
                fileIndex.fileVersion = nextVersion
                fileIndex.updateDate = Date()
                
                guard self.fileIndexRepo.update(fileIndex: fileIndex) else {
                    completion(Errors.failedUpdatingFileIndex)
                    return
                }
                
                // Remove Upload records from db (uploadsForFileUUID)
                for upload in uploadsForFileUUID {
                    let key = UploadRepository.LookupKey.uploadId(upload.uploadId)
                    let result = self.uploadRepo.retry {
                        return self.uploadRepo.remove(key: key)
                    }
                    
                    guard case .removed(numberRows: let numberRows) = result,
                        numberRows == 1 else {
                        completion(Errors.failedRemovingUploadRow)
                        return
                    }
                }
                
                // Don't do deletions yet. The overall operations can't be repeated if the original files are gone.
                let deletion = FileDeletion(cloudStorage: cloudStorage, cloudFileName: currentCloudFileName, options: options)
                self.fileDeletions += [deletion]
                
                completion(nil)
            }
        }
    }
}
