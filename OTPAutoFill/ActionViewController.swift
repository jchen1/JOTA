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
                                
                                let test = results["test"] as? String
                                print("da value is... \(results.allKeys)")
                            }
                        }
                    })
                }
            }
        }
    }

    @IBAction func done() {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        self.extensionContext!.completeRequest(returningItems: self.extensionContext!.inputItems, completionHandler: nil)
    }

}
