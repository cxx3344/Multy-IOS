//Copyright 2017 Idealnaya rabota LLC
//Licensed under Multy.io license.
//See LICENSE for details

import UIKit

private typealias TableViewDelegate = BTCWalletViewController
private typealias ScrollViewDelegate = BTCWalletViewController
private typealias TableViewDataSource = BTCWalletViewController
private typealias CollectionViewDelegateFlowLayout = BTCWalletViewController
private typealias CancelDelegate = BTCWalletViewController

class BTCWalletViewController: UIViewController, AnalyticsProtocol {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet var backView: UIView!
    @IBOutlet weak var titleLbl: UILabel!
    
    @IBOutlet weak var emptyFirstLbl: UILabel!
    @IBOutlet weak var emptySecondLbl: UILabel!
    @IBOutlet weak var emptyArrowImg: UIImageView!
    
    @IBOutlet weak var headerView: UIView!

    var backupView : UIView?

    @IBOutlet weak var heightOfBottomBar: NSLayoutConstraint!
    @IBOutlet weak var bottomTableConstraint: NSLayoutConstraint!
    @IBOutlet weak var spaceBetweenLblConstant: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    var presenter = BTCWalletPresenter()
    
    var isBackupOnScreen = true
    let progressHUD = ProgressHUD(text: "Getting Wallet...")
    
    var visibleCells = 5  // iphone 6  height 667
    let gradientLayer = CAGradientLayer()
    
    var isSocketInitiateUpdating = false
    
    var lastY: CGFloat = 0.0
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.handleRefresh(_:)), for: UIControlEvents.valueChanged)
        refreshControl.tintColor = UIColor.blue
//        refreshControl.backgroundColor = .blue
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(progressHUD)
        progressHUD.hide()
        
        self.swipeToBack()
        presenter.mainVC = self
        
        presenter.fixConstraints()
        presenter.registerCells()
        checkVisibleCellsWithHetight()
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateExchange), name: NSNotification.Name("exchageUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateWalletAfterSockets), name: NSNotification.Name("transactionUpdated"), object: nil)
        
        self.tableView.addSubview(self.refreshControl)
        self.fixForX()
//        self.fixForPlus()
        self.tableView.backgroundColor = #colorLiteral(red: 0.01194981113, green: 0.4769998789, blue: 0.9994105697, alpha: 1)
        self.tableView.bounces = false
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(screenWalletWithChain)\(presenter.wallet!.chain)")
    }
    
    func checkVisibleCellsWithHetight() {
        if screenHeight == heightOfStandard {
            visibleCells = 5
        } else if screenHeight == heightOfPlus || screenHeight == heightOfX {
            visibleCells = 7
        }
    }
    
    @objc func updateWalletAfterSockets() {
        if isSocketInitiateUpdating {
            return
        }
        
        if !isVisible() {
            return
        }
        
        isSocketInitiateUpdating = true
        
        presenter.getHistoryAndWallet()
    }
    
    func setGradientBackground() {
        self.headerView.backgroundColor = .clear
        let colorTop = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1.0).cgColor
        let colorBottom = UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.1).cgColor
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [ colorTop, colorBottom]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.frame = self.headerView.bounds
        
        self.headerView.layer.insertSublayer(gradientLayer, at: 0)

        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
            if self.tableView.cellForRow(at: [0,0]) == nil {
                return
            }
        } else {
            self.tableView.applyGradient(withColours: [UIColor(ciColor: CIColor(red: 0/255, green: 178/255, blue: 255/255)),
                                                       UIColor(ciColor: CIColor(red: 0/255, green: 122/255, blue: 255/255))],
                                         gradientOrientation: .topRightBottomLeft)
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.tabBar.isHidden = true
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        (self.tabBarController as! CustomTabBarViewController).changeViewVisibility(isHidden: true)
        self.titleLbl.text = self.presenter.wallet?.name
        self.backUpView(height: 272)
        
        self.presenter.getHistoryAndWallet()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        
        super.viewDidDisappear(animated)
    }
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        self.tableView.isUserInteractionEnabled = false
        self.presenter.getHistoryAndWallet()
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(pullWalletWithChain)\(presenter.wallet?.chain)")
    }
    
    @objc func updateExchange() {
        let firstCell = self.tableView.cellForRow(at: [0,0]) as? BTCWalletHeaderTableViewCell
        firstCell?.updateUI()
    }
    
    func updateHistory() {
        if presenter.historyArray.count > 0 {
            hideEmptyLbls()
        }
        
        for cell in self.tableView.visibleCells {
            if cell.isKind(of: TransactionWalletCell.self) {
                if let indexPath = self.tableView.indexPath(for: cell) {
                    (cell as! TransactionWalletCell).changeState(isEmpty: indexPath.row > presenter.numberOfTransactions()) // since we begin transactions from index 1
                    (cell as! TransactionWalletCell).fillCell()
                } else {
                    //How is that possible?
                }
            } else if cell.isKind(of: TransactionPendingCell.self) {
                (cell as! TransactionPendingCell).fillCell()
            }
        }
    }
    
    func backUpView(height: CGFloat) {
        if self.isBackupOnScreen == false {
            if backupView != nil && backupView!.frame.origin.y + 20 != height {
                backupView!.frame = CGRect(x: 16, y: (height /* (screenWidth / 375.0)*/) - 20, width: screenWidth - 32, height: 40)
            }
            return
        }
        backupView = UIView()
        backupView!.frame = CGRect(x: 16, y: (height /* (screenWidth / 375.0)*/) - 20, width: screenWidth - 32, height: 40)
        backupView!.layer.cornerRadius = 20
        backupView!.backgroundColor = .white
        
        backupView!.setShadow(with: #colorLiteral(red: 0.1490196078, green: 0.2980392157, blue: 0.4156862745, alpha: 0.3))
        
        if self.presenter.account?.seedPhrase != nil && self.presenter.account?.seedPhrase != "" {
            backupView!.isHidden = false
        } else {
            backupView!.isHidden = true
        }
        
        if self.view.subviews.contains(backupView!) {
            return
        }
        
        let image = UIImageView()
        image.image = #imageLiteral(resourceName: "warninngBig")
        image.frame = CGRect(x: 13, y: 11, width: 22, height: 22)
        
        let btn = UIButton()
        btn.frame = CGRect(x: 50, y: 0, width: backupView!.frame.width - 35, height: backupView!.frame.height)
        btn.setTitle("Backup is needed!", for: .normal)
        btn.setTitleColor(.red, for: .normal)
        btn.titleLabel?.font = UIFont(name: "Avenir-Next", size: 6)
        btn.contentHorizontalAlignment = .left
        btn.addTarget(self, action: #selector(goToSeed), for: .touchUpInside)
        
        let chevron = UIImageView()
        chevron.image = #imageLiteral(resourceName: "chevronRed")
        chevron.frame = CGRect(x: backupView!.frame.width - 35, y: 15, width: 11, height: 11)
        
        backupView!.addSubview(chevron)
        backupView!.addSubview(btn)
        backupView!.addSubview(image)
        self.tableView.addSubview(backupView!)
        self.isBackupOnScreen = false
    }
    
    @objc func goToSeed() {
        let stroryboard = UIStoryboard(name: "SeedPhrase", bundle: nil)
        let vc = stroryboard.instantiateViewController(withIdentifier: "seedAbout")
        self.navigationController?.pushViewController(vc, animated: true)
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: backupSeedTap)
    }
    
    @IBAction func closeAction() {
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: closeTap)
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func settingsAction(_ sender: Any) {
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(settingsWithChainTap)\(presenter.wallet!.chain)")
        self.performSegue(withIdentifier: "settingsVC", sender: sender)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if #available(iOS 11.0, *) {
            
        } else {
            self.tableView.applyGradient(withColours: [UIColor(ciColor: CIColor(red: 0/255, green: 178/255, blue: 255/255)),
                                                       UIColor(ciColor: CIColor(red: 0/255, green: 122/255, blue: 255/255))],
                                         gradientOrientation: .topRightBottomLeft)
        }
        
        setGradientBackground()
    }
    
    func fixUiWithPendingTransactions() {
        let numberOfPending = presenter.getNumberOfPendingTransactions()
        let numberOfTransactions = presenter.numberOfTransactions()
        if screenHeight == heightOfPlus && numberOfTransactions < 5 {
            if numberOfPending > 2 {
                self.tableView.isScrollEnabled = true
            }
        } else if screenHeight == heightOfStandard && numberOfTransactions < 5 {
            if numberOfPending > 1 {
                self.tableView.isScrollEnabled = true
            }
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        if presenter.wallet!.availableAmount() == 0 {
            self.presentAlert(with: "You have no available funds")
            
            return
        }
        
        let storyboard = UIStoryboard(name: "Send", bundle: nil)
        let sendStartVC = storyboard.instantiateViewController(withIdentifier: "sendStart") as! SendStartViewController
        sendStartVC.presenter.transactionDTO.choosenWallet = self.presenter.wallet
        sendStartVC.presenter.isFromWallet = true
        self.navigationController?.pushViewController(sendStartVC, animated: true)
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(sendWithChainTap)\(presenter.wallet!.chain)")
    }
    
    @IBAction func receiveAction(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Receive", bundle: nil)
        let receiveDetailsVC = storyboard.instantiateViewController(withIdentifier: "receiveDetails") as! ReceiveAllDetailsViewController
        receiveDetailsVC.presenter.wallet = self.presenter.wallet
        self.navigationController?.pushViewController(receiveDetailsVC, animated: true)
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(receiveWithChainTap)\(presenter.wallet!.chain)")
    }
    
    @IBAction func exchangeAction(_ sender: Any) {
        unowned let weakSelf =  self
        self.presentDonationAlertVC(from: weakSelf)
//        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(exchangeWithChainTap)\(presenter.wallet!.chain)")
        logAnalytics()
    }
    
    func logAnalytics() {
        sendDonationAlertScreenPresentedAnalytics(code: donationForExchangeFUNC)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "transactionVC" {
//            let transactionVC = segue.destination as! TransactionViewController
        } else if segue.identifier == "settingsVC" {
            let settingsVC = segue.destination as! WalletSettingsViewController
            settingsVC.presenter.wallet = self.presenter.wallet
        }
    }
    
    func hideEmptyLbls() {
        self.emptyFirstLbl.isHidden = true
        self.emptySecondLbl.isHidden = true
        self.emptyArrowImg.isHidden = true
    }
    
    func fixForiPad() {
        if screenHeight == heightOfiPad {
            hideEmptyLbls()
            self.bottomTableConstraint.constant = -50
        }
    }
    
    func fixForX() {
        if screenHeight == heightOfX {
            self.heightOfBottomBar.constant = 83
            self.spaceBetweenLblConstant.constant = 46
            self.bottomConstraint.constant = 30
        } else if screenHeight == heightOfStandard {
            self.spaceBetweenLblConstant.constant = 100
            self.bottomConstraint.constant = 30
        }
    }
    
    func fixForPlus() {
        if screenHeight == heightOfPlus {
            self.bottomTableConstraint.constant = -50
        }
    }
    
    func updateUI() {
        self.tableView.reloadData()
    }

}


extension CancelDelegate : CancelProtocol {
    func cancelAction() {
        presentDonationVCorAlert()
    }
    
    func presentNoInternet() {
        
    }
}

extension TableViewDelegate: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.presenter.numberOfTransactions() == 0 || indexPath.row == 0 {
            return
        }
        let countOfHistObjs = self.presenter.numberOfTransactions()
        if indexPath.row > countOfHistObjs && countOfHistObjs <= visibleCells {
            return
        }
        
        let storyBoard = UIStoryboard(name: "Wallet", bundle: nil)
        let transactionVC = storyBoard.instantiateViewController(withIdentifier: "transaction") as! TransactionViewController
        transactionVC.presenter.histObj = presenter.historyArray[indexPath.row - 1]
        transactionVC.presenter.blockchainType = BlockchainType.create(wallet: presenter.wallet!)
        transactionVC.presenter.wallet = presenter.wallet!
        self.navigationController?.pushViewController(transactionVC, animated: true)
        sendAnalyticsEvent(screenName: "\(screenWalletWithChain)\(presenter.wallet!.chain)", eventName: "\(transactionWithChainTap)\(presenter.wallet!.chain)")
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath == [0,0] {
            let heightForFirstCell : CGFloat = presenter.blockedAmount == 0 ? 296.0 : 352.0   //value for X
            
            backUpView(height: heightForFirstCell)
            if heightForFirstCell == 332 {
                setGradientBackground()
            }
            
            return heightForFirstCell /* (screenWidth / 375.0)*/
        } else if indexPath == [0,1] && self.presenter.numberOfTransactions() > 0 {
            if indexPath.row <= presenter.numberOfTransactions() && presenter.isTherePendingMoney(for: indexPath) { // <= since we begins from 1
                return 145
            } else {
                return 80
            }
        } else {
            if indexPath.row <= presenter.numberOfTransactions() && presenter.isTherePendingMoney(for: indexPath) { // <= since we begins from 1
                return 135
            } else {
                return 70
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath == [0, 1] {
//            cell.setCorners()
        }
    }
}

extension ScrollViewDelegate: UIScrollViewDelegate {
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let currentY = scrollView.contentOffset.y
        let currentBottomY = scrollView.frame.size.height + currentY
        if currentY <= lastY {
            //"scrolling down"
            tableView.bounces = true
        } else {
            //"scrolling up"
            // Check that we are not in bottom bounce
            if currentBottomY < scrollView.contentSize.height + scrollView.contentInset.bottom {
                tableView.bounces = false
            }
        }
        
        if scrollView.contentOffset.y >= 0 {
            lastY = scrollView.contentOffset.y
        }
    }
}

extension TableViewDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // check number of transactions
        // else return some empty cells
        let countOfHistObjects = self.presenter.numberOfTransactions()
        if countOfHistObjects > 0 {
            self.tableView.isScrollEnabled = true
            if countOfHistObjects < 7 {
                if screenHeight == heightOfX {
                    self.tableView.isScrollEnabled = false
                    return 8
                }
                return 7
            } else {
                return countOfHistObjects + 1
            }
        } else {
            self.tableView.isScrollEnabled = false
            if screenHeight == heightOfX {
                return 13
            }
            return 10
        }
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath == [0, 0] {         // Main Wallet Header Cell
            let headerCell = self.tableView.dequeueReusableCell(withIdentifier: "MainWalletHeaderCellID") as! BTCWalletHeaderTableViewCell
            headerCell.selectionStyle = .none
            headerCell.mainVC = self
            headerCell.delegate = self
            headerCell.wallet = self.presenter.wallet
            headerCell.blockedAmount = presenter.blockedAmount
            
            return headerCell
        } else {                           //  Wallet Cellx
            let countOfHistObjs = self.presenter.numberOfTransactions()
            
            if indexPath.row <= countOfHistObjs && presenter.historyArray[indexPath.row - 1].txStatus.uint32Value == 1 {
                print(presenter.historyArray[indexPath.row - 1])
            }
            
            if indexPath.row <= countOfHistObjs && presenter.isTherePendingMoney(for: indexPath) {
                let walletCell = tableView.dequeueReusableCell(withIdentifier: "TransactionPendingCellID") as! TransactionPendingCell
                walletCell.selectionStyle = .none
                walletCell.histObj = presenter.historyArray[indexPath.row - 1]
                walletCell.wallet = presenter.wallet
                walletCell.fillCell()
                
                return walletCell
            } else {
                let walletCell = self.tableView.dequeueReusableCell(withIdentifier: "TransactionWalletCellID") as! TransactionWalletCell
                walletCell.selectionStyle = .none
                if countOfHistObjs > 0 {
                    if indexPath.row > countOfHistObjs && countOfHistObjs <= visibleCells {
                        walletCell.changeState(isEmpty: true)
                    } else {
                        walletCell.histObj = presenter.historyArray[indexPath.row - 1]
                        walletCell.wallet = presenter.wallet!
                        walletCell.fillCell()
                        walletCell.changeState(isEmpty: false)
                        self.hideEmptyLbls()
                        if indexPath.row != 1 {
                            walletCell.changeTopConstraint()
                        }
                    }
                } else {
                    walletCell.changeState(isEmpty: true)
                    fixForiPad()
                }
                
                return walletCell
            }
        }
    }
}

extension CollectionViewDelegateFlowLayout : UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let heightForFirstCell : CGFloat = presenter.blockedAmount == 0 ? 190.0 : 250.0
        
        return CGSize(width: screenWidth, height: heightForFirstCell)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsetsMake(0, 0, 0, 0)
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
