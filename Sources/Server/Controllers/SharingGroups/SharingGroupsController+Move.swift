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
        
        // The owners of all of the media items to be moved must also have membership in the target/destination album.
        
        
    }
}
