//
//  SharingGroupsController+Move.swift
//  Server
//
//  Created by Christopher G Prince on 7/3/21.
//

import Foundation
import ServerShared
import LoggerAPI

extension SharingGroupsController {
    func moveFileGroups(params:RequestProcessingParameters) {
        guard let request = params.request as? MoveFileGroupsRequest else {
            let message = "Did not receive CreateSharingGroupRequest"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let destinationSharingGroupUUID = request.destinationSharingGroupUUID,
            let sourceSharingGroupUUID = request.sourceSharingGroupUUID else {
            let message = "Could not get source or destination sharing group"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        // User must have permissions on the source and dest sharing groups.
        guard sharingGroupSecurityCheck(sharingGroupUUID: destinationSharingGroupUUID, params: params) else {
            let message = "Failed in sharing group security check: For dest sharing group"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard sharingGroupSecurityCheck(sharingGroupUUID: sourceSharingGroupUUID, params: params) else {
            let message = "Failed in sharing group security check: For source sharing group"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let fileGroupUUIDs = request.fileGroupUUIDs,
            fileGroupUUIDs.count > 0 else {
            let message = "No file groups passed!"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

        guard let fileGroups = checkOwners(fileGroupUUIDs: fileGroupUUIDs, sourceSharingGroup: sourceSharingGroupUUID, destinationSharingGroup: destinationSharingGroupUUID, params: params) else {
            // `checkOwners` already did the completion.
            return
        }
        
        // Need to change the `sharingGroupUUID` field of each of the `FileGroupModel`'s.
        // BUT: I've not completed the migration to the use of the FileGroup table. The file index still uses the sharingGroupUUID in the `FileIndex` table.
    }
}

extension SharingGroupsController {
    // All of the file groups must be in the source sharing group, and
    // the v0 uploading user of all of the file groups (media items) to be moved must also have membership in the target/destination sharing group (album).
    // If nil is returned a return has been carried out using `params.completion`.
    // If non-nil is returned, these are the collection of `FileGroupModel`'s. corresponding to the passsed `fileGroupUUIDs`.
    private func checkOwners(fileGroupUUIDs: [String], sourceSharingGroup: String, destinationSharingGroup: String, params:RequestProcessingParameters) -> [FileGroupModel]? {
        let keys = fileGroupUUIDs.map { fileGroupUUID in
            FileGroupRepository.LookupKey.fileGroupUUID(fileGroupUUID: fileGroupUUID)
        }
        
        guard let fileGroups = params.repos.fileGroups.lookupAll(keys: keys, modelInit: FileGroupModel.init) else {
            let message = "Could not lookup FileGroupModel's"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return nil
        }
        
        guard fileGroupUUIDs.count == fileGroups.count else {
            let message = "Did not find all file groups passed as parameter."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return nil
        }

        // Make sure that all file groups are in the source sharing group
        let sourceFilter = fileGroups.filter { $0.sharingGroupUUID == sourceSharingGroup }
        guard sourceFilter.count == fileGroups.count else {
            let message = "Some of the file groups were not in the source sharing group."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return nil
        }
        
        // Get all the unique uploading users from the file groups
        let uploadingUserIds = Set<UserId>(fileGroups.map { $0.userId })
        
        let sharingGroupUserKeys = uploadingUserIds.map { uploadingUserIds in
            SharingGroupUserRepository.LookupKey.primaryKeys(sharingGroupUUID: destinationSharingGroup, userId: uploadingUserIds, deleted: nil)
        }
        
        guard let sharingGroupUsers = params.repos.sharingGroupUser.lookupAll(keys: sharingGroupUserKeys, modelInit: SharingGroupUser.init) else {
            let message = "Could not lookup SharingGroupUser's"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return nil
        }
        
        guard uploadingUserIds.count == sharingGroupUsers.count else {
            let message = "Not all file group users were in the destination sharing group"
            Log.error(message)
            let response = MoveFileGroupsResponse()
            response.result = .failedWithNotAllOwnersInTarget
            params.completion(.success(response))
            return nil
        }
        
        return fileGroups
    }
}
