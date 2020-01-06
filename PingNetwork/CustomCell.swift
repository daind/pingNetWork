//
//  CustomCell.swift
//  PingNetwork
//
//  Created by daind on 11/11/19.
//  Copyright © 2019 daind. All rights reserved.
//

import Foundation
import UIKit

class CustomCell: UITableViewCell {
    @IBOutlet weak var cellLabel:UILabel!
    
    func configureCell(item:Item) {
        cellLabel.text = item.text
        cellLabel.backgroundColor = UIColor.clear
        self.cellLabel.sizeToFit()
        cellLabel.adjustsFontSizeToFitWidth = true
    }
    
    
}


