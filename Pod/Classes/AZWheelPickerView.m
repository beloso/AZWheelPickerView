//
//  AZWheelPickerView.m
//  az-garage
//
//  Created by Yang Zhang on 12/27/12.
//  Copyright (c) 2012 Albert Zhang. All rights reserved.
//

#import "AZWheelPickerView.h"
#import <QuartzCore/QuartzCore.h>

#define kAZWheelPickerDefaultDeceleration       0.99
#define kAZWheelPickerDefaultMinimumSpeed       0.001
#define kAZWheelPickerChooseSectorSpeed         0.06
#define kMinimumDelta                           0.30 //minimum speed to use if the touch move event is too slow
#define kTimePerFrame (1.0 / 60.0) // 60 fps
#define kCorrectionAnimationDuration 0.5

@interface AZWheelPickerView ()

@property (nonatomic) CGFloat currentRotation;
@property (nonatomic) int currentIndex;
@property (nonatomic, strong) NSTimer *inertiaTimer;

@property (nonatomic, strong) UIImageView *theWheel;
@property (nonatomic, strong) UIImageView *wheelOver;

@property (nonatomic)CGSize wheelSize;
@property (nonatomic)BOOL isTouchDown;
@property (nonatomic)BOOL isTouchMoved;
@property (nonatomic)BOOL wheelBrakingHasStarted;
@property (nonatomic)float lastAtan2;
@property (nonatomic)float lastDelta;
@property (nonatomic)float currentSpeed;
@property (nonatomic)NSTimeInterval lastMovedTime1;
@property (nonatomic)NSTimeInterval lastMovedTime2;

@property (nonatomic)BOOL isRotatingByTimerWhenThisTapHappen;

@end

@implementation AZWheelPickerView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {

        [self myInit];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];

    if (self) {

        [self myInit];
    }

    return self;
}

- (void)myInit {

    self.animationDecelerationFactor = kAZWheelPickerDefaultDeceleration;
//    self.minimumSpeed                = kAZWheelPickerDefaultMinimumSpeed;
//    self.continuousTrigger           = NO;
    self.desiredIndex = -1;
    self.currentIndex = -1;
}


- (void)dealloc {

    [self stopInertiaTimer];
}

#pragma mark -

- (void)didMoveToWindow {
    [super didMoveToWindow];

    if (!self.window) {
        [self stopInertiaTimer];

        return;
    }

    if (!self.theWheel) {
        self.theWheel           = [[UIImageView alloc] initWithImage:self.wheelImage];
        self.theWheel.transform = CGAffineTransformMakeRotation(self.wheelInitialRotation);
        [self addSubview:self.theWheel];

        self.wheelSize          = self.wheelImage.size;
    }
    
    if (!self.theWheel) {
        self.theWheel           = [[UIImageView alloc] initWithImage:self.wheelImage];
        self.theWheel.transform = CGAffineTransformMakeRotation(self.wheelInitialRotation);
        [self addSubview:self.theWheel];
        
        self.wheelSize          = self.wheelImage.size;
    }
    
    if (!self.wheelOver) {
        self.wheelOver           = [[UIImageView alloc] initWithImage:self.wheelOverImage];
    }

    [self fixPositionByIndexAnimated:NO];
}

#pragma mark -

- (void)stopInertiaTimer {

    if (self.inertiaTimer) {

        [self.inertiaTimer invalidate];
        self.inertiaTimer = nil;
    }
}

#pragma mark -

- (void)touchesBegan:(NSSet *)touches
           withEvent:(UIEvent *)event {
    
#warning This should be removed once testing is done
    self.animationDecelerationFactor = kAZWheelPickerDefaultDeceleration;
    self.currentIndex = -1;
    [self.wheelOver removeFromSuperview];
//end
    
    self.isTouchDown                        = YES;
    self.isTouchMoved                       = NO;
    self.isRotatingByTimerWhenThisTapHappen = NO;

    if (self.inertiaTimer) {

        self.isRotatingByTimerWhenThisTapHappen = YES;
        [self stopInertiaTimer];
    }

    CGPoint pos = [[touches anyObject] locationInView:self];
    self.lastAtan2      = atan2(pos.y - self.wheelSize.width / 2,
                           pos.x - self.wheelSize.height / 2);

    self.lastMovedTime1 = 0;
    self.lastMovedTime2 = 0;
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event {

    self.isTouchMoved = YES;

    if (self.isTouchDown) {

        CGPoint pos     = [[touches anyObject] locationInView:self];
        float thisAtan2 = atan2(pos.y - self.wheelSize.width / 2,
                                pos.x - self.wheelSize.height / 2);

        self.lastDelta       = thisAtan2 - self.lastAtan2;

        _currentRotation += self.lastDelta;
            
        self.theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);
        

        self.lastAtan2      = thisAtan2;

        self.lastMovedTime1 = self.lastMovedTime2;
        self.lastMovedTime2 = [NSDate timeIntervalSinceReferenceDate];
    }
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event {

    self.isTouchDown = NO;

    [self handleTouchesEndedOrCancelled:touches];

}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event {

    self.isTouchDown = NO;

    [self handleTouchesEndedOrCancelled:touches];
}

- (void)handleTouchesEndedOrCancelled:(NSSet *)touches {

    if (self.isTouchMoved) {

    [self continueByInertia2];


    }
//        else {
//
//        [self fixPositionByRotationAnimated:YES];
//    }
}

#pragma mark -

- (void)continueByInertia2 {
    
    NSTimeInterval interval = (self.lastMovedTime2 - self.lastMovedTime1);
    
    NSLog(@"interval: %f", interval); //last time interval of the move event, it is always the same, as events are generated at regular intervals. unless the move stops, then it will be big
    NSLog(@"Rotation: %f", self.currentRotation);
    NSLog(@"lastDeltaRad: %f", self.lastDelta);
    NSLog(@"lastDeltaDeg: %f", self.lastDelta*57.2958);
    

    
    self.currentSpeed = MAX(fabsf(self.lastDelta), kMinimumDelta); // only allow clockwise rotation, with a minimum speed
    
    NSLog(@"speed: %f", self.currentSpeed);
    NSLog(@"-----------------");
    
    self.inertiaTimer = [NSTimer scheduledTimerWithTimeInterval:kTimePerFrame
                                                            target:self
                                                          selector:@selector(onInertiaTimer2)
                                                          userInfo:nil
                                                           repeats:YES];
            [self onInertiaTimer2];     // excute once immediately

}


- (void)onInertiaTimer2 {
    
    _currentRotation += _currentSpeed;
    _theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);
    _currentSpeed *= _animationDecelerationFactor;
    
   
   // choose the desired index, at kAZWheelPickerChooseSectorSpeed speed, a full turn of the wheel is garanteed
    if (_desiredIndex != -1 && fabsf(_currentSpeed) <= kAZWheelPickerChooseSectorSpeed ){
        
        //NSLog(@"chooseSpeed: %f", _currentSpeed);
        
        
        int index      = [self rotation2index:_currentRotation];
        
        if (_currentIndex != index) {
            
            _currentIndex = index;
            
            int distanceToIndex = self.currentIndex - self.desiredIndex;
            if (distanceToIndex < 0){
                distanceToIndex = distanceToIndex +self.numberOfSectors;
            }
            
            switch(distanceToIndex){
                    
                case 5: {
                    break;
                }
                case 4: {
                    break;
                }
                case 3: {
                    break;
                }
                case 2: {
                    break;
                }
                case 1: {
                    //brake the wheel to a speed between 0.015 and 0.030
                     //_currentSpeed=0.015;
                     //_currentSpeed=0.030;
                    _currentSpeed = drand48()*0.015+0.015;
                    NSLog(@"----------------BRAKE at 1 %f",_currentSpeed);

                    break;}
                
                case 0: {
                    //brake the wheel to a speed between 0.005 and 0.010
                    //_currentSpeed = 0.005;
                    //_currentSpeed = 0.010;
                    _currentSpeed = drand48()*0.005+0.005;
                     NSLog(@"----------------BRAKE at 0 %f",_currentSpeed);
                    break;}
                    
            }

            NSLog(@"CurrentIndex: %d   desiredIndex: %d", _currentIndex, _desiredIndex);
        }
    }
    
    //stop the wheel
    if (fabsf(_currentSpeed) <= kAZWheelPickerDefaultMinimumSpeed) {
        
        [self stopInertiaTimer];
        int index = [self rotation2index:_currentRotation];
        
        NSLog(@"wheel stopped");
        NSLog(@"Rotation: %f", self.currentRotation);
        NSLog(@"index: %d", index);
        
        
        [self placeWheelOverAtIndex:index];
        
        NSLog(@"-----------------");
    
        [self fixPositionByRotationAnimated:YES];
        
        if (self.delegate &&
            [self.delegate conformsToProtocol:@protocol(AZWheelPickerViewDelegate)] &&
            [self.delegate respondsToSelector:@selector(wheelViewDidEndSpinning:)]) {
            
            [self.delegate wheelViewDidEndSpinning:self];
        }
    }
}


- (void)placeWheelOverAtIndex:(int)index {
    
    NSLog(@"Placing over at %d", index);
    [self.theWheel addSubview:self.wheelOver];
    self.wheelOver.transform = CGAffineTransformMakeRotation(-[self index2rotation:index]);
}

- (int)distanceToIndex:(NSUInteger)index {
    
    int dist = self.currentIndex - self.desiredIndex;
    if (dist < 0){
        dist = dist +self.numberOfSectors;
    }
    
    return dist;
}

- (float)index2rotation:(int)index {

    float r = self.wheelInitialRotation - (M_PI * 2 / self.numberOfSectors) * index;

    return r;
}

- (int)rotation2index:(float)rotation {

    float rotation2 = rotation + (M_PI * 2 / self.numberOfSectors) / 2;

    int index       = ((int)floorf((rotation2 - self.wheelInitialRotation) / (M_PI * 2 / self.numberOfSectors))) %
                      self.numberOfSectors;

    if (index > 0) {

        index = self.numberOfSectors - index;

    } else if (index < 0) {

        index = -index;
    }

    return index;
}


- (void)setSelectedIndex:(int)selectedIndex {

    [self setSelectedIndex:selectedIndex animated:NO];
}

- (void)setSelectedIndex:(int)selectedIndex
                animated:(BOOL)animated {

    BOOL isChanged     = (_selectedIndex != selectedIndex);

    NSInteger oldIndex = _selectedIndex;
    _selectedIndex = selectedIndex;

    CGFloat oldAngle   = _currentRotation;
    CGFloat newAngle   = [self index2rotation:selectedIndex];

    _currentRotation = newAngle;

    CGFloat a = [self distanceBetweenAnglesAlpha:newAngle beta:oldAngle];
    NSLog(@"Correcting angle %f: %@", a, a < 0 ? @"YES" : @"NO");
    [self stopInertiaTimer];
    
    
    
    [UIView animateWithDuration:kCorrectionAnimationDuration
                          delay:0.8
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        
        self.theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);
        
    } completion:^(BOOL finished) {
        
         if (self.delegate &&
             [self.delegate conformsToProtocol:@protocol(AZWheelPickerViewDelegate)] &&
             [self.delegate respondsToSelector:@selector(wheelViewDidEndSpinning:)]) {

             [self.delegate wheelViewDidEndSpinning:self];
         }
     }];

    if (isChanged) {

        [self sendActionsForControlEvents:UIControlEventValueChanged];

        if (self.delegate &&
            [self.delegate conformsToProtocol:@protocol(AZWheelPickerViewDelegate)] &&
            [self.delegate respondsToSelector:@selector(wheelView:didSelectItemAtIndex:)]) {

            [self.delegate wheelView:self didSelectItemAtIndex:selectedIndex];
        }
    }
}

- (void)fixPositionByRotationAnimated:(BOOL)animated {

    int index = [self rotation2index:self.currentRotation];
    [self setSelectedIndex:index animated:animated];
}

- (void)fixPositionByIndexAnimated:(BOOL)animated {

    int i = self.selectedIndex;
    [self setSelectedIndex:i animated:animated];
}

#pragma mark -

- (CGFloat)distanceBetweenAnglesAlpha:(CGFloat)x beta:(CGFloat)y {

    return atan2(sin(x - y), cos(x - y));
}

- (CGSize)sizeThatFits:(CGSize)size {

    CGSize sz = [super sizeThatFits:size];

    if (self.wheelImage) {
        sz = self.wheelImage.size;
    }

    return sz;
}

- (CGSize)intrinsicContentSize {

    CGSize sz = CGSizeZero;

    if (self.wheelImage) {
        sz = self.wheelImage.size;
    }

    return sz;
}

@end
