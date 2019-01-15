# ZHContactManager
通讯录操作：选择联系人、添加新联系人、添加到现有联系人；打电话、发短信、发邮件

# cocoapods support
```
pod 'ZHContactManager'
```

### 选择联系人
```
[[ZHAuthManager defaultManager] requestAuthorization:AuthTypeContacts authorizedResult:^(BOOL granted) {
    if (granted) {
        ZHContactManager *manager = [ZHContactManager defaultManager];
        [manager selectContactWithCompletionHandler:^(ZHContact *contact) {
            if (contact) {
                //do something
            }
        }];
    }
}];
```
### 获取通讯录所有联系人
```
NSMutableArray *contacts = [manager getAllContacts];
```
### 添加新联系人
```
[manager addNewContactWithPhoneNumber:@"123456"];
```
### 添加到现有的联系人-系统UI
```
[manager addToExistingContactWithPhoneNumber:@"123456"];
```
### 打电话
```
[manager callPhone:@"123456"];
```

### 发送短信
#### 简单用法
```
[manager sendMessage];
```

### 发送邮件
#### 简单用法
```
[manager sendEmail];
```





