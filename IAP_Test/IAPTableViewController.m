//
//  IAPTableViewController.m
//  IAP_Test
//
//  Created by 周建顺 on 15/7/20.
//  Copyright (c) 2015年 周建顺. All rights reserved.
//

#import "IAPTableViewController.h"
#import <StoreKit/StoreKit.h>
#import "IAPProductTableViewCell.h"

#define kAppStoreVerifyURL @"https://buy.itunes.apple.com/verifyReceipt" //实际购买验证URL
#define kSandboxVerifyURL @"https://sandbox.itunes.apple.com/verifyReceipt" //开发阶段沙盒验证URL

#define kProductID1 @"MxrCoin600"
#define kProductID2 @"MxrCoin1200"
#define kProductID3  @"MxrCoin100"
#define kProductID4 @"MxrVip1"

@interface IAPTableViewController ()<SKProductsRequestDelegate,SKPaymentTransactionObserver>

@property (nonatomic,strong) NSMutableDictionary *products;
@property (nonatomic) NSInteger selectIndex;
//@property (nonatomic,strong)  UIRefreshControl *refreshControl;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *indicator;

@end

@implementation IAPTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    //self.indicator.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.indicator];
    self.indicator.translatesAutoresizingMaskIntoConstraints = NO;
    NSLayoutConstraint *cx = [NSLayoutConstraint constraintWithItem:self.indicator attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.indicator.superview attribute:NSLayoutAttributeCenterX multiplier:1.f constant:0.f];
   NSLayoutConstraint *cy = [NSLayoutConstraint constraintWithItem:self.indicator attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self.indicator.superview attribute:NSLayoutAttributeCenterY multiplier:1.f constant:0.f];
    [self.view addConstraint:cx];
    [self.view addConstraint:cy];
    
    UIBarButtonItem *buyButton = [[UIBarButtonItem alloc] initWithTitle:@"购买" style:UIBarButtonItemStylePlain target:self action:@selector(buyProduct)];
    self.navigationItem.rightBarButtonItem = buyButton;
    
    
    UIBarButtonItem *restoreButton = [[UIBarButtonItem alloc] initWithTitle:@"恢复购买" style:UIBarButtonItemStyleDone target:self action:@selector(restoreProduct)];
    self.navigationItem.leftBarButtonItem = restoreButton;
    
    self.selectIndex = -1;
    
    [self loadProducts];
    [self addTransactionObjserver];
         self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    self.refreshControl.tintColor = [UIColor grayColor];
//    [self.refreshControl addTarget:self action:@selector(pullToRefresh) forControlEvents:UIControlEventValueChanged];
    

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)addTransactionObjserver{
    //设置支付观察者（类似于代理），通过观察者来监控购买情况
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

-(void)loadProducts{
    NSSet *sets = [NSSet setWithObjects:kProductID1,kProductID2,kProductID3,kProductID4,@"MxrCoin1800" , nil];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:sets];
    productsRequest.delegate = self;
    [productsRequest start];
    [self.indicator startAnimating];
    [self.refreshControl beginRefreshing];
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"正在刷新"];
}

-(void)buyProduct{
    if (self.selectIndex>=0) {
        SKProduct *product = [self.products objectForKey:self.products.allKeys[self.selectIndex]];
        [self purchaseProduct:product];
    }
}
- (IBAction)refresh:(UIRefreshControl *)sender {
    
    [self loadProducts];
}

-(void)restoreProduct{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

-(void)pullToRefresh{

    [self loadProducts];
}

-(void)purchaseProduct:(SKProduct*)product{
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    
    if (![SKPaymentQueue canMakePayments]) {
        NSLog(@"设备不支持购买");
        return;
    }
    
    SKPaymentQueue *payQueue = [SKPaymentQueue defaultQueue];
    [payQueue addPayment:payment];
    [self.indicator startAnimating];
}


-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
    [transactions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
            [self.indicator stopAnimating];
        SKPaymentTransaction *transaction = obj;
        if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
            // 购买成功
            
            [self verifyPurchaseWithPaymentTransaction];
            [queue finishTransaction:transaction];
            
        }else if(transaction.transactionState == SKPaymentTransactionStateRestored){
            // 恢复购买，只有非消耗性，才有
            
             [queue finishTransaction:transaction];
            
        }else if(transaction.transactionState == SKPaymentTransactionStateFailed){
            if (transaction.error.code == SKErrorPaymentCancelled) {
                NSLog(@"取消购买");
            }
          NSLog(@"ErrorCode:%li",transaction.error.code);
              [queue finishTransaction:transaction];
        }
        
        
        
    }];
}


/**
 *  验证购买，避免越狱软件模拟苹果请求达到非法购买问题
 *
 */
-(void)verifyPurchaseWithPaymentTransaction{
    
    [self.indicator startAnimating];
    
    //从沙盒中获取交易凭证并且拼接成请求体数据
    NSURL *receiptUrl=[[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData=[NSData dataWithContentsOfURL:receiptUrl];
    
    NSString *receiptString=[receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];//转化为base64字符串
    
    NSString *bodyString = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", receiptString];//拼接请求数据
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    
    //创建请求到苹果官方进行购买验证
    NSURL *url=[NSURL URLWithString:kSandboxVerifyURL];
    NSMutableURLRequest *requestM=[NSMutableURLRequest requestWithURL:url];
    requestM.HTTPBody=bodyData;
    requestM.HTTPMethod=@"POST";
    //创建连接并发送同步请求
    NSError *error=nil;
    NSData *responseData=[NSURLConnection sendSynchronousRequest:requestM returningResponse:nil error:&error];
    if (error) {
        NSLog(@"验证购买过程中发生错误，错误信息：%@",error.localizedDescription);
        return;
    }
    NSDictionary *dic=[NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
    NSLog(@"%@",dic);
    
    NSString *message = nil;
    if([dic[@"status"] intValue]==0){
        NSLog(@"购买成功！");
        NSDictionary *dicReceipt= dic[@"receipt"];
        NSDictionary *dicInApp=[dicReceipt[@"in_app"] firstObject];
        NSString *productIdentifier= dicInApp[@"product_id"];//读取产品标识
        //如果是消耗品则记录购买数量，非消耗品则记录是否购买过
//        NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
//        if ([productIdentifier isEqualToString:kProductID3]) {
//            int purchasedCount=[defaults integerForKey:productIdentifier];//已购买数量
//            [[NSUserDefaults standardUserDefaults] setInteger:(purchasedCount+1) forKey:productIdentifier];
//        }else{
//            [defaults setBool:YES forKey:productIdentifier];
//        }
//        [self.tableView reloadData];
        //在此处对购买记录进行存储，可以存储到开发商的服务器端
    }else{
        NSLog(@"购买失败，未通过验证！");
    }
    
//    dispatch_async(dispatch_get_main_queue(), ^{
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
//        [alert show];
//    });
        [self.indicator stopAnimating];

}

#pragma mark - SKProductsRequestd代理方法
/**
 *  产品请求完成后的响应方法
 *
 *  @param request  请求对象
 *  @param response 响应对象，其中包含产品信息
 */
-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    //保存有效的产品
    self.products =[NSMutableDictionary dictionary];
    [response.products enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SKProduct *product=obj;
        [self.products setObject:product forKey:product.productIdentifier];
    }];
    //由于这个过程是异步的，加载成功后重新刷新表格
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
    [self.indicator stopAnimating];
       self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
}
-(void)requestDidFinish:(SKRequest *)request{
    NSLog(@"请求完成.");
}
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    if (error) {
        NSLog(@"请求过程中发生错误，错误信息：%@",error.localizedDescription);
    }
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return self.products.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    IAPProductTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cellIdentifier" forIndexPath:indexPath];
    
//    if (!cell) {
//        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cellIdentifier"] ;
//    }
    //cell.accessoryType=UITableViewCellAccessoryNone;
    NSString *key=self.products.allKeys[indexPath.row];
    SKProduct *product=self.products[key];
    cell.productName.text=[NSString stringWithFormat:@"%@",product.localizedTitle] ;
    //NSLog(@"%@",[NSString stringWithFormat:@"%@",product.price]);
    NSLog(@"product.productIdentifier:%@",product.productIdentifier);
    cell.productDetail.text = product.localizedDescription;
    cell.productPrice.text= [NSString stringWithFormat:@"%@",product.price];
    
    // Configure the cell...
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    self.selectIndex = indexPath.row;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    // Get the new view controller using [segue destinationViewController].
//    // Pass the selected object to the new view controller.
//    NSLog(@"sender:%@",sender);
//    
//    UIViewController *vc = [[UIViewController alloc] init];
//    
//    return;
//}


@end
