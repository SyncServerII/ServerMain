//
//  FileController.swift
//  Server
//
//  Created by Christopher Prince on 1/15/17.
//
//

import Foundation
import LoggerAPI
import Credentials
import CredentialsGoogle
import ServerShared
import ServerAccount

class FileController : ControllerProtocol {    
    enum CheckError : Error {
        case couldNotConvertModelObject
        case errorLookingUpInFileIndex
        case errorLookingUpFileGroup
        case sharingGroupMismatch
    }
    
    // Result is nil only if there is no existing file in the FileIndex. Throws an error if there is an error.
    static func checkForExistingFile(params:RequestProcessingParameters, sharingGroupUUID: String, fileUUID: String) throws -> FileIndex? {
        
        let key = FileIndexRepository.LookupKey.primaryKey(fileUUID: fileUUID)
        let lookupResult = params.repos.fileIndex.lookup(key: key, modelInit: FileIndex.init)

        switch lookupResult {
        case .found(let modelObj):
            guard let fileIndexObj = modelObj as? FileIndex else {
                Log.error("Could not convert model object to FileIndex")
                throw CheckError.couldNotConvertModelObject
            }
            
            guard let fileGroup = try? params.repos.fileGroups.getFileGroup(forFileGroupUUID: fileIndexObj.fileGroupUUID) else {
                throw CheckError.errorLookingUpFileGroup
            }
            
            guard fileGroup.sharingGroupUUID == sharingGroupUUID else {
                throw CheckError.sharingGroupMismatch
            }
            
            return fileIndexObj
            
        case .noObjectFound:
            return nil
            
        case .error(let error):
            Log.error("Error looking up file in FileIndex: \(error)")
            throw CheckError.errorLookingUpInFileIndex
        }
    }
    
    class func setup() -> Bool {
        return true
    }
    
    init() {
    }
    
    // OWNER
    // userId is the owning user Id-- e.g., obtained from the userId field of FileIndex.
    static func getCreds(forUserId userId: UserId, userRepo: UserRepository, accountManager: AccountManager, accountDelegate: AccountDelegate?) -> Account? {
        let userKey = UserRepository.LookupKey.userId(userId)
        let userResults = userRepo.lookup(key: userKey, modelInit: User.init)
        guard case .found(let model) = userResults,
            let user = model as? User else {
            Log.error("Could not get user from database.")
            return nil
        }
    
        guard let credsJSON = user.creds, let creds = try? accountManager.accountFromJSON(credsJSON, accountName: user.accountType, user: .user(user), accountDelegate: accountDelegate) else {
            Log.error("Could not get user creds.")
            return nil
        }
                
        return creds
    }
            
    func index(params:RequestProcessingParameters) {
        guard let indexRequest = params.request as? IndexRequest else {
            let message = "Did not receive IndexRequest"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }

#if DEBUG
        if indexRequest.testServerSleep != nil {
            Log.info("Starting sleep (testServerSleep= \(indexRequest.testServerSleep!)).")
            Thread.sleep(forTimeInterval: TimeInterval(indexRequest.testServerSleep!))
            Log.info("Finished sleep (testServerSleep= \(indexRequest.testServerSleep!)).")
        }
#endif

        guard params.repos.fileIndexClientUI.removeExpiredRecords() else {
            let message = "Could not remove expired fileIndexClientUI records"
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        // Only giving a summary of content per sharing group when not requesting an index for a specific sharing group.
        let includeContentsSummary = indexRequest.sharingGroupUUID == nil

        guard let clientSharingGroups = params.repos.sharingGroup.sharingGroups(forUserId: params.currentSignedInUser!.userId, includeContentsSummary: includeContentsSummary, includeRemovedUsers: true, sharingGroupUserRepo: params.repos.sharingGroupUser, userRepo: params.repos.user, fileIndexRepo: params.repos.fileIndex) else {
            let message = "Could not get sharing groups for user."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
        
        guard let sharingGroupUUID = indexRequest.sharingGroupUUID else {
            // Not an error-- caller just didn't give a sharing group uuid-- only returning sharing group info.
            let response = IndexResponse()
            response.sharingGroups = clientSharingGroups
            params.completion(.success(response))
            return
        }
        
        Log.info("Index: Getting file index for sharing group uuid: \(sharingGroupUUID)")

        // Not worrying about whether the sharing group is deleted-- where's the harm in getting a file index for a deleted sharing group?
        guard sharingGroupSecurityCheck(sharingGroupUUID: sharingGroupUUID, params: params, checkSharingGroupNotDeleted: false) else {
            let message = "Failed in sharing group security check."
            Log.error(message)
            params.completion(.failure(.message(message)))
            return
        }
            
        let fileIndexResult = params.repos.fileIndex.fileIndex(forSharingGroupUUID: sharingGroupUUID)

        switch fileIndexResult {
        case .fileIndex(let fileIndex):
            Log.info("Number of entries in FileIndex: \(fileIndex.count)")
            let response = IndexResponse()
            response.fileIndex = fileIndex
            response.sharingGroups = clientSharingGroups
            params.completion(.success(response))
            
        case .error(let error):
            let message = "Error: \(error)"
            Log.error(message)
            params.completion(.failure(.message(message)))
        }
    }
}
