//
//  IAPProductTableViewCell.h
//  IAP_Test
//
//  Created by 周建顺 on 15/7/20.
//  Copyright (c) 2015年 周建顺. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IAPProductTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *productName;
@property (weak, nonatomic) IBOutlet UILabel *productDetail;
@property (weak, nonatomic) IBOutlet UILabel *productPrice;

@end
