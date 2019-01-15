//
//  ZHContactManager.h
//  ZHContactManager
//
//  Created by Lee on 2016/7/20.
//  Copyright © 2016年 leezhihua All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZHContact.h"

@interface ZHContactManager : NSObject

/**
 单利
 */
+ (instancetype)defaultManager;

/**
 选择联系人
 */
- (void)selectContactWithCompletionHandler:(void(^)(ZHContact * contact))completion;

/**
 获取通讯录所有联系人
 */
- (NSMutableArray<ZHContact *> *)getAllContacts;

/**
 添加新联系人
 */
- (void)addNewContactWithPhoneNumber:(NSString *)phoneNumber;

/**
 添加到现有的联系人
 */
- (void)addToExistingContactWithPhoneNumber:(NSString *)phoneNumber;

/**
 打电话
 */
- (void)callPhone:(NSString *)phone;

/**
 发送短信
 */
- (void)sendMessage;

/**
 发送短信-指定内容
 
 @param message 内容文本
 @param recipients 接收人(手机号，传入多个手机号就是群发)
 @param subject 标题
 @param attachments 附件(图片，可以传入图片名称<本地、网络>)
 @param result 发送结果
 */
- (void)sendMessageWithContent:(NSString *)message recipients:(NSArray<NSString *> *)recipients subject:(NSString *)subject attachments:(NSArray<ZHAttachment *> *)attachments  result:(void (^)(BOOL success, NSError *error))result;

/**
 发送邮件
 */
- (void)sendEmail;

/**
 发送邮件-指定内容

 @param content 邮件正文
 @param subject 主题
 @param recipients 接收人
 @param ccRecipients 抄送
 @param bccRecipients 密送
 @param attachments 附件
 @param result 结果
 */
- (void)sendEmail:(NSString *)content subject:(NSString *)subject recipients:(NSArray<NSString *> *)recipients ccRecipients:(NSArray<NSString *> *)ccRecipients bccRecipients:(NSArray<NSString *> *)bccRecipients attachments:(NSArray<ZHAttachment *> *)attachments result:(void(^)(BOOL success, NSError *error))result;

@end

