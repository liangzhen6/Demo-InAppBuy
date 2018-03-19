//
//  ViewController.m
//  InAppBuy
//
//  Created by shenzhenshihua on 2018/3/16.
//  Copyright © 2018年 shenzhenshihua. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>
#define SandboxUrl        @"https://sandbox.itunes.apple.com/verifyReceipt"//测试
#define AppPurchaseUrl    @"https://buy.itunes.apple.com/verifyReceipt" //正式

#define ThreeMonthsOfPurchase  @"yzzk.sub_3m" //购买三个月 yzzk_23_41
//#define ThreeMonthsOfPurchase  @"yzzk_23_41" //单期购买
@interface ViewController ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //设置监听
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // Do any additional setup after loading the view, typically from a nib.
}

//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    
//}
- (IBAction)btnAction:(id)sender {
    [self buy];

}
- (IBAction)reBuyAction:(id)sender {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];

}

- (void)buy {
    if ([SKPaymentQueue canMakePayments]) {
        //可以购买
        NSSet * set = [NSSet setWithArray:@[ThreeMonthsOfPurchase]];
        SKProductsRequest * request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
        request.delegate = self;
        [request start];
        
    } else {
        //不可以购买
        NSLog(@"不可以购买");
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count) {
        //产品存在
        SKProduct * pruduct = response.products[0];
        [self buySumWithId:pruduct];
        NSLog(@"%@---%@---%@",response,pruduct.localizedDescription,pruduct.localizedTitle);
    }
}

- (void)buySumWithId:(SKProduct *)product {
    SKPayment * payment = [SKPayment paymentWithProduct:product];
    //开始购买
    [[SKPaymentQueue defaultQueue] addPayment:payment];
   
    
}
/*
 不上架就是沙盒测试，上架就是实际购买
 购买完毕校验结果
 721369@qq.com
 Lz123456
 
 */

#pragma mark -==SKPaymentTransactionObserver===

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction * transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                {//交易完成
                    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                    [self verifyFinishedWithTransaction:transaction];
                    NSLog(@"交易完成");
                }
                break;
            case SKPaymentTransactionStatePurchasing:
                {//商品添加进列表
                    NSLog(@"商品添加进列表");
                }
                break;
            case SKPaymentTransactionStateFailed:
                {//交易失败
                    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                    NSLog(@"交易失败");
                }
                break;
            case SKPaymentTransactionStateRestored:
                {//已经购买过该商品
                    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                    [self verifyFinishedWithTransaction:transaction];
                    NSLog(@"已经购买过该商品");
                }
                break;
            case SKPaymentTransactionStateDeferred:
                {//等待中。。
                    NSLog(@"等待中。。");
                }
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSLog(@"购买失败：%@",error);
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
 */

#pragma mark =====校验购买结果=====
- (void)verifyFinishedWithTransaction:(SKPaymentTransaction *)transaction {
    if (transaction.transactionState == SKPaymentTransactionStatePurchased || transaction.transactionState == SKPaymentTransactionStateRestored) {
        //购买成功
        NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
        if (!receipt) { /* No local receipt -- handle the error. */
            NSLog(@"receipt 本地数据不存在");
            return;
        }
        NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:receipt options:NSJSONReadingAllowFragments error:nil];
        NSLog(@"原始数据==%@",dict);
        //App 专用共享密钥  如果没有这个数据校验是错误 21004
        //如何获得？ itunes content->功能->App内购买项目->App专用共享密钥
        NSString * theString = @"7bd3e766df954e2f9532b35a3a03fd3e";
        //编码 base64
        NSString *base64_receipt = [receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        [params setObject:base64_receipt forKey:@"receipt-data"];
        [params setObject:theString forKey:@"password"];
        
        [self httpRequesWithUrl:AppPurchaseUrl postData:params completion:^(NSDictionary *result) {
            if (result[@"status"]) {
                if ([result[@"status"] floatValue] == 21007) {
                    //是沙盒测试版本
                    [self handleVerifySandbox:params];
                }
            } else {
                //验证购买成功
            }
        }];
        
    }
}

- (void)handleVerifySandbox:(NSDictionary *)params {
    [self httpRequesWithUrl:SandboxUrl postData:params completion:^(NSDictionary *result) {
        NSLog(@"%@",result);
        if (!result[@"status"]) {
            NSLog(@"验证成功购买过！！！");
        }
    }];
}

//////编码 base64
//- (NSString*)base64String:(NSData *)parameterData{
//    const uint8_t* input = (const uint8_t*)[parameterData bytes];
//    NSInteger length = [parameterData length];
//
//    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
//
//    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
//    uint8_t* output = (uint8_t*)data.mutableBytes;
//
//    NSInteger i;
//    for (i=0; i < length; i += 3) {
//        NSInteger value = 0;
//        NSInteger j;
//        for (j = i; j < (i + 3); j++) {
//            value <<= 8;
//
//            if (j < length) {
//                value |= (0xFF & input[j]);
//            }
//        }
//
//        NSInteger theIndex = (i / 3) * 4;
//        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
//        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
//        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
//        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
//    }
//    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
//}

//网络请求
- (void)httpRequesWithUrl:(NSString *)urlString postData:(NSDictionary *)postData completion:(void(^)(NSDictionary *result))completion {
    
    NSURLSession * session = [NSURLSession sharedSession];
    NSURL * url = [NSURL URLWithString:urlString];
    NSMutableURLRequest * request =[NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:postData options:NSJSONWritingPrettyPrinted error:nil];
    NSString * jsstring =  [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    request.HTTPBody = [jsstring dataUsingEncoding:NSUTF8StringEncoding];
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSURLSessionTask * task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error) {
            NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
//            environment = sandbox 代表是沙盒测试。
            NSLog(@"dict=%@",dict);
            if (completion) {
                completion(dict);
            }
        }
        NSLog(@"response=%@",response);
    }];
    [task  resume];
    
}



-(void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];//解除监听
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
