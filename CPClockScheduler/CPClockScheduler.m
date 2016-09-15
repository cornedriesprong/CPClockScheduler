//
//  CPClockScheduler.m
//  CPClockScheduler
//
//  Created by Corné Driesprong on 14/09/16.
//  Copyright © 2016 CP3. All rights reserved.
//

#import "CPClockScheduler.h"
#import <mach/mach_time.h>

#define kSpinLockTime 0.01

NSString *const kTick = @"tick";
NSString *const kStart = @"start";
NSString *const kStop = @"stop";

NSString *const kBlock = @"block";
NSString *const kTime = @"stop";

@implementation CPClockScheduler {
    double timebase_ratio;
    int _tickCount;
    
    uint64_t _nextTickTime;
    uint64_t _interval;
    
    NSMutableArray *_scheduledBlocks;
}

#pragma mark - Initialization

- (instancetype)init {
    
    if (self = [super init]) {
        
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        timebase_ratio = ((double)timebase.numer / (double)timebase.denom) * 1.0e-9;
        
        float pulseLength = 60 / _tempo;
        _interval = pulseLength / timebase_ratio;
        
        _scheduledBlocks = [[NSMutableArray alloc] init];
    }
    return self;
}

+ (instancetype)sharedInstance {
    
    static CPClockScheduler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Clock

- (void)tick {
    
    while (_isRunning) {
        
        NSMutableArray *blocksForCurrentTick = [[NSMutableArray alloc] init];
        
        for (NSDictionary *dict in [_scheduledBlocks copy]) {
            if ([[dict objectForKey:kTime] integerValue] == _tickCount) {
                [blocksForCurrentTick addObject: [dict objectForKey:kBlock]];
                [_scheduledBlocks removeObject:dict];
            }
        }
        
        NSTimeInterval currentTickTime = _nextTickTime * timebase_ratio;
        if ((mach_absolute_time() * timebase_ratio) >= currentTickTime - kSpinLockTime) {
            
            // spin lock
            while (mach_absolute_time() < _nextTickTime);
            
            for (void (^eventFireBlock)(void) in blocksForCurrentTick) {
                eventFireBlock();
            }
        }
        
        // update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kTick object:nil userInfo:nil];
        });
        
        _tickCount++;
        _nextTickTime += _interval;
        
        mach_wait_until(_nextTickTime - (kSpinLockTime / timebase_ratio));
    }
}

- (void)startClockWithTempo:(float)tempo {
    
    [self setTempo: tempo];
    _isRunning = YES;
    
    _nextTickTime = mach_absolute_time() + _interval;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kStart
                                                        object:nil
                                                      userInfo:nil];
    
    NSThread *thread = [[NSThread alloc] initWithTarget:self
                                               selector:@selector(tick)
                                                 object:nil];
    [thread setThreadPriority:1.0];
    [thread start];
}

- (void)stopClock {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kStop
                                                        object:nil
                                                      userInfo:nil];
    
    _isRunning = NO;
}

#pragma mark - Schedule events

- (void)scheduleEventAtTickCount:(int)tickCount
                  eventFireBlock:(void(^)(void))eventFireBlock {
    
    NSNumber *tickCountNumber = [NSNumber numberWithInt:tickCount];
    NSDictionary *noteOnDict = @{ kBlock : eventFireBlock,
                                  kTime : tickCountNumber };
    
    [_scheduledBlocks addObject:noteOnDict];
}

#pragma mark - Accessors

- (void)setTempo:(float)tempo {
    
    _tempo = tempo;
    float pulseLength = 60 / _tempo;
    _interval = pulseLength / timebase_ratio;
}

@end
