//
//  ZhiYu-Bridging-Header.h
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：桥接微信 SDK 与阿里云一键登录 SDK (Objective-C) 供 Swift 调用。
//

#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import <WechatOpenSDK/WechatOpenSDK.h>
#import <ATAuthSDK_D/ATAuthSDK.h>
#endif

