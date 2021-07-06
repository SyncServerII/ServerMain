//
//  FileController+DownloadFile.swift
//  Server
//
//  Created by Christopher Prince on 3/22/17.
//
//

import Foundation
import LoggerAPI
import ServerShared
import Kitura
import ServerAccount

extension FileController {
    func downloadFile(params:RequestProcessingParameters) {
        guard let downloadRequest = params.request as? DownloadFileRequest else {
            let message = "Did not receive DownloadFileRequest"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard sharingGroupSecurityCheck(sharingGroupUUID: downloadRequest.sharingGroupUUID, params: params) else {
            let message = "Failed in sharing group security check."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        // TODO: *0* What would happen if someone else deletes the file as we we're downloading it? It seems a shame to hold a lock for the entire duration of the download, however.
        
        // Need to get the file from the cloud storage service:
            
        // First, lookup the file in the FileIndex.
           
        let key = FileIndexRepository.LookupKey.primaryKey(fileUUID: downloadRequest.fileUUID)
        let lookupResult = params.repos.fileIndex.lookup(key: key, modelInit: FileIndex.init)
        
        let fileIndex:FileIndex
        
        switch lookupResult {
        case .found(let model):
            guard let model = model as? FileIndex else {
                let message = "Could not convert model object to FileIndex"
                Log.error(message)
                params.completion(.failure(.message(message)))
                return
            }
            
            fileIndex = model
            
        case .noObjectFound:
            let message = "Could not find file in FileIndex"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
            
        case .error(let error):
            let message = "Error looking up file in FileIndex: \(error)"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

        // Also do an important security check -- make sure the fileUUID is in the sharing group.
        guard let fileGroupModel = try? params.repos.fileGroups.getFileGroup(forFileGroupUUID: fileIndex.fileGroupUUID) else {
            let message = "Could not get file group."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard fileGroupModel.sharingGroupUUID == downloadRequest.sharingGroupUUID else {
            let message = "File was not in the sharing group."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        var foundStaleVersion = false
        let staleVersionKey = StaleVersionRepository.LookupKey.uuids(fileUUID: fileIndex.fileUUID, sharingGroupUUID: fileGroupModel.sharingGroupUUID, fileVersion: downloadRequest.fileVersion)
        let staleVersionLookupResult = params.repos.staleVersion.lookup(key: staleVersionKey, modelInit: StaleVersion.init)
        switch staleVersionLookupResult {
        case .found:
            foundStaleVersion = true
            
        case .noObjectFound:
            break
            
        case .error(let error):
            let message = "Error looking up file in StaleVersion: \(error)"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        // Either the file version needs to be in the FileIndex or in StaleVersion.
        
        guard foundStaleVersion ||
            downloadRequest.fileVersion == fileIndex.fileVersion else {
            let message = "Expected file version \(String(describing: downloadRequest.fileVersion)) was not the same as the actual version \(String(describing: fileIndex.fileVersion))"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let deleted = fileIndex.deleted else {
            let message = "Nil fileIndex.deleted value"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard !deleted else {
            let message = "The file you are trying to download has been deleted!"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
                            
        // Both the deviceUUID and the fileUUID must come from the file index-- They give the specific name of the file in cloud storage. The deviceUUID of the requesting device is not the right one.
        guard let deviceUUID = fileIndex.deviceUUID else {
            let message = "No deviceUUID!"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        let cloudFileName = Filename.inCloud(deviceUUID: deviceUUID, fileUUID: downloadRequest.fileUUID, mimeType: fileIndex.mimeType, fileVersion: downloadRequest.fileVersion)

        // OWNER
        // The cloud storage for the file is the original owning user's storage.
        guard let owningUserCreds = FileController.getCreds(forUserId: fileGroupModel.owningUserId, userRepo: params.repos.user, accountManager: params.services.accountManager, accountDelegate: params.accountDelegate) else {
            let message = "Could not obtain owning users creds"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let cloudStorageCreds = owningUserCreds.cloudStorage(mock: params.services.mockStorage),
            let cloudStorageType = owningUserCreds.accountScheme.cloudStorageType else {
            let message = "Could not obtain cloud storage creds or cloud storage type."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        let options = CloudStorageFileNameOptions(cloudFolderName: owningUserCreds.cloudFolderName, mimeType: fileIndex.mimeType)
        
        cloudStorageCreds.downloadFile(cloudFileName: cloudFileName, options:options) { result in
            switch result {
            case .success(let data, let checkSum):
                // I used to check the file size as downloaded against the file size in the file index (last uploaded). And call it an error if they didn't match. But we're being fancier now. Going to let the client see if this is an error. https://github.com/crspybits/SyncServerII/issues/93
                
                Log.debug("CheckSum: \(checkSum)")

                var contentsChanged = false
                // 11/4/18; This is conditional because for migration purposes, the FileIndex may not contain a lastUploadedCheckSum. i.e., it comes from a FileIndex record before we added the lastUploadedCheckSum field.
                if let lastUploadedCheckSum = fileIndex.lastUploadedCheckSum {
                    contentsChanged = checkSum != lastUploadedCheckSum
                }
                
                let response = DownloadFileResponse()
                response.appMetaData = fileIndex.appMetaData
                response.data = data
                response.checkSum = checkSum
                response.cloudStorageType = cloudStorageType
                response.contentsChanged = contentsChanged
                params.completion(.success(response))
            
            // Don't consider the following two cases as HTTP status errors, so we can return appMetaData back to client. appMetaData, for v0 files, can be necessary for clients to deal more completely with these error conditions.
            case .accessTokenRevokedOrExpired:
                let message = "Access token revoked or expired."
                Log.error(message)
                let response = DownloadFileResponse()
                response.appMetaData = fileIndex.appMetaData
                response.cloudStorageType = cloudStorageType
                response.gone = GoneReason.authTokenExpiredOrRevoked.rawValue
                params.completion(.success(response))
                
            case .fileNotFound:
                let message = "File not found."
                Log.error(message)
                let response = DownloadFileResponse()
                response.appMetaData = fileIndex.appMetaData
                response.cloudStorageType = cloudStorageType
                response.gone = GoneReason.fileRemovedOrRenamed.rawValue
                params.completion(.success(response))
            
            case .failure(let error):
                let message = "Failed downloading file: \(error); file: \(cloudFileName)"
                Log.error(message)
                params.completion(.failure(.message(message)))
            }
        }
    }
}
