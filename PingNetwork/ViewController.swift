//
//  ViewController.swift
//  PingNetwork
//
//  Created by daind on 10/21/19.
//  Copyright © 2019 daind. All rights reserved.
//

import UIKit
import CoreData
import GoogleMobileAds


class ViewController: UIViewController, SimplePingDelegate, UITextFieldDelegate, GADBannerViewDelegate {
    
    lazy var adBannerView: GADBannerView = {
        let adBannerView = GADBannerView(adSize: kGADAdSizeSmartBannerPortrait)
        adBannerView.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        adBannerView.delegate = self
        adBannerView.rootViewController = self
        return adBannerView
    }()
    
    var interstitial: GADInterstitial?
    
    var arrayOfItems:[Item] = [Item]()
    var emptyDict: [UInt16: Double] = [:]

    @IBOutlet weak var startText: UIButton!
    @IBAction func pingData(_ sender: Any) {
        if (startText.currentTitle == "Ping") {
            self.start()
        } else {
            self.stop()
        }
        
    }
    @IBOutlet weak var inputText: UITextField!
    
    @IBOutlet weak var tableViewPing: UITableView!
    
    @IBOutlet weak var titlePing: UILabel!
    var autoCompletionPossibilities = ["google.com", "facebook.com"]
    
    let userDefaults = UserDefaults.standard
    struct Keys {
        static let address  = "address"
        static let firstRun = "firstRun"
    }
    
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewPing.contentInset = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        tableViewPing.separatorStyle = .none
        startText.layer.cornerRadius = 5;
        self.inputText.text = "google.com"
        checkForFirstRun()
        
        print(userDefaults.object(forKey: Keys.address) as? [String] ?? [String]())
        
        // Request a Google Ad
        adBannerView.load(GADRequest())
    }
    
    
    var pinger: SimplePing?
    var sendTimer: Timer?
    
    func start() {
        // reset data
        arrayOfItems.removeAll()
        tableViewPing.reloadData()
        
        self.pingerWillStart()
        
        NSLog("start")
        
        let pinger = SimplePing(hostName: inputText.text!)
        self.pinger = pinger
        pinger.addressStyle = .any
        
        pinger.delegate = self
        pinger.start()
        addAddress()
        

    }
    
    func stop() {
        NSLog("stop")
        
        self.pinger?.stop()
        self.pinger = nil
        
        self.sendTimer?.invalidate()
        self.sendTimer = nil
        
        self.pingerDidStop()
    }
    
    // send a ping
    // called to send a ping, both directly and via a time
    
    @objc func sendPing() {
        self.pinger!.send(with: nil)
    }
    
    // MARK: pinger delegate callback
    var fromPing: String=""
    func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        NSLog("pinging %@", ViewController.displayAddressForAddress(address: address as NSData))
        fromPing = ViewController.displayAddressForAddress(address: address as NSData)
        
        // add title
        let title = "PING " + inputText.text! + "( " + fromPing + "):"
        titlePing.text = title
        
        // send the first ping straight way
        self.sendPing()
        
        // and start a timer to send the subsequent pings
        assert(self.sendTimer == nil)
        
        self.sendTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(ViewController.sendPing), userInfo: nil, repeats: true)
    }
    
    func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        NSLog("failed: %@", ViewController.shortErrorFromError(error: error as NSError))
        removeAddress()
        let variableString = "ping: cannot resolve " + inputText.text! + ": " + ViewController.shortErrorFromError(error: error as NSError)
        arrayOfItems.insert(Item(text: variableString), at: 0)
        tableViewPing.reloadData()
        self.stop()
    }
    
    var sentTime: TimeInterval = 0
    func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        sentTime = Date().timeIntervalSince1970
        emptyDict[sequenceNumber] = sentTime
        print(emptyDict)
        for (sequence, value) in emptyDict {
            if Int(((Date().timeIntervalSince1970 - value).truncatingRemainder(dividingBy: 1)) * 1000) > 3000 {
                // time out
                emptyDict.removeValue(forKey: sequence)
                 let messageTimeOut = "Request timeout for icmp_seq " + String(sequenceNumber)
                arrayOfItems.append(Item(text: messageTimeOut))
                tableViewPing.reloadData()
                let lastRowIndex = self.tableViewPing!.numberOfRows(inSection: 0) - 1
                let pathToLastRow = IndexPath.init(row: lastRowIndex, section: 0)
                tableViewPing.scrollToRow(at: pathToLastRow, at: .none, animated: true)
            }
        }
        
        NSLog("#%u sent", sequenceNumber)
    }
    
    func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        NSLog("#%u send failed: %@", sequenceNumber, ViewController.shortErrorFromError(error: error as NSError))
        let var1 = "ping: sendTo: " + String(ViewController.shortErrorFromError(error: error as NSError));
        let var2 = "Request timeout for icmp_seq " + String(sequenceNumber)
        
        arrayOfItems.insert(Item(text: var1), at: 0)
        arrayOfItems.insert(Item(text: var2), at: 0)
        tableViewPing.reloadData()
    }
    
    func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        let some = Int(((Date().timeIntervalSince1970 - sentTime).truncatingRemainder(dividingBy: 1)) * 1000)
        print("PING: \(some) MS")
        NSLog("#%u received, %@, size=%zu",  sequenceNumber, fromPing, packet.count)
        
        emptyDict.removeValue(forKey: sequenceNumber)
        
        var variableString = "Replay from "
        variableString += fromPing + ": icmp_seq=" + String(sequenceNumber) + " ttl="
        variableString += String(pinger.timeToLiveProperty) + " time=" + String(some) + " ms"
        
        arrayOfItems.append(Item(text: variableString))
        tableViewPing.reloadData()
        let lastRowIndex = self.tableViewPing!.numberOfRows(inSection: 0) - 1
        let pathToLastRow = IndexPath.init(row: lastRowIndex, section: 0)
        tableViewPing.scrollToRow(at: pathToLastRow, at: .none, animated: true)
    }
    
    func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        NSLog("unexpected packet, size=%zu", packet.count)
    }
    
    // MARK: Utilities
    // Returns the string representiation of the supplied address.
    // - param address: Contains a `(struct sockaddr) with the address to render
    // - return: A string representation of that address
    
    static func displayAddressForAddress(address: NSData) -> String {
        var hostStr = [Int8] (repeating: 0, count: Int(NI_MAXHOST))
        
        let success = getnameinfo(address.bytes.assumingMemoryBound(to: sockaddr.self)
            , socklen_t(address.length), &hostStr, socklen_t(hostStr.count), nil, 0, NI_NUMERICHOST) == 0
        let result: String
        if success {
            result = String(cString: hostStr)
        } else {
            result = "?"
        }
        return result
    }
    
    // returns a short error string for the supplied error.
    static func shortErrorFromError(error: NSError) -> String {
        if error.domain == kCFErrorDomainCFNetwork as String && error.code == Int(CFNetworkErrors.cfHostErrorUnknown.rawValue) {
            if let failureObj = error.userInfo[kCFGetAddrInfoFailureKey as String] {
                if let failureNum = failureObj as? NSNumber {
                    if failureNum.intValue != 0 {
                        let f = gai_strerror(Int32(failureNum.intValue))
                        if f != nil {
                            return String(cString: f!)
                        }
                    }
                }
            }
        }
        if let result = error.localizedFailureReason {
            return result
        }
        return error.localizedDescription
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func pingerWillStart() {
        self.startText.setTitle("Stop", for: .normal)
    }
    
    func pingerDidStop() {
        self.startText.setTitle("Ping", for: .normal)

    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool { //1
        var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string) // 2
        subString = formatSubstring(subString: subString)
        
        if subString.count == 0 { // 3 when a user clears the textField
            resetValues()
        } else {
            searchAutocompleteEntriesWIthSubstring(substring: subString) //4
        }
        return true
    }
    func formatSubstring(subString: String) -> String {
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased() //5
        return formatted
    }
    
    func resetValues() {
        autoCompleteCharacterCount = 0
        inputText.text = ""
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring) //1
        
        if suggestions.count > 0 {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in //2
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions) // 3
                self.putColourFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery) //4
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery) //5
            })
        } else {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in //7
                self.inputText.text = substring
            })
            autoCompleteCharacterCount = 0
        }
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        var possibleMatches: [String] = []
        for item in userDefaults.object(forKey: Keys.address) as? [String] ?? [String]() { //2
            let myString:NSString! = item as NSString
            let substringRange :NSRange! = myString.range(of: userText)
            
            if (substringRange.location == 0)
            {
                possibleMatches.append(item)
            }
        }
        return possibleMatches
    }
    
    func putColourFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        let colouredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        colouredString.addAttribute(NSAttributedString.Key.foregroundColor, value: UIColor.green, range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        self.inputText.attributedText = colouredString
    }
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        if let newPosition = self.inputText.position(from: self.inputText.beginningOfDocument, offset: userQuery.count) {
            self.inputText.selectedTextRange = self.inputText.textRange(from: newPosition, to: newPosition)
        }
        let selectedRange: UITextRange? = inputText.selectedTextRange
        inputText.offset(from: inputText.beginningOfDocument, to: (selectedRange?.start)!)
    }
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
    }
    
    func addAddress() {
        var addressArray = userDefaults.object(forKey: Keys.address) as? [String] ?? [String]()
        if !addressArray.contains(inputText.text!) {
            addressArray.append(inputText.text!)
            userDefaults.set(addressArray, forKey: Keys.address)
        }
    }
    func removeAddress() {
        var addressArray = userDefaults.object(forKey: Keys.address) as? [String] ?? [String]()
        print(addressArray)
        addressArray.removeLast()
        print(addressArray)
        userDefaults.set(addressArray, forKey: Keys.address)
    }
    
    func checkForFirstRun() {
        let firstRun = userDefaults.bool(forKey: Keys.firstRun)
        if !firstRun {
            userDefaults.set(autoCompletionPossibilities, forKey: Keys.address)
            print(userDefaults.object(forKey: Keys.address) as? [String] ?? [String]())
            userDefaults.set(true, forKey: Keys.firstRun)

        }
    }
    
    // mark for GADBanner
    
    func adViewDidReceiveAd(_ bannerView: GADBannerView) {
        print("Banner loaded successfully")
        tableViewPing.tableHeaderView?.frame = bannerView.frame
        tableViewPing.tableHeaderView = bannerView
        
    }
     
    func adView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: GADRequestError) {
        print("Fail to receive ads")
        print(error)
    }


}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrayOfItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCellIdentifier") as? CustomCell {
            cell.configureCell(item: arrayOfItems[indexPath.row])
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}


