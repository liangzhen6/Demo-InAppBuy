//
//  ViewController.swift
//  InAppBuy
//
//  Created by shenzhenshihua on 2018/3/19.
//  Copyright © 2018年 shenzhenshihua. All rights reserved.
//

import UIKit
import StoreKit

class ViewController: UIViewController,SKProductsRequestDelegate,SKPaymentTransactionObserver {

    let SandboxUrl = "https://sandbox.itunes.apple.com/verifyReceipt"//测试
    let AppPurchaseUrl = "https://buy.itunes.apple.com/verifyReceipt"//正式版
    let ThreeMonthsOfPurchase = "yzzk.sub_3m" //购买三个月
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SKPaymentQueue.default().add(self)
        // Do any additional setup after loading the view, typically from a nib.
    }

    
    @IBAction func reBuyAction(_ sender: Any) {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    @IBAction func buyAction(_ sender: Any) {
        buy()
    }
    
    func buy() {
        if SKPaymentQueue.canMakePayments() {
            let set = NSSet.init(array: [ThreeMonthsOfPurchase])
            let request = SKProductsRequest.init(productIdentifiers: set as! Set<String>)
            request.delegate = self
            request.start()
        } else {
            //用户没有开启内购
            print("用户没有开启内购")
        }
    }
    
    //购买商品
    func buySome(product:SKProduct) {
        let payment = SKPayment.init(product: product)
        
        SKPaymentQueue.default().add(payment)
        
    }
    
    //MARK:-- SKProductsRequestDelegate --
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.products.isEmpty {
            //产品id存在
            let product = response.products.first
            buySome(product: product!)
        } else {
            print("无商品")
        }
    }
    
    
    //MARK: -- SKPaymentTransactionObserver --
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch(transaction.transactionState){
                
            case .purchasing:
                print("商品加入列表")
                
            case .purchased:
                //交易完成
                SKPaymentQueue.default().finishTransaction(transaction)
                verifyFinishedWithTransaction(transaction: transaction)
            case .failed:
                //交易失败
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                //已经购买过， 恢复购买走这里
                SKPaymentQueue.default().finishTransaction(transaction)
                verifyFinishedWithTransaction(transaction: transaction)
            case .deferred:
                //等待中。。。
                print("等待中。。。")
            }
        }
        
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        print("购买失败\(error)")
    }
    
    /*
     苹果反馈的状态码；
     
     21000 App Store无法读取你提供的JSON数据
     21002 收据数据不符合格式 （踩过坑，越狱机会出现）
     21003 收据无法被验证
     21004 你提供的共享密钥和账户的共享密钥不一致
     21005 收据服务器当前不可用
     21006 收据是有效的，但订阅服务已经过期。当收到这个信息时，解码后的收据信息也包含在返回内容中
     21007 收据信息是测试用（sandbox），但却被发送到产品环境中验证
     21008 收据信息是产品环境中使用，但却被发送到测试环境中验证
     
     //验证需要注意点
     为保证审核的通过，需要在客户端或server进行双重验证，即，先以线上交易验证地址进行验证，如果苹果正式验证服务器的返回验证码code为21007，则再一次连接沙盒测试服务器进行验证即可。在应用提审时，苹果IAP提审验证时是在沙盒环境的进行的，即：苹果在审核App时，只会在sandbox环境购买，其产生的购买凭证，也只能连接苹果的测试验证服务器，如果没有做双验证，需要特别注意此问题，否则会被拒。
     status = 21007
     校验成功 不会有status码
     
     //App 专用共享密钥  如果没有这个数据校验是错误 21004
     //如何获得？ itunes content->功能->App内购买项目->App专用共享密钥
     NSString * theString = @"7bd3e766df954e2f9532b35a3a03fd3e";
     
     */
    //MARK: --- 去苹果服务器校验购买数据 ---
    func verifyFinishedWithTransaction(transaction:SKPaymentTransaction) {
        if transaction.transactionState == .purchased || transaction.transactionState == .restored {
            //是购买完成 或者 是恢复购买状态
            let url = Bundle.main.appStoreReceiptURL
            do {
                let receipt = try Data.init(contentsOf: url!)
                guard !receipt.isEmpty else { return }
                
                let base64_receipt = receipt.base64EncodedString(options: .endLineWithLineFeed)
                var params = Dictionary.init() as [String:Any]
                params["receipt-data"] = base64_receipt
                params["password"] = "7bd3e766df954e2f9532b35a3a03fd3e"
                httpRequest(urlString: AppPurchaseUrl, params: params, comple: { (result) in
                    if !result.isEmpty {
                        let number = result["status"] as! Float
                        
                        if number == 21007 {
                        //失败 换成测试模式
                            self.handleVerifySandbox(params: params)
                        } else {
                            print("校验成功！！！AppPurchaseUrl")
                        }
                    }
                })

            } catch {
                print("异常抛出")
            }
            
        }
    }
    
    //MARK:---- 处理是沙盒测试的情况 ----
    func handleVerifySandbox(params:[String:Any]) {
        httpRequest(urlString: SandboxUrl, params: params) { (result) in
            if !result.isEmpty {
                let number = result["status"] as! Float
                
                if number == 21007 {
                    //失败 换成测试模式
                    
                } else {
                    print("校验成功！！！SandboxUrl")
                }
            }
        }
    }
    //MARK:--- 网络请求 ---
    func httpRequest(urlString:String, params:[String:Any], comple:@escaping (_ result:[String:Any])->()) {
        let session = URLSession.shared
        let url = URL.init(string: urlString)
        var request = URLRequest.init(url: url!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        do {
        let josnData = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
            let jsstring = String.init(data: josnData, encoding: .utf8)
            request.httpBody = jsstring?.data(using: .utf8)
            session.dataTask(with: request, completionHandler: { (data, respon, error) in
                if error == nil {
                    do {
                        let dict = try JSONSerialization.jsonObject(with: data!, options: .allowFragments) as! [String:Any]
                        if !dict.isEmpty {
                            print(dict)
                            comple(dict)
                        }
                        
                    } catch {
                        print("出现错误")
                    }
                    
                }
                
            }).resume()
            
        } catch {
            print("出现错误")
        }
        
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func delete(_ sender: Any?) {
        //移除监听
        SKPaymentQueue.default().remove(self)
    }

}

