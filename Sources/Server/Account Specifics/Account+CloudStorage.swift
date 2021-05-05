//
//  Account+CloudStorage.swift
//  Server
//
//  Created by Christopher G Prince on 8/15/20.
//

import Foundation
import ServerAccount
import LoggerAPI

extension Account {
    // Pass as the `mock` the MockStorage if you are using it.
    func cloudStorage(mock: CloudStorage?) -> CloudStorage? {
        var useMockStorage: Bool {
#if DEBUG
#if DEBUG && MOCK_STORAGE
            return true
#endif
            if let loadTesting = Configuration.server.loadTestingCloudStorage, loadTesting {
                return true
            }
#endif
            return false
        }
        
        var useReadOnlyStorage: Bool {
#if DEBUG
            if let readonlyCloudStorage = Configuration.server.readonlyCloudStorage, readonlyCloudStorage {
                return true
            }
#endif
            return false
        }

        Log.debug("cloudStorage: useMockStorage: \(useMockStorage)")
        Log.debug("cloudStorage: useReadOnlyStorage: \(useReadOnlyStorage)")
        
        if useMockStorage {
            return mock
        }
        else if let cloudStorage = self as? CloudStorage {
            if useReadOnlyStorage {
                return ReadOnlyCloudStorage(cloudStorage: cloudStorage)
            }
            else {
                return cloudStorage
            }
        }
        else {
            return nil
        }
    }
}

