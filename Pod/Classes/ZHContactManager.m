//
//  ZHContactManager.m
//  ZHContactManager
//
//  Created by Lee on 2016/7/20.
//  Copyright © 2016年 leezhihua All rights reserved.
//

#import "ZHContactManager.h"
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>

#define kRootViewController [UIApplication sharedApplication].keyWindow.rootViewController

@interface ZHContactManager ()<ABPeoplePickerNavigationControllerDelegate, ABNewPersonViewControllerDelegate, CNContactPickerDelegate, CNContactViewControllerDelegate, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate>
@property (nonatomic, copy) void(^singleContacts)(ZHContact *contacts);
@property (nonatomic, copy) NSString *phoneNumber;
@property (nonatomic, copy) void(^sendMessageResult)(BOOL success, NSError *error);
@property (nonatomic, copy) void(^sendEmailResult)(BOOL success, NSError *error);
@end

static ZHContactManager *manager = nil;
@implementation ZHContactManager

+ (instancetype)defaultManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

#pragma mark - CNContact->ZHContact
- (ZHContact *)transformZHContactByCNContact:(CNContact *)contact  API_AVAILABLE(ios(9.0)) {
    ZHContact *contacts = [[ZHContact alloc] init];
    contacts.identifier = contact.identifier;
    //头像
    if (contact.imageDataAvailable) {
        contacts.image = [UIImage imageWithData:contact.imageData];
        contacts.thumbnailImage = [UIImage imageWithData:contact.thumbnailImageData];
    }
    //名字
    contacts.name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
    contacts.givenName = contact.givenName;
    contacts.familyName = contact.familyName;
    //工作
    contacts.organizationName = contact.organizationName;
    contacts.departmentName = contact.departmentName;
    contacts.jobTitle = contact.jobTitle;
    contacts.note = contact.note;
    //生日
    contacts.birthday = contact.birthday;
    contacts.nonGregorianBirthday = contact.nonGregorianBirthday;
    //号码
    NSMutableArray *phoneInfo = [NSMutableArray arrayWithCapacity:0];
    for (CNLabeledValue<CNPhoneNumber*> *phoneNumber in contact.phoneNumbers) {
        NSString *type = [self localizedStringForLabel:phoneNumber.label spareString:@"手机"];
        NSString *value = phoneNumber.value.stringValue;
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = value;
        [phoneInfo addObject:event];
    }
    contacts.phoneInfo = phoneInfo.copy;
    //邮箱
    NSMutableArray *emailInfo = [NSMutableArray arrayWithCapacity:0];
    for (CNLabeledValue *emailAddress in contact.emailAddresses) {
        NSString *type = [self localizedStringForLabel:emailAddress.label spareString:@"邮件"];
        NSString *value = emailAddress.value;
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = value;
        [emailInfo addObject:event];
    }
    contacts.emailInfo = emailInfo.copy;
    
    //地址
    NSMutableArray *addressInfo = [NSMutableArray arrayWithCapacity:0];
    for (CNLabeledValue<CNPostalAddress*> *addressLabelValue in contact.postalAddresses) {
        //类型
        NSString *type = [self localizedStringForLabel:addressLabelValue.label spareString:@"地址"];
        //信息
        CNPostalAddress *address = addressLabelValue.value;
        ZHAddress *addInfo = [[ZHAddress alloc] init];
        addInfo.country = address.country;
        addInfo.state = address.state;
        addInfo.city = address.city;
        addInfo.street = address.street;
        addInfo.postalCode = address.postalCode;
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = addInfo;
        [addressInfo addObject:event];
    }
    contacts.addressInfo = addressInfo.copy;
    
    return contacts;
}
#pragma mark - ABRecordRef->ZHContact
- (ZHContact *)transformZHContactByPerson:(ABRecordRef)people {
    ZHContact *contacts = [[ZHContact alloc] init];
    //获取联系人记录id
    contacts.identifier = [NSString stringWithFormat:@"%ld", (long)ABRecordGetRecordID(people)];;
    //头像
    if (ABPersonHasImageData(people)) {
        NSData *imageData = (__bridge_transfer NSData *)ABPersonCopyImageDataWithFormat(people, kABPersonImageFormatOriginalSize);
        contacts.image = [UIImage imageWithData:imageData];
        NSData *thumbnailImageData = (__bridge_transfer NSData *)ABPersonCopyImageDataWithFormat(people, kABPersonImageFormatThumbnail);
        contacts.thumbnailImage = [UIImage imageWithData:thumbnailImageData];
    }
    //名字
    NSString *name = (__bridge_transfer NSString *)ABRecordCopyCompositeName(people);
    contacts.name = name;
    NSString *firstName = (__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonFirstNameProperty));
    contacts.givenName = firstName;
    NSString *lastName = (__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
    contacts.familyName = lastName;
    //工作
    NSString *organization = (__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonOrganizationProperty));
    contacts.organizationName = organization;
    NSString *department = (__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonDepartmentProperty));
    contacts.departmentName = department;
    NSString *job = (__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonJobTitleProperty));
    contacts.jobTitle = job;
    //获取当前联系人的备注
    NSString *notes = (__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonNoteProperty));
    contacts.note = notes;
    //获取当前联系人的生日
    NSDate *birthday = (__bridge_transfer NSDate*)(ABRecordCopyValue(people, kABPersonBirthdayProperty));
    if (birthday) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:birthday];
        contacts.birthday = components;
    }
    //获取当前联系人的农历生日
    NSDictionary * brithdayDictionary = (__bridge_transfer NSDictionary *)(ABRecordCopyValue(people, kABPersonAlternateBirthdayProperty));//获得农历日历属性的字典
    //农历日历的属性，设置为农历属性的时候，此字典存在数值
    if (brithdayDictionary) {
        //NSString *calendar = [brithdayDictionary valueForKey:@"calendarIdentifier"]; //农历生日的标志位,比如“chinese”
        //BOOL isLeapMonth = [[brithdayDictionary valueForKey:@"isLeapMonth"] boolValue];//是否是闰月
        NSInteger era = [[brithdayDictionary valueForKey:@"era"] integerValue];//纪元
        NSInteger year = [[brithdayDictionary valueForKey:@"year"] integerValue];//年份,六十组干支纪年的索引数，比如12年为壬辰年，为循环的29,此数字为29
        NSInteger month = [[brithdayDictionary valueForKey:@"month"] integerValue];//月份
        NSInteger day = [[brithdayDictionary valueForKey:@"day"] integerValue];//日
        NSDateComponents *components = [[NSDateComponents alloc] init];
        components.era = era;
        components.year = year;
        components.month = month;
        components.day = day;
        
        contacts.nonGregorianBirthday = components;
    }
    
    //获取当前联系人的电话 数组
    ABMultiValueRef phones = ABRecordCopyValue(people, kABPersonPhoneProperty);
    NSMutableArray *phoneInfo = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger j=0; j<ABMultiValueGetCount(phones); j++) {
        //获取电话类型（工作电话、住宅电话）
        NSString *type = [self localizedStringForValue:phones atIndex:j spareString:@"手机"];
        //获取该类型下的电话值
        NSString *phone = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phones, j));
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = phone;
        [phoneInfo addObject:event];
    }
    contacts.phoneInfo = phoneInfo.copy;
    [self releaseRef:phones];
    
    //获取当前联系人的邮箱 注意是数组
    ABMultiValueRef emails= ABRecordCopyValue(people, kABPersonEmailProperty);
    NSMutableArray *emailInfo = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger j=0; j<ABMultiValueGetCount(emails); j++) {
        NSString *type = [self localizedStringForValue:emails atIndex:j spareString:@"邮件"];
        NSString *email = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(emails, j));
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = email;
        [emailInfo addObject:event];
    }
    contacts.emailInfo = emailInfo.copy;
    [self releaseRef:emails];
    
    //获取地址
    ABMultiValueRef address = ABRecordCopyValue(people, kABPersonAddressProperty);
    NSMutableArray *addressInfo = [NSMutableArray arrayWithCapacity:0];
    for (NSInteger j=0; j<ABMultiValueGetCount(address); j++) {
        //地址类型
        NSString *type = [self localizedStringForValue:address atIndex:j spareString:@"地址"];
        //地址信息
        NSDictionary * tempDic = (__bridge_transfer NSDictionary *)(ABMultiValueCopyValueAtIndex(address, j));
        NSString *country = tempDic[(NSString*)kABPersonAddressCountryKey];
        NSString *province = tempDic[(NSString*)kABPersonAddressStateKey];
        NSString *city = tempDic[(NSString*)kABPersonAddressCityKey];
        NSString *street = tempDic[(NSString*)kABPersonAddressStreetKey];
        NSString *postcode = tempDic[(NSString*)kABPersonAddressZIPKey];
        ZHAddress *addInfo = [[ZHAddress alloc] init];
        addInfo.country = country;
        addInfo.state = province;
        addInfo.city = city;
        addInfo.street = street;
        addInfo.postalCode = postcode;
        ZHEvent *event = [[ZHEvent alloc] init];
        event.label = type;
        event.value = addInfo;
        [addressInfo addObject:event];
    }
    contacts.addressInfo = addressInfo.copy;
    [self releaseRef:address];
    
    return contacts;
}
#pragma mark - 添加联系人-无UI
- (void)addContact:(ZHContact *)contacts {
    if (@available(iOS 9.0, *)) {
        CNMutableContact *mutableContact = [[CNMutableContact alloc] init];
        mutableContact.givenName = contacts.givenName;
        mutableContact.familyName = contacts.familyName;
        CNLabeledValue *phone = [CNLabeledValue labeledValueWithLabel:CNLabelPhoneNumberMobile value:[CNPhoneNumber phoneNumberWithStringValue:contacts.phoneInfo.firstObject.value]];
        mutableContact.phoneNumbers = @[phone];
        //保存对象
        CNSaveRequest *saveRequest = [[CNSaveRequest alloc] init];
        [saveRequest addContact:mutableContact toContainerWithIdentifier:nil];
        //更新通讯录
        CNContactStore *store = [[CNContactStore alloc] init];
        [store executeSaveRequest:saveRequest error:nil];
    } else {
        //创建通讯录
        ABAddressBookRef addressBookRef = ABAddressBookCreate();
        ABRecordRef recordRef = ABPersonCreate();
        ABRecordSetValue(recordRef, kABPersonFirstNameProperty, (__bridge CFStringRef)contacts.givenName, nil);
        ABRecordSetValue(recordRef, kABPersonLastNameProperty, (__bridge CFStringRef)contacts.familyName, nil);
        //保存手机
        ABMutableMultiValueRef phone = ABMultiValueCreateMutable(kABStringPropertyType);
        ABMultiValueAddValueAndLabel(phone, (__bridge CFStringRef)contacts.phoneInfo.firstObject.value, kABPersonPhoneMobileLabel, NULL);
        ABRecordSetValue(recordRef, kABPersonPhoneProperty, phone, nil);
        //
        ABAddressBookAddRecord(addressBookRef, recordRef, nil);
        ABAddressBookSave(addressBookRef, nil);
        CFRelease(recordRef);
        CFRelease(phone);
    }
}
#pragma mark - 添加新联系人-使用系统UI
- (void)addNewContactWithPhoneNumber:(NSString *)phoneNumber {
    if (@available(iOS 9.0, *)) {
        CNMutableContact *mutableContact = [[CNMutableContact alloc] init];
        CNLabeledValue *phone = [CNLabeledValue labeledValueWithLabel:CNLabelPhoneNumberMobile value:[CNPhoneNumber phoneNumberWithStringValue:phoneNumber]];
        mutableContact.phoneNumbers = @[phone];
        CNContactViewController *contactVC = [CNContactViewController viewControllerForNewContact:mutableContact];
        contactVC.delegate = self;
        contactVC.navigationItem.title = @"添加联系人";
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:contactVC];
        [kRootViewController presentViewController:nav animated:YES completion:nil];
    } else {
        ABRecordRef newPerson = ABPersonCreate();
        ABMutableMultiValueRef valueRef = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(valueRef, (__bridge CFTypeRef)phoneNumber, kABPersonPhoneMobileLabel, NULL);
        ABRecordSetValue(newPerson, kABPersonPhoneProperty, valueRef, nil);
        ABNewPersonViewController *personVC = [[ABNewPersonViewController alloc] init];
        personVC.newPersonViewDelegate = self;
        personVC.displayedPerson = newPerson;
        personVC.navigationItem.title = @"添加联系人";
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:personVC];
        [kRootViewController presentViewController:nav animated:YES completion:^{
            CFRelease(newPerson);
            CFRelease(valueRef);
        }];
    }
}
#pragma mark - 添加到现有的联系人-使用系统UI
- (void)addToExistingContactWithPhoneNumber:(NSString *)phoneNumber {
    self.phoneNumber = phoneNumber;
    if (@available(iOS 9.0, *)) {
        //先选择现有联系人
        CNContactPickerViewController *contactPickerVC = [[CNContactPickerViewController alloc] init];
        contactPickerVC.delegate = self;
        contactPickerVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:YES];//设为YES会走【联系人列表选择代理】
        [kRootViewController presentViewController:contactPickerVC animated:YES completion:nil];
    } else {
        ABPeoplePickerNavigationController *peoplePickerVC = [[ABPeoplePickerNavigationController alloc] init];
        peoplePickerVC.peoplePickerDelegate = self;
        peoplePickerVC.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:YES];
        [kRootViewController presentViewController:peoplePickerVC animated:YES completion:nil];
    }
}
#pragma mark CNContactViewControllerDelegate
- (void)contactViewController:(CNContactViewController *)viewController didCompleteWithContact:(CNContact *)contact  API_AVAILABLE(ios(9.0)) {
    [viewController dismissViewControllerAnimated:YES completion:^{
        
    }];
}
#pragma mark - ABNewPersonViewControllerDelegate
- (void)newPersonViewController:(ABNewPersonViewController *)newPersonView didCompleteWithNewPerson:(ABRecordRef)person {
    [newPersonView dismissViewControllerAnimated:YES completion:^{
        
    }];
}
#pragma mark - 选择联系人
- (void)selectContactWithCompletionHandler:(void (^)(ZHContact *))completion {
    if (@available(iOS 9.0, *)) {
        CNContactPickerViewController *contactPickerVC = [[CNContactPickerViewController alloc] init];
        contactPickerVC.delegate = self;
        self.singleContacts = completion;
        contactPickerVC.predicateForSelectionOfContact = [NSPredicate predicateWithValue:NO];//设为NO会走【联系人详情选择代理】
        [kRootViewController presentViewController:contactPickerVC animated:YES completion:nil];
    } else {
        ABPeoplePickerNavigationController *peoplePickerVC = [[ABPeoplePickerNavigationController alloc] init];
        peoplePickerVC.peoplePickerDelegate = self;
        self.singleContacts = completion;
        peoplePickerVC.predicateForSelectionOfPerson = [NSPredicate predicateWithValue:NO];
        [kRootViewController presentViewController:peoplePickerVC animated:YES completion:nil];
    }
}
#pragma mark CNContactPickerDelegate
- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker  API_AVAILABLE(ios(9.0)){
    self.singleContacts(nil);
}
//联系人列表选择代理
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact  API_AVAILABLE(ios(9.0)){
    [picker dismissViewControllerAnimated:NO completion:nil];
    CNMutableContact *mutableContact = contact.mutableCopy;
    CNLabeledValue *phone = [CNLabeledValue labeledValueWithLabel:CNLabelPhoneNumberMobile value:[CNPhoneNumber phoneNumberWithStringValue:self.phoneNumber]];
    NSMutableArray *phones = mutableContact.phoneNumbers.mutableCopy;
    [phones addObject:phone];
    mutableContact.phoneNumbers = phones.copy;
    CNContactViewController *contactVC = [CNContactViewController viewControllerForNewContact:mutableContact];
    contactVC.delegate = self;
    contactVC.navigationItem.title = @"添加联系人";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:contactVC];
    [kRootViewController presentViewController:nav animated:YES completion:nil];
}
//联系人详情选择代理
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContactProperty:(CNContactProperty *)contactProperty  API_AVAILABLE(ios(9.0)) {
    CNContact *contact = contactProperty.contact;
    ZHContact *contacts = [self transformZHContactByCNContact:contact];
    [picker dismissViewControllerAnimated:YES completion:^{
        self.singleContacts(contacts);
    }];
}

#pragma mark ABPeoplePickerNavigationControllerDelegate
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
    [peoplePicker dismissViewControllerAnimated:YES completion:^{
        self.singleContacts(nil);
    }];
}
//联系人列表选择代理
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker didSelectPerson:(ABRecordRef)person {
    [peoplePicker dismissViewControllerAnimated:NO completion:nil];
    //原联系人电话
    ABMutableMultiValueRef phones = ABRecordCopyValue(person, kABPersonPhoneProperty);
    //创建可变值
    ABMutableMultiValueRef valueRef = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    //循环添加原联系人电话
    for (CFIndex i = 0; i < ABMultiValueGetCount(phones); i++) {
        CFTypeRef value = ABMultiValueCopyValueAtIndex(phones, i);
        CFStringRef label = ABMultiValueCopyLabelAtIndex(phones, i);
        ABMultiValueAddValueAndLabel(valueRef, value, label, NULL);
    }
    //添加新号码
    ABMultiValueAddValueAndLabel(valueRef, (__bridge CFTypeRef)self.phoneNumber, kABPersonPhoneMobileLabel, NULL);
    //保存
    ABRecordSetValue(person, kABPersonPhoneProperty, valueRef, nil);
    ABNewPersonViewController *personVC = [[ABNewPersonViewController alloc] init];
    personVC.newPersonViewDelegate = self;
    personVC.displayedPerson = person;
    personVC.navigationItem.title = @"添加联系人";
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:personVC];
    [kRootViewController presentViewController:nav animated:YES completion:^{
        CFRelease(phones);
        CFRelease(valueRef);
    }];
}
//联系人详情选择代理
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController*)peoplePicker didSelectPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
    ZHContact *contacts = [self transformZHContactByPerson:person];
    [peoplePicker dismissViewControllerAnimated:YES completion:^{
        self.singleContacts(contacts);
    }];
}

#pragma mark - 获取全部联系人
- (NSMutableArray<ZHContact *> *)getAllContacts {
    NSMutableArray *contactsBook = [NSMutableArray arrayWithCapacity:0];
    if (@available(iOS 9.0, *)) {
        CNContactStore *contactStore = [[CNContactStore alloc] init];
        NSArray *fetchKeys = @[CNContactIdentifierKey,
                               CNContactImageDataKey,
                               CNContactThumbnailImageDataKey,
                               CNContactImageDataAvailableKey,
                               [CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName],
                               CNContactGivenNameKey,
                               CNContactFamilyNameKey,
                               CNContactOrganizationNameKey,
                               CNContactDepartmentNameKey,
                               CNContactJobTitleKey,
                               CNContactNoteKey,
                               CNContactBirthdayKey,
                               CNContactNonGregorianBirthdayKey,
                               CNContactPhoneNumbersKey,
                               CNContactEmailAddressesKey,
                               CNContactPostalAddressesKey,
                               CNContactTypeKey];
        
        CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:fetchKeys];
        [contactStore enumerateContactsWithFetchRequest:fetchRequest error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
            ZHContact *contacts = [self transformZHContactByCNContact:contact];
            [contactsBook addObject:contacts];
        }];
    } else {
        //获取所有联系人
        ABAddressBookRef addressBookRef = ABAddressBookCreate();
        CFArrayRef arrayRef = ABAddressBookCopyArrayOfAllPeople(addressBookRef);
        long count = CFArrayGetCount(arrayRef);
        
        for (long i = 0; i < count; i++) {
            //获取联系人对象的引用
            ABRecordRef people = CFArrayGetValueAtIndex(arrayRef, i);
            ZHContact *contacts = [self transformZHContactByPerson:people];
            [contactsBook addObject:contacts];
        }
        [self releaseRef:addressBookRef];
        [self releaseRef:arrayRef];
    }
    return contactsBook;
}

- (NSString *)localizedStringForLabel:(NSString *)label spareString:(NSString *)spareString {
    if (@available(iOS 9.0, *)) {
        NSString *type = [CNLabeledValue localizedStringForLabel:label];
        if (!type) {
            type = spareString;
        }
        return type;
    }
    return nil;
}

- (NSString *)localizedStringForValue:(ABMultiValueRef)value atIndex:(NSInteger)index spareString:(NSString *)spareString {
    NSString *type  = (__bridge_transfer NSString*)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(value, index));
    if (!type) {
        type = spareString;
    }
    return type;
}


- (void)releaseRef:(CFTypeRef)ref {
    if (ref) {
        CFRelease(ref);
    }
}


#pragma mark - 打电话
- (void)callPhone:(NSString *)phone {
    phone = [phone stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (phone.length <= 0) {
        NSAssert(phone.length, @"Warning: please input correct phone number");
    }
    NSString *phoneNumber = [@"telprompt://" stringByAppendingString:phone];
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phoneNumber] options:@{} completionHandler:nil];
    } else {
        NSString *phoneNumber = [@"tel://" stringByAppendingString:phone];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phoneNumber]];
        
    }
}

#pragma mark - 发短信
- (void)sendMessage {
    if([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *messageVC = [[MFMessageComposeViewController alloc]init];
        messageVC.messageComposeDelegate = self;
        [kRootViewController presentViewController:messageVC animated:YES completion:nil];
    } else {
        NSLog(@"Warning:this client cannot send message!");
    }
}

- (void)sendMessageWithContent:(NSString *)message recipients:(NSArray<NSString *> *)recipients subject:(NSString *)subject attachments:(NSArray<ZHAttachment *> *)attachments  result:(void (^)(BOOL success, NSError *error))result {
    if([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *messageVC = [[MFMessageComposeViewController alloc]init];
        messageVC.messageComposeDelegate = self;
        messageVC.body = message;
        messageVC.recipients = recipients;
        if ([MFMessageComposeViewController canSendSubject] && subject.length) {
            messageVC.subject = subject;
        }
        if ([MFMessageComposeViewController canSendAttachments] && attachments.count) {
            for (ZHAttachment *attachment in attachments) {
                if (attachment.data && attachment.dataIdentifier) {
                    [messageVC addAttachmentData:attachment.data typeIdentifier:attachment.dataIdentifier filename:attachment.name];
                }
                if (attachment.url) {
                    [messageVC addAttachmentURL:attachment.url withAlternateFilename:attachment.name];
                }
            }
        }
        self.sendMessageResult = result;
        [kRootViewController presentViewController:messageVC animated:YES completion:nil];
    } else {
        NSLog(@"Warning:this client cannot send message!");
    }
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
    [controller dismissViewControllerAnimated:YES completion:^{
        if (self.sendMessageResult) {
            __block NSError *error = nil;
            switch (result) {
                case MessageComposeResultSent:
                    self.sendMessageResult(YES, nil);
                    break;
                case MessageComposeResultCancelled:
                    error = [NSError errorWithDomain:@"Message Send Error-Cancelled" code:MessageComposeResultCancelled userInfo:nil];
                    self.sendMessageResult(NO, error);
                    break;
                case MessageComposeResultFailed:
                    error = [NSError errorWithDomain:@"Message Send Error-Failed" code:MessageComposeResultFailed userInfo:nil];
                    self.sendMessageResult(NO, error);
                    break;
                    
                default:
                    break;
            }
        }
    }];
}

#pragma mark - 发邮件
- (void)sendEmail {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
        mailVC.mailComposeDelegate = self;
        [kRootViewController presentViewController:mailVC animated:YES completion:nil];
    } else {
        NSLog(@"Warning:this client cannot send email!");
    }
}
- (void)sendEmail:(NSString *)content subject:(NSString *)subject recipients:(NSArray<NSString *> *)recipients ccRecipients:(NSArray<NSString *> *)ccRecipients bccRecipients:(NSArray<NSString *> *)bccRecipients attachments:(NSArray<ZHAttachment *> *)attachments result:(void(^)(BOOL success, NSError *error))result {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailVC = [[MFMailComposeViewController alloc] init];
        mailVC.mailComposeDelegate = self;
        //收件人
        [mailVC setToRecipients:recipients];
        //抄送
        [mailVC setCcRecipients:ccRecipients];
        //密送
        [mailVC setBccRecipients:bccRecipients];
        //主题
        [mailVC setSubject:subject];
        //正文
        if (content.length) {
            BOOL html = [content containsString:@"<html>"];
            [mailVC setMessageBody:content isHTML:html];
        }
        //附件
        if (attachments.count) {
            for (ZHAttachment *attachment in attachments) {
                [mailVC addAttachmentData:attachment.data mimeType:attachment.mineType fileName:attachment.name];
            }
        }
        self.sendEmailResult = result;
        [kRootViewController presentViewController:mailVC animated:YES completion:nil];
    } else {
        NSLog(@"Warning:this client cannot send email!");
    }
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    [controller dismissViewControllerAnimated:YES completion:^{
        if (self.sendEmailResult) {
            __block NSError *err = nil;
            switch (result) {
                case MFMailComposeResultSent:
                    self.sendEmailResult(YES, nil);
                    break;
                case MFMailComposeResultFailed:
                    self.sendEmailResult(NO, error);
                    break;
                case MFMailComposeResultSaved:
                    err = [NSError errorWithDomain:@"Email Send Error-Saved" code:MFMailComposeResultSaved userInfo:nil];
                    self.sendEmailResult(NO, err);
                    break;
                case MFMailComposeResultCancelled:
                    err = [NSError errorWithDomain:@"Email Send Error-Cancelled" code:MFMailComposeResultCancelled userInfo:nil];
                    self.sendEmailResult(NO, err);
                    break;
                default:
                    break;
            }
        }
    }];
}


@end
