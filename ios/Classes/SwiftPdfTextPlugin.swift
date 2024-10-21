import Flutter
import UIKit
import PDFKit

public class SwiftPdfTextPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pdf_text", binaryMessenger: registrar.messenger())
        let instance = SwiftPdfTextPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .default).async {
            if let args = call.arguments as? [String: Any] {
                if call.method == "initDoc" {
                    guard let path = args["path"] as? String,
                          let password = args["password"] as? String else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path or password", details: nil))
                        }
                        return
                    }
                    self.initDoc(result: result, path: path, password: password)
                } else if call.method == "getDocPageText" {
                    guard let path = args["path"] as? String,
                          let password = args["password"] as? String,
                          let pageNumber = args["number"] as? Int else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path, password, or page number", details: nil))
                        }
                        return
                    }
                    self.getDocPageText(result: result, path: path, password: password, pageNumber: pageNumber)
                } else if call.method == "getDocText" {
                    guard let path = args["path"] as? String,
                          let password = args["password"] as? String,
                          let missingPagesNumbers = args["missingPagesNumbers"] as? [Int] else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing path, password, or missingPagesNumbers", details: nil))
                        }
                        return
                    }
                    self.getDocText(result: result, path: path, password: password, missingPagesNumbers: missingPagesNumbers)
                } else {
                    DispatchQueue.main.async {
                        result(FlutterMethodNotImplemented)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid method arguments", details: nil))
                }
            }
        }
    }

    /**
     Initializes the PDF document and returns some information into the channel.
     */
    private func initDoc(result: FlutterResult, path: String, password: String) {
        guard let doc = getDoc(result: result, path: path, password: password) else {
            return
        }
        
        let length = doc.pageCount
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss"

        let attributes = doc.documentAttributes

        let creationDate: String? = {
            if let date = attributes?[PDFDocumentAttribute.creationDateAttribute] as? Date {
                return dateFormatter.string(from: date)
            }
            return nil
        }()
        
        let modificationDate: String? = {
            if let date = attributes?[PDFDocumentAttribute.modificationDateAttribute] as? Date {
                return dateFormatter.string(from: date)
            }
            return nil
        }()

        let data: [String: Any] = [
            "length": length,
            "info": [
                "author": attributes?[PDFDocumentAttribute.authorAttribute],
                "creationDate": creationDate,
                "modificationDate": modificationDate,
                "creator": attributes?[PDFDocumentAttribute.creatorAttribute],
                "producer": attributes?[PDFDocumentAttribute.producerAttribute],
                "keywords": attributes?[PDFDocumentAttribute.keywordsAttribute],
                "title": attributes?[PDFDocumentAttribute.titleAttribute],
                "subject": attributes?[PDFDocumentAttribute.subjectAttribute]
            ]
        ]

        DispatchQueue.main.async {
            result(data)
        }
    }

    /**
     Gets the text of a document page, given its number.
     */
    private func getDocPageText(result: FlutterResult, path: String, password: String, pageNumber: Int) {
        guard let doc = getDoc(result: result, path: path, password: password) else {
            return
        }
        
        // Safely get the page at the specified number
        guard let page = doc.page(at: pageNumber - 1) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "PAGE_NOT_FOUND", message: "Page not found at index \(pageNumber)", details: nil))
            }
            return
        }
        
        // Safely retrieve the text of the page
        let text = page.string ?? ""
        
        // Return the result back to the main thread
        DispatchQueue.main.async {
            result(text)
        }
    }

    /**
     Gets the text of the entire document.
     In order to improve the performance, it only retrieves the pages that are currently missing.
     */
    private func getDocText(result: FlutterResult, path: String, password: String, missingPagesNumbers: [Int]) {
        guard let doc = getDoc(result: result, path: path, password: password) else {
            return
        }

        var missingPagesTexts = [String]()
        for pageNumber in missingPagesNumbers {
            if let page = doc.page(at: pageNumber - 1) {
                let pageText = page.string ?? ""
                missingPagesTexts.append(pageText)
            } else {
                // Append empty text or handle missing pages if necessary
                missingPagesTexts.append("")
            }
        }

        // Return the result back to the main thread
        DispatchQueue.main.async {
            result(missingPagesTexts)
        }
    }

    /**
     Gets a PDF document, given its path.
     */
    private func getDoc(result: FlutterResult, path: String, password: String = "") -> PDFDocument? {
        // Safely initialize the PDFDocument from the file path
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "INVALID_PATH", message: "File path is invalid", details: nil))
            }
            return nil
        }
        
        // Check if the document is locked and try to unlock it with the provided password
        if !doc.unlock(withPassword: password) {
            DispatchQueue.main.async {
                result(FlutterError(code: "INVALID_PASSWORD", message: "The password is invalid", details: nil))
            }
            return nil
        }
        
        return doc
    }
}
