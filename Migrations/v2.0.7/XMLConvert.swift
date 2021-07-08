#!/usr/bin/swift

// Convert XML format files into a form I can ship to the server for table insertion.

import Foundation

class XMLConvert: NSObject {
    let parser: XMLParser
    let tableName: String
    var currentColumnNames = [String]()
    var currentColumnValues = [String]()
    var expectingValue = false
    var currentColumnValue = ""
    
    enum XMLConvertError: Error {
        case badFileName
        case couldNotOpenXMLFile
    }
    
    init(xmlFile: URL, tableName: String) throws {
        self.tableName = tableName
        
        guard let parser = XMLParser(contentsOf: xmlFile) else {
            print("Usage: Could not open XML file: \(xmlFile)")
            throw XMLConvertError.couldNotOpenXMLFile
        }
        
        self.parser = parser
        super.init()
        
        self.parser.delegate = self
        let result = self.parser.parse()
        if (!result) {
            print("ERROR!!")
        }
    }
}

extension XMLConvert: XMLParserDelegate {
    func parserDidStartDocument(_ parser: XMLParser) {
    }

    func parserDidEndDocument(_ parser: XMLParser) {
    }

    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
    }

    
    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) {
    }

    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) {
        //print("foundAttributeDeclarationWithName: \(attributeName)")
    }

    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
        //print("foundElementDeclarationWithName: \(elementName)")
    }
    
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
    
        switch elementName {
        case "row":
            currentColumnNames = []
            currentColumnValues = []
            expectingValue = false
            currentColumnValue = ""
            
        case "field":
            if let columnName = attributeDict["name"] {
                currentColumnNames += [columnName]
            }

            /* <field name="appMetaData" xsi:nil="true" />
            */
            if let columnValue = attributeDict["xsi:nil"], columnValue == "true" {
                currentColumnValues += ["NULL"]
            }
            else {
                expectingValue = true
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
    
        switch elementName {
        case "row":
            let columns = currentColumnNames.joined(separator: ", ") + ", owningUserId"
            let values = currentColumnValues.joined(separator: ", ") + ", \(currentColumnValues[0])"
            print("INSERT INTO \(tableName) (\(columns)) VALUES (\(values));")
            
        case "field":
            if currentColumnValue.count > 0 {
                currentColumnValues += ["'\(currentColumnValue)'"]
                currentColumnValue = ""
                expectingValue = false
            }
            
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
    }

    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
    }

    /* Deal with values like `text/plain` in:
       <field name="mimeType">text/plain</field>
    */
    func parser(_ parser: XMLParser, foundCharacters string: String) {
//        let trimmed = string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
//        if trimmed.count > 0 {
//            currentColumnValues += ["'\(trimmed)'"]
//        }
        
        if expectingValue {
            currentColumnValue += string
        }
    }

    func parser(_ parser: XMLParser, foundIgnorableWhitespace whitespaceString: String) {
    }

    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
    }

    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        return nil
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("parseErrorOccurred")
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        print("validationErrorOccurred")
    }
}

do {
    guard CommandLine.arguments.count == 3 else {
        print("Usage: TableName filename.xml")
        exit(1)
    }

    let tableName = CommandLine.arguments[1]
    let xmlFile = URL(fileURLWithPath: CommandLine.arguments[2])
    let _ = try XMLConvert(xmlFile: xmlFile, tableName: tableName)
} catch let error {
    print("Error: \(error)")
}
