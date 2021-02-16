//
//  DeleteStaleFileVersions.swift
//  Server
//
//  Created by Christopher G Prince on 2/15/21.
//

import Foundation
import LoggerAPI
import ServerShared
import ServerAccount

class DeleteStaleFileVersions {
    enum DeleteStaleFileVersionsError: Error {
        case generic(String)
    }
    
    private let staleVersionRepo:StaleVersionRepository
    private var fileIndexRepo:FileIndexRepository
    private let userRepo: UserRepository
    private let services: UploaderServices
    
    init(staleVersionRepo:StaleVersionRepository, fileIndexRepo:FileIndexRepository, userRepo: UserRepository, services: UploaderServices) {
        self.staleVersionRepo = staleVersionRepo
        self.fileIndexRepo = fileIndexRepo
        self.userRepo = userRepo
        self.services = services
    }
    
    // Operates synchronously
    func doNeededDeletions() throws {
        Log.info("Checking for stale file versions that need deleting.")

        let staleVersionKey = StaleVersionRepository.LookupKey.needingDeletion
        guard let staleFileVersions = staleVersionRepo.lookupAll(key: staleVersionKey, modelInit: StaleVersion.init) else {
            throw DeleteStaleFileVersionsError.generic("DeleteStaleFileVersions: failed on lookupAll")
        }
        
        guard staleFileVersions.count > 0 else {
            Log.debug("No stale files need deletion.")
            return
        }
        
        Log.debug("\(staleFileVersions.count) stale files need deletion.")
        
        var fileDeletions = [FileDeletion]()
        
        for staleFileVersion in staleFileVersions {
            let fileIndexKey = FileIndexRepository.LookupKey.fileIndexId(staleFileVersion.fileIndexId)
            let fileIndexResult = fileIndexRepo.lookup(key: fileIndexKey, modelInit: FileIndex.init)
            guard case .found(let object) = fileIndexResult,
                let fileIndex = object as? FileIndex else {
                throw DeleteStaleFileVersionsError.generic("DeleteStaleFileVersions: failed lookup in FileIndexRepository: \(String(describing: staleFileVersion.fileIndexId))")
            }

            guard let (owningCreds, cloudStorage) = try? fileIndex.getCloudStorage(userRepo: userRepo, services: services) else {
                throw DeleteStaleFileVersionsError.generic("DeleteStaleFileVersions: failed getCloudStorage")
            }
        
            let options = CloudStorageFileNameOptions(cloudFolderName: owningCreds.cloudFolderName, mimeType: fileIndex.mimeType)
            let currentCloudFileName = Filename.inCloud(deviceUUID: staleFileVersion.deviceUUID, fileUUID: staleFileVersion.fileUUID, mimeType: options.mimeType, fileVersion: staleFileVersion.fileVersion)
            let deletion = FileDeletion(cloudStorage: cloudStorage, cloudFileName: currentCloudFileName, options: options)
            
            fileDeletions += [deletion]
        }

        // Need to remove entries from the StaleVersionsRepo. If I delete the files first, and then the db removal fails, then I might later try deleting files that aren't there -- due to the db references.
        if let errors = FileDeletion.apply(deletions: fileDeletions), errors.count > 0 {
            throw DeleteStaleFileVersionsError.generic("FileDeletion.apply: \(errors)")
        }
        
        let removalResult = staleVersionRepo.remove(key: staleVersionKey)
        guard case .removed(let count) = removalResult else {
            throw DeleteStaleFileVersionsError.generic("Failed deleting StaleVersion repo records")
        }
        
        Log.debug("Successfully deleted \(count) stale file versions.")
    }
}
