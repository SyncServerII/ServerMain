//
//  Package.swift
//

import PackageDescription

let package = Package(
    name: "Server",
    targets: [
        Target(name: "Main",
               dependencies: [.Target(name: "Server")]),
        Target(name: "Server")],
    dependencies: [
        .Package(url: "https://github.com/crspybits/SyncServer-Shared.git", majorVersion: 1),

        .Package(url: "https://github.com/crspybits/SMServerLib.git", majorVersion: 0),
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 7),
        
        // 7/2/17; See comment in SwiftMain with the same date.
        // .Package(url: "https://github.com/RuntimeTools/SwiftMetrics.git", majorVersion: 1, minor: 2),
        
		.Package(url: "https://github.com/PerfectlySoft/Perfect.git", majorVersion: 2, minor: 0),
		.Package(url: "https://github.com/PerfectlySoft/Perfect-Thread.git", majorVersion: 2, minor: 0),

		.Package(url:"https://github.com/crspybits/Perfect-MySQL.git", majorVersion: 2, minor: 1),
		
        // .Package(url: "https://github.com/hkellaway/Gloss.git", majorVersion: 1, minor: 2),
		.Package(url: "https://github.com/crspybits/Gloss.git", majorVersion: 1, minor: 2),
		
        .Package(url: "https://github.com/IBM-Swift/Kitura-Credentials.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/IBM-Swift/Kitura-CredentialsFacebook.git", majorVersion: 1, minor: 7),
        .Package(url: "https://github.com/IBM-Swift/Kitura-CredentialsGoogle.git", majorVersion: 1, minor: 7),


        .Package(url: "https://github.com/IBM-Swift/HeliumLogger.git", majorVersion: 1, minor: 7)        
	]
)