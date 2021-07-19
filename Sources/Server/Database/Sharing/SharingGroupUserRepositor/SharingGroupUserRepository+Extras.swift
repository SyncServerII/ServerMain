//
//  SharingGroupUserRepository+Extras.swift
//  Server
//
//  Created by Christopher G Prince on 7/6/21.
//

import Foundation
import ServerShared
import LoggerAPI

extension SharingGroupUserRepository {
    enum CheckPermissionsResult {
        case success
        case didNotHavePermission
        case didNotHaveMinimumPermission(needed: Permission, had: Permission)
        case sharingGroupUUIDNotFound
        case sharingGroupUUIDGone
        case error(String)
    }
    
    func checkPermissions(userId: UserId, sharingGroupUUID: String, minPermission:Permission?, sharingGroupRepo: SharingGroupRepository) -> CheckPermissionsResult {

        let key = SharingGroupUserRepository.LookupKey.primaryKeys(sharingGroupUUID: sharingGroupUUID, userId: userId, deleted: false)
        let result = lookup(key: key, modelInit: SharingGroupUser.init)
        switch result {
        case .found(let model):
            guard let sharingGroupUser = model as? SharingGroupUser,
                let userPermissions = sharingGroupUser.permission else {
                return .didNotHavePermission
            }

            if let minPermission = minPermission {
                guard userPermissions.hasMinimumPermission(minPermission) else {
                    return .didNotHaveMinimumPermission(needed: minPermission, had: userPermissions)
                }
            }
            
        case .noObjectFound:
            // One reason that the sharing group user might not be found is that the SharingGroupUser was removed from the system-- e.g., if an owning user is deleted, SharingGroupUser rows that have it as their owningUserId will be removed.
            // If a client fails with this error, it seems like some kind of client error or edge case where the client should have been updated already (i.e., from an Index endpoint call) so that it doesn't make such a request. Therefore, I'm not going to code a special case on the client to deal with this.
            // 7/8/20; Actually, this occurs simply when an incorrect sharingGroupUUID is used when uploading a file. Let's test to see if the sharingGroupUUID exists.
            if let exists = sharingGroupExists(sharingGroupUUID: sharingGroupUUID, sharingGroupRepo: sharingGroupRepo), exists {
                return .sharingGroupUUIDGone
            }
            else {
                return .sharingGroupUUIDNotFound
            }

        case .error(let error):
            return .error(error)
        }
        
        return .success
    }
    
    private func sharingGroupExists(sharingGroupUUID: String, sharingGroupRepo: SharingGroupRepository) -> Bool? {
        let key = SharingGroupRepository.LookupKey.sharingGroupUUID(sharingGroupUUID)
        let result = sharingGroupRepo.lookup(key: key, modelInit: SharingGroup.init)
        switch result {
        case .found:
            return true
        case .noObjectFound:
            return false
        case .error(let error):
            Log.error("sharingGroupExists: \(error)")
            return nil
        }
    }
    
    // Check which users are are actively in the sharing group (i.e., not deleted members). Returns nil on error.
    func usersInSharingGroup(sharingGroupUUID: String) -> Set<UserId>? {
        guard let users:[User] = sharingGroupUsers(forSharingGroupUUID: sharingGroupUUID, includeRemovedUsers: false) else {
            return nil
        }
        
        return Set<UserId>(users.map { $0.userId })
    }
}
