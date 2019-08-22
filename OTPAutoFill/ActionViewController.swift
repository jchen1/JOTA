//
//  ActionViewController.swift
//  OTPAutoFill
//
//  Created by Jeff Chen on 8/21/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit
import MobileCoreServices

class ActionViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    var code: String?

    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Get the item[s] we're handling from the extension context.
        for item in self.extensionContext!.inputItems as! [NSExtensionItem] {
            for provider in item.attachments! {
                if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                    provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { (item, error) in
                        guard let dictionary = item as? NSDictionary else { return }
                        OperationQueue.main.addOperation {
                            if let results = dictionary[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                                // https://twitter.com/account/login_verification?challenge_type=Totp
                                print("da value is... \(results.allKeys), \(results.allValues)")
                                self.code = self.checkOTP(url: URL(string: results.object(forKey: "url")! as! String)!)
                                print("code: \(self.code)")
                            }
                        }
                    })
                }
            }
        }
    }
    
    func checkOTP(url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        let otps = OTPLoader.loadOTPs()
        
        guard let code = try? otps[0].generate() else {
            return nil
        }
        
        return code
        
        // todo check verification URL...
        
    }

    @IBAction func done() {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        let item = NSExtensionItem()
        let jsDict = [ NSExtensionJavaScriptFinalizeArgumentKey :
            [ "id" : "challenge_response",
              "code": code ?? ""
            ]]
        
        print("done!! \(jsDict)")
        
        item.attachments = [ NSItemProvider(item: jsDict as NSSecureCoding, typeIdentifier: kUTTypePropertyList as String)]

        self.extensionContext!.completeRequest(returningItems: [item], completionHandler: nil)
    }

}
