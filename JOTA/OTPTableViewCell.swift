//
//  OTPTableViewCell.swift
//  JOTA
//
//  Created by Jeff Chen on 8/22/19.
//  Copyright © 2019 Jeff Chen. All rights reserved.
//

import UIKit

class OTPTableViewCell: UITableViewCell {

    @IBOutlet weak var otpCodeLabel: UILabel!
    @IBOutlet weak var otpLabelLabel: UILabel!
    @IBOutlet weak var userLabel: UILabel!
    @IBOutlet weak var timeLeftLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
