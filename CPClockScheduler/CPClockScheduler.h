//
//  CPClockScheduler.h
//  CPClockScheduler
//
//  Created by Corné Driesprong on 14/09/16.
//  Copyright © 2016 CP3. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CPClockScheduler : NSObject

@property (nonatomic, readonly) BOOL isRunning;
@property (nonatomic) float tempo;

+ (instancetype)sharedInstance;

- (void)startClockWithTempo:(float)tempo;
- (void)stopClock;

- (void)scheduleEventAtTickCount:(int)tickCount
                  eventFireBlock:(void(^)(void))eventFireBlock;

@end
