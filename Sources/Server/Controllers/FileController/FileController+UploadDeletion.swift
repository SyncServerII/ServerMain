//
//  FileController+UploadDeletion.swift
//  Server
//
//  Created by Christopher Prince on 3/22/17.
//
//

import Foundation
import LoggerAPI
import ServerShared
import Kitura

/* Algorithm:

1) Gets the database key for
    a) the fileUUID if the request one
    b) the fileGroupUUID, if the deletion request has one
2) Gets all the [FileInfo] objects for the files for those keys
3) If all of the files are already marked as deleted, returns success.
    Just a repeated attempt to delete the same file.
4) If at least one file not yet deleted, marks the FileIndex as deleted for all of the files.
    Doesn't yet delete the file in Cloud Storage.
5) Creates a DeferredUpload, and
    a) If this deletion is for one fileUUID, creates a Upload record.
        and links in the DeferredUpload
    b) If this deletion is for a fileGroupUUID, doesn't create an Upload record.
6) The Uploader will then (asynchonously):
    a) For a single fileUUID
        Flush out any DeferredUpload record(s) for that file
        And remove any Upload record(s).
        Delete the file from Cloud Storage.
    b) For a fileGroupUUID
        Flush out any DeferredUpload record(s) for the files associated with that file group.
        And remove any Upload record(s) for that file group.
        Delete the file(s) from Cloud Storage.
 */

extension FileController {
    func uploadDeletion(params:RequestProcessingParameters) {
        guard let uploadDeletionRequest = params.request as? UploadDeletionRequest else {
            let message = "Did not receive UploadDeletionRequest"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let sharingGroupUUID = uploadDeletionRequest.sharingGroupUUID,
            sharingGroupSecurityCheck(sharingGroupUUID: sharingGroupUUID, params: params) else {
            let message = "Failed in sharing group security check."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

        guard let fileGroupUUID = uploadDeletionRequest.fileGroupUUID else {
            let message = "Did not have a fileGroupUUID"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let fileGroup = try? params.repos.fileGroups.getFileGroup(forFileGroupUUID: fileGroupUUID) else {
            let message = "Could not get file group."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

        // Make sure the file group is in the sharing group.
        guard fileGroup.sharingGroupUUID == uploadDeletionRequest.sharingGroupUUID  else {
            let message = "The file group was not in the sharing group."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

        // Is the file group already marked as deleted?
        if fileGroup.deleted {
            Log.info("File(s) already marked as deleted: Not deleting again.")
            let response = UploadDeletionResponse()
            params.completion(.success(response))
            return
        }
        
        // Mark the file(s) as deleted in the FileGroup
        let key = FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fileGroupUUID)
        guard let _ = params.repos.fileGroups.markAsDeleted(key: key) else {
            let message = "Failed marking file(s) as deleted: \(key)"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        let finishType:FinishUploadDeletion.DeletionsType = .fileGroup(fileGroupUUID: uploadDeletionRequest.fileGroupUUID)

        let uploader = Uploader(services: params.services.uploaderServices, delegate: params.services)

        do {
            let finishUploads = try FinishUploadDeletion(type: finishType, uploader: uploader, sharingGroupUUID: sharingGroupUUID, params: params)
            let result = try finishUploads.finish()
            
            switch result {
            case .deferred(let deferredUploadId, let runner):
                Log.info("Success deleting files: Subject to deferred transfer.")
                let response = UploadDeletionResponse()
                response.deferredUploadId = deferredUploadId
                params.completion(.successWithRunner(response, runner: runner))
                
            case .error:
                let message = "Could not complete FinishUploads"
                Log.error(message)
                params.completion(.failure(.message(message)))
            }
        } catch let error {
            let message = "Could not finish FinishUploads: \(error)"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
    }
}
