//
//  Download.swift
//  SyncServer
//
//  Created by Christopher Prince on 2/23/17.
//
//

import Foundation
import SMCoreLib

class Download {
    static let session = Download()
    
    private init() {
    }
    
    enum CheckCompletion {
    case noDownloadsOrDeletionsAvailable
    case downloadsOrDeletionsAvailable(numberOfFiles:Int32)
    case error(Error)
    }
    
    // TODO: *0* while this check is occuring, we want to make sure we don't have a concurrent check operation.
    // Creates DownloadFileTracker's to represent files that need downloading/download deleting. Updates MasterVersion with the master version on the server.
    func check(completion:((CheckCompletion)->())? = nil) {
        ServerAPI.session.fileIndex { (fileIndex, masterVersion, error) in
            guard error == nil else {
                completion?(.error(error!))
                return
            }

            let (fileDownloads, downloadDeletions) = Directory.session.checkFileIndex(fileIndex: fileIndex!)

            MasterVersion.get().version = masterVersion!
            
            if fileDownloads == nil && downloadDeletions == nil {
                CoreData.sessionNamed(Constants.coreDataName).saveContext()
                completion?(.noDownloadsOrDeletionsAvailable)
            }
            else {
                let allFiles = (fileDownloads ?? []) + (downloadDeletions ?? [])
                for file in allFiles {
                    if file.fileVersion != 0 {
                        // TODO: *5* We're considering this an error currently because we're not yet supporting multiple file versions.
                        assert(false, "Not Yet Implemented: Multiple File Versions")
                    }
                    
                    let dft = DownloadFileTracker.newObject() as! DownloadFileTracker
                    dft.fileUUID = file.fileUUID
                    dft.fileVersion = file.fileVersion
                    dft.deletedOnServer = file.deleted!
                }
                
                CoreData.sessionNamed(Constants.coreDataName).saveContext()

                completion?(.downloadsOrDeletionsAvailable(numberOfFiles: Int32(allFiles.count)))
            }
        }
    }

    enum NextResult {
    case started
    case noDownloadsOrDeletions
    case allDownloadsCompleted
    case error(String)
    }
    
    enum NextCompletion {
    case downloaded(DownloadFileTracker)
    case masterVersionUpdate
    case error(String)
    }
    
    // Starts download of next file, if there is one. There should be no files downloading already. Only if .startedDownload is the NextResult will the completion handler be called. With a masterVersionUpdate response for NextCompletion, the MasterVersion Core Data object is updated by this method, and all the DownloadFileTracker objects have been reset.
    func next(completion:((NextCompletion)->())?) -> NextResult {
        let dfts = DownloadFileTracker.fetchAll()
        if dfts.count == 0 {
            return .noDownloadsOrDeletions
        }

        let alreadyDownloading = dfts.filter {$0.status == .downloading}
        if alreadyDownloading.count != 0 {
            let message = "Already downloading a file!"
            Log.error(message)
            return .error(message)
        }
        
        let notStarted = dfts.filter {$0.status == .notStarted && $0.deletedOnServer == false}
        if notStarted.count == 0 {
            return .allDownloadsCompleted
        }
        
        let nextToDownload = notStarted[0]

        let masterVersion = MasterVersion.get().version
        ServerAPI.session.downloadFile(file: nextToDownload as! Filenaming, serverMasterVersion: masterVersion) { (result, error)  in
            guard error == nil else {
                Synchronized.block(nextToDownload) {
                    nextToDownload.status = .notStarted
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                
                let message = "Error: \(error)"
                Log.error(message)
                completion?(.error(message))
                return
            }
            
            switch result! {
            case .success(let downloadedFile):
                Synchronized.block(nextToDownload) {
                    nextToDownload.status = .downloaded
                    nextToDownload.appMetaData = downloadedFile.appMetaData
                    nextToDownload.fileSizeBytes = downloadedFile.fileSizeBytes
                    nextToDownload.localURL = downloadedFile.url
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                completion?(.downloaded(nextToDownload))
                
            case .serverMasterVersionUpdate(let masterVersionUpdate):
                Synchronized.block(nextToDownload) {
                    // TODO: *2* A more efficient method (than in place here) is to get the file index, giving us the new masterVersion, and see which files that we have already downloaded have the same version as we expect.
                    // The simplest method to deal with this is to restart all downloads. It is insufficient to just reset all of the DownloadFileTracker objects: Because some of the files we're wanting to download could have been marked as deleted in the FileIndex on the server. Thus, I'm going to remove all DownloadFileTracker objects.

                    DownloadFileTracker.removeAll()
                    MasterVersion.get().version = masterVersionUpdate
                    CoreData.sessionNamed(Constants.coreDataName).saveContext()
                }
                completion?(.masterVersionUpdate)
            }
        }
        
        Synchronized.block(nextToDownload) {
            nextToDownload.status = .downloading
            CoreData.sessionNamed(Constants.coreDataName).saveContext()
        }
        
        return .started
    }
}
