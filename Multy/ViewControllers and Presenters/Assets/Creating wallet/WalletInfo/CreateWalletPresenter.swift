//Copyright 2017 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import UIKit
import Firebase

class CreateWalletPresenter: NSObject {
    weak var mainVC: CreateWalletViewController?
    var account : AccountRLM?
    var blockchainType = BlockchainType.create(currencyID: 0, netType: 0)
//
    func makeAuth(completion: @escaping (_ answer: String) -> ()) {
        if self.account != nil {
            return
        }
        
        DataManager.shared.auth(rootKey: nil) { (account, error) in
//            self.assetsVC?.view.isUserInteractionEnabled = true
//            self.assetsVC?.progressHUD.hide()
            guard account != nil else {
                return
            }
            self.account = account
            DataManager.shared.socketManager.start()
            completion("ok")
        }
    }
    
    func createNewWallet(completion: @escaping (_ dict: Dictionary<String, Any>?) -> ()) {
        if account == nil {
//            print("-------------ERROR: Account nil")
//            return
            self.makeAuth(completion: { (answer) in
                self.create()
            })
        } else {
            self.create()
        }
    }
    
    func create() {
        var binData : BinaryData = account!.binaryDataString.createBinaryData()!
        //MARK: topIndex
        let currencyID = blockchainType.blockchain.rawValue
        let networkID = blockchainType.net_type
        let currentTopIndex = account!.topIndexes.filter("currencyID = \(currencyID) AND networkID == \(networkID)").first
        
        if currentTopIndex == nil {
            mainVC?.presentAlert(with: "TopIndex error data!")
            
            return
        }
        
        let dict = DataManager.shared.createNewWallet(for: &binData, currencyID + 60, walletID: currentTopIndex!.topIndex.uint32Value + 1)
        let cell = mainVC?.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as! CreateWalletNameTableViewCell
        let params = [
            "currencyID"    : dict!["currency"] as! UInt32,
            "address"       : dict!["address"] as! String,
            "addressIndex"  : dict!["addressID"] as! UInt32,
            "walletIndex"   : dict!["walletID"] as! UInt32,
            "walletName"    : cell.walletNameTF.text ?? "Wallet"
            ] as [String : Any]
        
        DataManager.shared.addWallet(params: params) { (dict, error) in
            if error == nil {
                print(dict as Any)
                self.mainVC?.cancleAction(UIButton())
            } else {
                self.mainVC?.progressHUD.hide()
                self.mainVC?.presentAlert(with: "Error while creating wallet!")
            }
        }
    }
}
