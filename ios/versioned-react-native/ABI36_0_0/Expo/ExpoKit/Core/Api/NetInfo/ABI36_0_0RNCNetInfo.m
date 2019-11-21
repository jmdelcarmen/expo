/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "ABI36_0_0RNCNetInfo.h"
#import "ABI36_0_0RNCConnectionStateWatcher.h"

#include <ifaddrs.h>
#include <arpa/inet.h>

#if !TARGET_OS_TV
@import CoreTelephony;
#endif
@import SystemConfiguration.CaptiveNetwork;

#import <ABI36_0_0React/ABI36_0_0RCTAssert.h>
#import <ABI36_0_0React/ABI36_0_0RCTBridge.h>
#import <ABI36_0_0React/ABI36_0_0RCTEventDispatcher.h>

@interface ABI36_0_0RNCNetInfo () <ABI36_0_0RNCConnectionStateWatcherDelegate>

@property (nonatomic, strong) ABI36_0_0RNCConnectionStateWatcher *connectionStateWatcher;
@property (nonatomic) BOOL isObserving;

@end

@implementation ABI36_0_0RNCNetInfo

#pragma mark - Module setup

ABI36_0_0RCT_EXPORT_MODULE()

// We need ABI36_0_0RNCReachabilityCallback's and module methods to be called on the same thread so that we can have
// guarantees about when we mess with the reachability callbacks.
- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

#pragma mark - Lifecycle

- (NSArray *)supportedEvents
{
  return @[@"netInfo.networkStatusDidChange"];
}

- (void)startObserving
{
  self.isObserving = YES;
}

- (void)stopObserving
{
  self.isObserving = NO;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _connectionStateWatcher = [[ABI36_0_0RNCConnectionStateWatcher alloc] initWithDelegate:self];
  }
  return self;
}

- (void)dealloc
{
  self.connectionStateWatcher = nil;
}

#pragma mark - ABI36_0_0RNCConnectionStateWatcherDelegate

- (void)connectionStateWatcher:(ABI36_0_0RNCConnectionStateWatcher *)connectionStateWatcher didUpdateState:(ABI36_0_0RNCConnectionState *)state
{
  if (self.isObserving) {
    NSDictionary *dictionary = [self currentDictionaryFromUpdateState:state];
    [self sendEventWithName:@"netInfo.networkStatusDidChange" body:dictionary];
  }
}

#pragma mark - Public API

ABI36_0_0RCT_EXPORT_METHOD(getCurrentState:(ABI36_0_0RCTPromiseResolveBlock)resolve
                  reject:(__unused ABI36_0_0RCTPromiseRejectBlock)reject)
{
  ABI36_0_0RNCConnectionState *state = [self.connectionStateWatcher currentState];
  resolve([self currentDictionaryFromUpdateState:state]);
}

#pragma mark - Utilities

// Converts the state into a dictionary to send over the bridge
- (NSDictionary *)currentDictionaryFromUpdateState:(ABI36_0_0RNCConnectionState *)state
{
  NSMutableDictionary *details = nil;
  if (state.connected) {
    details = [NSMutableDictionary new];
    details[@"isConnectionExpensive"] = @(state.expensive);
    
    if ([state.type isEqualToString:ABI36_0_0RNCConnectionTypeCellular]) {
      details[@"cellularGeneration"] = state.cellularGeneration ?: NSNull.null;
      details[@"carrier"] = [self carrier] ?: NSNull.null;
    } else if (
      [state.type isEqualToString:ABI36_0_0RNCConnectionTypeWifi] ||
      [state.type isEqualToString:ABI36_0_0RNCConnectionTypeEthernet]
    ) {
      details[@"ipAddress"] = [self ipAddress] ?: NSNull.null;
      details[@"subnet"] = [self subnet] ?: NSNull.null;
      details[@"ssid"] = [self ssid] ?: NSNull.null;
    }
  }
  
  return @{
           @"type": state.type,
           @"isConnected": @(state.connected),
           @"details": details ?: NSNull.null
           };
}

- (NSString *)carrier
{
#if (TARGET_OS_TV)
  return nil;
#else
  CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
  CTCarrier *carrier = [netinfo subscriberCellularProvider];
  return carrier.carrierName;
#endif
}

- (NSString *)ipAddress
{
  NSString *address = @"0.0.0.0";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = 0;
  // retrieve the current interfaces - returns 0 on success
  success = getifaddrs(&interfaces);
  if (success == 0) {
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      if (temp_addr->ifa_addr->sa_family == AF_INET) {
        NSString* ifname = [NSString stringWithUTF8String:temp_addr->ifa_name];
        if (
          // Check if interface is en0 which is the wifi connection on the iPhone
          // and the ethernet connection on the Apple TV
          [ifname isEqualToString:@"en0"] ||
          // Check if interface is en1 which is the wifi connection on the Apple TV
          [ifname isEqualToString:@"en1"]
        ) {
          // Get NSString from C String
          address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
        }
      }
      
      temp_addr = temp_addr->ifa_next;
    }
  }
  // Free memory
  freeifaddrs(interfaces);
  return address;
}

- (NSString *)subnet
{
  NSString *subnet = @"0.0.0.0";
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = 0;
  // retrieve the current interfaces - returns 0 on success
  success = getifaddrs(&interfaces);
  if (success == 0) {
    // Loop through linked list of interfaces
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      if (temp_addr->ifa_addr->sa_family == AF_INET) {
        NSString* ifname = [NSString stringWithUTF8String:temp_addr->ifa_name];
        if (
          // Check if interface is en0 which is the wifi connection on the iPhone
          // and the ethernet connection on the Apple TV
          [ifname isEqualToString:@"en0"] ||
          // Check if interface is en1 which is the wifi connection on the Apple TV
          [ifname isEqualToString:@"en1"]
        ) {
          // Get NSString from C String
          subnet = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr)];
        }
      }
      
      temp_addr = temp_addr->ifa_next;
    }
  }
  // Free memory
  freeifaddrs(interfaces);
  return subnet;
}

- (NSString *)ssid
{
  NSArray *interfaceNames = CFBridgingRelease(CNCopySupportedInterfaces());
  NSDictionary *SSIDInfo;
  NSString *SSID = NULL;
  for (NSString *interfaceName in interfaceNames) {
    SSIDInfo = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName));
    if (SSIDInfo.count > 0) {
        SSID = SSIDInfo[@"SSID"];
        if ([SSID isEqualToString:@"Wi-Fi"] || [SSID isEqualToString:@"WLAN"]){
          SSID = NULL;
        }
        break;
    }
  }
  return SSID;
}

@end