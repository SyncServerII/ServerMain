//
//  FileController+UploadFile+OtherUser.swift
//  Server
//
//  Created by Christopher G Prince on 6/5/21.
//

// Support for another user uploading a v0 file. i.e., one user uploaded files in a file group, and then another user uploads a file to that file group. We want the owning user for the new file in the existing file group to be the same as the other files in the file group.

import Foundation
import ServerShared

extension FileController {
    enum GetExistingUserResult {
        case error(String)
        case fileGroupNotFound
        case userId(UserId)
    }
    
    // For a v0 file see if this is an existing file group.
    func getExistingOwningUser(fileGroupUUID: String, sharingGroupUUID: String, params:RequestProcessingParameters) -> GetExistingUserResult {
        let key = FileIndexRepository.LookupKey.fileGroupUUID(fileGroupUUID: fileGroupUUID)
        guard let fileIndices = params.repos.fileIndex.lookupAll(key: key, modelInit: FileIndex.init) else {
            return .error("Could not lookup file group in FileIndex")
        }
        
        guard fileIndices.count > 0 else {
            return .fileGroupNotFound
        }
        
        guard let fileGroup = try? params.repos.fileGroups.getFileGroup(forFileGroupUUID: fileGroupUUID) else {
            return .error("No FileGroup")
        }
        
        guard fileGroup.sharingGroupUUID == sharingGroupUUID else {
            return .error("Sharing group was not that expected.")
        }
        
        return .userId(fileGroup.owningUserId)
    }
}
