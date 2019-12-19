//
//  APIClient.swift
//  PingNetwork
//
//  Created by daind on 11/13/19.
//  Copyright © 2019 daind. All rights reserved.
//
import Foundation
import UIKit

class APIClient {
    
    func getData() ->[Item] {
        var array: [Item] = [Item]()
        
        let item1 = Item(text:"Settings")
        let item2 = Item(text:"Coins")
        let item3 = Item(text:"Usage")
        
        array.append(item1)
        array.append(item2)
        array.append(item3)
        
        return array
    }
}
