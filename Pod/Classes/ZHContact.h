//
//  ZHContact.h
//  ZHContactManager
//
//  Created by Lee on 2018/9/26.
//  Copyright © 2018年 leezhihua All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ZHAttachment : NSObject
///发送邮件必传，发送短信可选
@property (nonatomic, strong) NSData *data;
///发送短信可选
@property (nonatomic, strong) NSURL *url;
///发送短信，附件格式为NSData时必传
@property (nonatomic, copy) NSString *dataIdentifier;
///必传
@property (nonatomic, copy) NSString *name;
///发送邮件必传
@property (nonatomic, copy) NSString *mineType;
@end

@interface ZHEvent<ValueType:id> : NSObject
@property (nonatomic, copy) NSString *label;
@property (nonatomic, strong) ValueType value;
@end

@interface ZHAddress : NSObject
@property (nonatomic, copy) NSString *country;
@property (nonatomic, copy) NSString *state;//省份，州(美)
@property (nonatomic, copy) NSString *city;
@property (nonatomic, copy) NSString *street;
@property (nonatomic, copy) NSString *postalCode;
@end

@interface ZHContact : NSObject

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) UIImage *thumbnailImage;

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *givenName;
@property (nonatomic, copy) NSString *familyName;

@property (nonatomic, copy) NSString *organizationName;
@property (nonatomic, copy) NSString *departmentName;
@property (nonatomic, copy) NSString *jobTitle;
@property (nonatomic, copy) NSString *note;

@property (nonatomic, strong) NSDateComponents *nonGregorianBirthday;//农历生日
@property (nonatomic, strong) NSDateComponents *birthday;

//电话类型：电话号码
@property (nonatomic, copy) NSArray<ZHEvent<NSString *> *> *phoneInfo;
//邮件类型：邮件
@property (nonatomic, copy) NSArray<ZHEvent<NSString *> *> *emailInfo;
//地址类型：地址信息
@property (nonatomic, copy) NSArray<ZHEvent<ZHAddress *> *> *addressInfo;
@end

