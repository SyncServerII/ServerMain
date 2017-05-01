//
//  FileController_UploadTests.swift
//  Server
//
//  Created by Christopher Prince on 3/22/17.
//
//

import XCTest
@testable import Server
import LoggerAPI
import PerfectLib
import Foundation

class FileController_UploadTests: ServerTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testUploadTextFile() {
        _ = uploadTextFile()
    }
    
    func testUploadJPEGFile() {
        _ = uploadJPEGFile()
    }
    
    func testUploadTextAndJPEGFile() {
        let deviceUUID = PerfectLib.UUID().string
        _ = uploadTextFile(deviceUUID:deviceUUID)
        _ = uploadJPEGFile(deviceUUID:deviceUUID, addUser:false)
    }
    
    func testUploadingSameFileTwiceWorks() {
        let deviceUUID = PerfectLib.UUID().string
        let (request, _) = uploadTextFile(deviceUUID:deviceUUID)
        
        // Second upload.
        _ = uploadTextFile(deviceUUID: deviceUUID, fileUUID: request.fileUUID, addUser: false, fileVersion: request.fileVersion, masterVersion: request.masterVersion, cloudFolderName: request.cloudFolderName, appMetaData: request.appMetaData)
    }

    func testUploadTextFileWithStringWithSpacesAppMetaData() {
        _ = uploadTextFile(appMetaData:"A Simple String")
    }
    
    func testUploadTextFileWithJSONAppMetaData() {
        _ = uploadTextFile(appMetaData:"{ \"foo\": \"bar\" }")
    }
}