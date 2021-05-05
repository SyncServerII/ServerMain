//
//  ReadOnlyCloudStorage.swift
//  Server
//
//  Created by Christopher G Prince on 5/2/21.
//

// A limited form of Cloud storage providing reading only, for testing.

import Foundation
import ServerAccount

class ReadOnlyCloudStorage: CloudStorage {
    let cloudStorage: CloudStorage
    
    init(cloudStorage: CloudStorage) {
        self.cloudStorage = cloudStorage
    }
    
    enum ReadOnlyStorageError: Error {
        case readOnly
    }
    
    func uploadFile(cloudFileName:String, data:Data, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<String>)->()) {
        completion(.failure(ReadOnlyStorageError.readOnly))
    }
    
    func downloadFile(cloudFileName:String, options:CloudStorageFileNameOptions?, completion:@escaping (DownloadResult)->()) {
        cloudStorage.downloadFile(cloudFileName: cloudFileName, options: options, completion: completion)
    }
    
    func deleteFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<()>)->()) {
        completion(.failure(ReadOnlyStorageError.readOnly))
    }

    func lookupFile(cloudFileName:String, options:CloudStorageFileNameOptions?,
        completion:@escaping (Result<Bool>)->()) {
        cloudStorage.lookupFile(cloudFileName: cloudFileName, options: options, completion: completion)
    }
}
