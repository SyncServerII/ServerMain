//
//  ServerTestCase.swift
//  Server
//
//  Created by Christopher Prince on 1/7/17.
//
//

// Base XCTestCase class- has no specific tests.

import Foundation
import XCTest
@testable import Server
import LoggerAPI
import PerfectLib

class ServerTestCase : XCTestCase {
    var db:Database!
    
    // A cloud folder name
    let testFolder = "Test.Folder"
    
    override func setUp() {
        super.setUp()
#if os(macOS)
        Constants.delegate = self
        Constants.setup(configFileName: "ServerTests.json")
#else // Linux
        Constants.setup(configFileFullPath: "../../Private/Server/ServerTests.json")
#endif
        self.db = Database()
        
        _ = UserRepository(db).remove()
        _ = UserRepository(db).create()
        _ = UploadRepository(db).remove()
        _ = UploadRepository(db).create()
        _ = MasterVersionRepository(db).remove()
        _ = MasterVersionRepository(db).create()
        _ = FileIndexRepository(db).remove()
        _ = FileIndexRepository(db).create()
        _ = LockRepository(db).remove()
        _ = LockRepository(db).create()
        _ = DeviceUUIDRepository(db).remove()
        _ = DeviceUUIDRepository(db).create()
        _ = SharingInvitationRepository(db).remove()
        _ = SharingInvitationRepository(db).create()
    }
    
    func addNewUser(deviceUUID:String) {
        self.performServerTest { expectation, googleCreds in
            let headers = self.setupHeaders(accessToken: googleCreds.accessToken, deviceUUID:deviceUUID)
            self.performRequest(route: ServerEndpoints.addUser, headers: headers) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                XCTAssert(response!.statusCode == .OK, "Did not work on addUser request")
                expectation.fulfill()
            }
        }
    }
    
    func uploadTextFile(deviceUUID:String = PerfectLib.UUID().string, fileUUID:String? = nil, addUser:Bool=true, updatedMasterVersionExpected:Int64? = nil, fileVersion:FileVersionInt = 0, masterVersion:Int64 = 0, cloudFolderName:String = "CloudFolder", appMetaData:String? = nil) -> (request: UploadFileRequest, fileSize:Int64) {
        if addUser {
            self.addNewUser(deviceUUID:deviceUUID)
        }
        
        var fileUUIDToSend = ""
        if fileUUID == nil {
            fileUUIDToSend = PerfectLib.UUID().string
        }
        else {
            fileUUIDToSend = fileUUID!
        }
        
        let stringToUpload = "Hello World!"
        let data = stringToUpload.data(using: .utf8)
        
        let uploadRequest = UploadFileRequest(json: [
            UploadFileRequest.fileUUIDKey : fileUUIDToSend,
            UploadFileRequest.mimeTypeKey: "text/plain",
            UploadFileRequest.cloudFolderNameKey: cloudFolderName,
            UploadFileRequest.fileVersionKey: fileVersion,
            UploadFileRequest.masterVersionKey: masterVersion
        ])!
        
        uploadRequest.appMetaData = appMetaData
        
        runUploadTest(data:data!, uploadRequest:uploadRequest, expectedUploadSize:Int64(stringToUpload.characters.count), updatedMasterVersionExpected:updatedMasterVersionExpected, deviceUUID:deviceUUID)
        
        return (request:uploadRequest, fileSize: Int64(stringToUpload.characters.count))
    }
    
    func runUploadTest(data:Data, uploadRequest:UploadFileRequest, expectedUploadSize:Int64, updatedMasterVersionExpected:Int64? = nil, deviceUUID:String) {
        self.performServerTest { expectation, googleCreds in
            let headers = self.setupHeaders(accessToken: googleCreds.accessToken, deviceUUID:deviceUUID)
            
            // The method for ServerEndpoints.uploadFile really must be a POST to upload the file.
            XCTAssert(ServerEndpoints.uploadFile.method == .post)
            
            self.performRequest(route: ServerEndpoints.uploadFile, headers: headers, urlParameters: "?" + uploadRequest.urlParameters()!, body:data) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                XCTAssert(response!.statusCode == .OK, "Did not work on uploadFile request")
                XCTAssert(dict != nil)
                
                if let uploadResponse = UploadFileResponse(json: dict!) {
                    if updatedMasterVersionExpected == nil {
                        XCTAssert(uploadResponse.size != nil)
                        XCTAssert(uploadResponse.size == expectedUploadSize)
                    }
                    else {
                        XCTAssert(uploadResponse.masterVersionUpdate == updatedMasterVersionExpected)
                    }
                }
                else {
                    XCTFail()
                }
                
                // [1]. 2/11/16. Once I put transaction support into mySQL access, I run into some apparent race conditions with using `UploadRepository(self.db).lookup` here. That is, I fail the following check -- but I don't fail if I put a breakpoint here. This has lead me want to implement a new endpoint-- "GetUploads"-- which will enable (a) testing of the scenario below (i.e., after an upload, making sure that the Upload table has the relevant contents), and (b) recovery in an app when the masterVersion comes back different-- so that some uploaded files might not need to be uploaded again (note that for most purposes this later issue is an optimization).
                /*
                // Check the upload repo to make sure the entry is present.
                Log.debug("uploadRequest.fileUUID: \(uploadRequest.fileUUID)")
                let result = UploadRepository(self.db).lookup(key: .fileUUID(uploadRequest.fileUUID), modelInit: Upload.init)
                switch result {
                case .error(let error):
                    XCTFail("\(error)")
                    
                case .found(_):
                    if updatedMasterVersionExpected != nil {
                        XCTFail("No Upload Found")
                    }

                case .noObjectFound:
                    if updatedMasterVersionExpected == nil {
                        XCTFail("No Upload Found")
                    }
                }*/

                expectation.fulfill()
            }
        }
    }
    
    func uploadJPEGFile(deviceUUID:String = PerfectLib.UUID().string, addUser:Bool=true, fileVersion:Int64 = 0) -> (request: UploadFileRequest, fileSize:Int64) {
    
        if addUser {
            self.addNewUser(deviceUUID:deviceUUID)
        }
        
        let fileURL = URL(fileURLWithPath: "/tmp/Cat.jpg")
        let sizeOfCatFileInBytes:Int64 = 1162662
        let data = try! Data(contentsOf: fileURL)
        
        let uploadRequest = UploadFileRequest(json: [
            UploadFileRequest.fileUUIDKey : PerfectLib.UUID().string,
            UploadFileRequest.mimeTypeKey: "image/jpeg",
            UploadFileRequest.cloudFolderNameKey: testFolder,
            UploadFileRequest.fileVersionKey: fileVersion,
            UploadFileRequest.masterVersionKey: 0
        ])
        
        runUploadTest(data:data, uploadRequest:uploadRequest!, expectedUploadSize:sizeOfCatFileInBytes, deviceUUID:deviceUUID)
        
        return (uploadRequest!, sizeOfCatFileInBytes)
    }
    
    func sendDoneUploads(expectedNumberOfUploads:Int32?, deviceUUID:String = PerfectLib.UUID().string, updatedMasterVersionExpected:Int64? = nil, masterVersion:Int64 = 0) {
        self.performServerTest { expectation, googleCreds in
            let headers = self.setupHeaders(accessToken: googleCreds.accessToken, deviceUUID:deviceUUID)
            
            let doneUploadsRequest = DoneUploadsRequest(json: [
                DoneUploadsRequest.masterVersionKey : "\(masterVersion)"
            ])
            
            self.performRequest(route: ServerEndpoints.doneUploads, headers: headers, urlParameters: "?" + doneUploadsRequest!.urlParameters()!, body:nil) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                XCTAssert(response!.statusCode == .OK, "Did not work on doneUploadsRequest request")
                XCTAssert(dict != nil)
                
                if let doneUploadsResponse = DoneUploadsResponse(json: dict!) {
                    XCTAssert(doneUploadsResponse.masterVersionUpdate == updatedMasterVersionExpected)
                    XCTAssert(doneUploadsResponse.numberUploadsTransferred == expectedNumberOfUploads)
                    XCTAssert(doneUploadsResponse.numberDeletionErrors == nil)
                }
                else {
                    XCTFail()
                }
                
                expectation.fulfill()
            }
        }
    }
    
    func getFileIndex(expectedFiles:[UploadFileRequest], deviceUUID:String = PerfectLib.UUID().string, masterVersionExpected:Int64, expectedFileSizes: [String: Int64], expectedDeletionState:[String: Bool]? = nil) {
    
        XCTAssert(expectedFiles.count == expectedFileSizes.count)
        
        self.performServerTest { expectation, googleCreds in
            let headers = self.setupHeaders(accessToken: googleCreds.accessToken, deviceUUID:deviceUUID)
            
            self.performRequest(route: ServerEndpoints.fileIndex, headers: headers, body:nil) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                XCTAssert(response!.statusCode == .OK, "Did not work on fileIndexRequest request")
                XCTAssert(dict != nil)
                
                if let fileIndexResponse = FileIndexResponse(json: dict!) {
                    XCTAssert(fileIndexResponse.masterVersion == masterVersionExpected)
                    XCTAssert(fileIndexResponse.fileIndex!.count == expectedFiles.count)
                    
                    _ = fileIndexResponse.fileIndex!.map { fileInfo in
                        Log.info("fileInfo: \(fileInfo)")
                        
                        let filterResult = expectedFiles.filter { uploadFileRequest in
                            uploadFileRequest.fileUUID == fileInfo.fileUUID
                        }
                        
                        XCTAssert(filterResult.count == 1)
                        let expectedFile = filterResult[0]
                        
                        XCTAssert(expectedFile.appMetaData == fileInfo.appMetaData)
                        XCTAssert(expectedFile.fileUUID == fileInfo.fileUUID)
                        XCTAssert(expectedFile.fileVersion == fileInfo.fileVersion)
                        XCTAssert(expectedFile.mimeType == fileInfo.mimeType)
                        
                        if expectedDeletionState == nil {
                            XCTAssert(fileInfo.deleted == false)
                        }
                        else {
                            XCTAssert(fileInfo.deleted == expectedDeletionState![fileInfo.fileUUID])
                        }
                        
                        XCTAssert(expectedFile.cloudFolderName == fileInfo.cloudFolderName)
                        
                        XCTAssert(expectedFileSizes[fileInfo.fileUUID] == fileInfo.fileSizeBytes)
                    }
                }
                else {
                    XCTFail()
                }
                
                expectation.fulfill()
            }
        }
    }
    
    func getUploads(expectedFiles:[UploadFileRequest], deviceUUID:String = PerfectLib.UUID().string,expectedFileSizes: [String: Int64]? = nil, matchOptionals:Bool = true, expectedDeletionState:[String: Bool]? = nil) {
    
        if expectedFileSizes != nil {
            XCTAssert(expectedFiles.count == expectedFileSizes!.count)
        }
        
        self.performServerTest { expectation, googleCreds in
            let headers = self.setupHeaders(accessToken: googleCreds.accessToken, deviceUUID:deviceUUID)
            
            self.performRequest(route: ServerEndpoints.getUploads, headers: headers, body:nil) { response, dict in
                Log.info("Status code: \(response!.statusCode)")
                XCTAssert(response!.statusCode == .OK, "Did not work on getUploadsRequest request")
                XCTAssert(dict != nil)
                
                if let getUploadsResponse = GetUploadsResponse(json: dict!) {
                    if getUploadsResponse.uploads == nil {
                        XCTAssert(expectedFiles.count == 0)
                        if expectedFileSizes != nil {
                            XCTAssert(expectedFileSizes!.count == 0)
                        }
                    }
                    else {
                        XCTAssert(getUploadsResponse.uploads!.count == expectedFiles.count)
                        
                        _ = getUploadsResponse.uploads!.map { fileInfo in
                            Log.info("fileInfo: \(fileInfo)")
                            
                            let filterResult = expectedFiles.filter { requestMessage in
                                requestMessage.fileUUID == fileInfo.fileUUID
                            }
                            
                            XCTAssert(filterResult.count == 1)
                            let expectedFile = filterResult[0]
                            
                            XCTAssert(expectedFile.fileUUID == fileInfo.fileUUID)
                            XCTAssert(expectedFile.fileVersion == fileInfo.fileVersion)
                            
                            if matchOptionals {
                                XCTAssert(expectedFile.mimeType == fileInfo.mimeType)
                                XCTAssert(expectedFile.appMetaData == fileInfo.appMetaData)
                                
                                if expectedFileSizes != nil {
                                    XCTAssert(expectedFileSizes![fileInfo.fileUUID] == fileInfo.fileSizeBytes)
                                }
                                
                                XCTAssert(expectedFile.cloudFolderName == fileInfo.cloudFolderName)
                            }
                            
                            if expectedDeletionState == nil {
                                XCTAssert(fileInfo.deleted == false)
                            }
                            else {
                                XCTAssert(fileInfo.deleted == expectedDeletionState![fileInfo.fileUUID])
                            }
                        }
                    }
                }
                else {
                    XCTFail()
                }
                
                expectation.fulfill()
            }
        }
    }
}

extension ServerTestCase : ConstantsDelegate {
    // A hack to get access to Server.json during testing.
    public func configFilePath(forConstants:Constants) -> String {
        return "/tmp"
    }
}

