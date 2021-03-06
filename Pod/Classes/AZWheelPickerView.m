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
// TODO: change this to be calculated taking into account the number of sectors
#define kAZWheelPickerMaxChooseSectorSpeed      0.063
#define kAZWheelPickerMinChooseSectorSpeed      0.0535
#define kMinimumDeltaEnforce                    0.30//minimum speed to use if the touch move event is too slow and enforceMinimumSpeed is on
#define kMinimumDeltaNoEnforce                  kAZWheelPickerMaxChooseSectorSpeed//minimum speed to use if the touch move event is too slow and we are not enforcing speed, we notify delegate instead
#define kTimePerFrame (1.0 / 60.0) // 60 fps
#define kCorrectionAnimationDuration 0.5

@interface AZWheelPickerView ()

@property (nonatomic) CGFloat currentRotation;
@property (nonatomic) int currentIndex;
@property (nonatomic, strong) NSTimer *inertiaTimer;

@property (nonatomic, strong) UIImageView *theWheel;
@property (nonatomic, strong) UIImageView *wheelOver;

@property (nonatomic) CGSize wheelSize;
@property (nonatomic) BOOL isTouchDown;
@property (nonatomic) BOOL isTouchMoved;
@property (nonatomic) BOOL wheelBrakingHasStarted;
@property (nonatomic) float lastAtan2;
@property (nonatomic) float lastDelta;
@property (nonatomic) float currentSpeed;
@property (nonatomic) NSTimeInterval lastMovedTime1;
@property (nonatomic) NSTimeInterval lastMovedTime2;

@property (nonatomic) BOOL isRotatingByTimerWhenThisTapHappen;

@property (nonatomic) BOOL canBreak;
@property (nonatomic) CGFloat chooseSectorSpeed;

@property (nonatomic) BOOL fullySpinning;

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
    self.desiredIndex                = -1;
    self.currentIndex                = -1;

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

        self.theWheel                                           = [[UIImageView alloc] initWithImage:self.wheelImage];
        self.theWheel.translatesAutoresizingMaskIntoConstraints = NO;
        self.theWheel.contentMode                               = UIViewContentModeScaleAspectFit;
        self.theWheel.transform                                 = CGAffineTransformMakeRotation(
            self.wheelInitialRotation);
        [self addSubview:self.theWheel];

        NSLayoutConstraint *imageViewTop = [NSLayoutConstraint constraintWithItem:self.theWheel
                                                                        attribute:NSLayoutAttributeTop
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeTop
                                                                       multiplier:1.0
                                                                         constant:0.0];
        NSLayoutConstraint *imageViewLeft = [NSLayoutConstraint constraintWithItem:self.theWheel
                                                                         attribute:NSLayoutAttributeLeft
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeLeft
                                                                        multiplier:1.0
                                                                          constant:0.0];
        NSLayoutConstraint *imageViewRight = [NSLayoutConstraint constraintWithItem:self.theWheel
                                                                          attribute:NSLayoutAttributeRight
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self
                                                                          attribute:NSLayoutAttributeRight
                                                                         multiplier:1.0
                                                                           constant:0.0];
        NSLayoutConstraint *imageViewBottom = [NSLayoutConstraint constraintWithItem:self.theWheel
                                                                           attribute:NSLayoutAttributeBottom
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:self
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1.0
                                                                            constant:0.0];

        [self addConstraints:@[imageViewTop, imageViewLeft, imageViewRight, imageViewBottom]];
    }

    if (!self.wheelOver) {

        self.wheelOver                                           =
            [[UIImageView alloc] initWithImage:self.wheelOverImage];
        self.wheelOver.translatesAutoresizingMaskIntoConstraints = NO;
        self.wheelOver.contentMode                               = UIViewContentModeScaleAspectFit;
        self.wheelOver.transform                                 = CGAffineTransformMakeRotation(
            self.wheelInitialRotation);
        self.wheelOver.hidden                                    = YES;
        [self.theWheel addSubview:self.wheelOver];

        NSLayoutConstraint *imageViewTop = [NSLayoutConstraint constraintWithItem:self.wheelOver
                                                                        attribute:NSLayoutAttributeTop
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:self
                                                                        attribute:NSLayoutAttributeTop
                                                                       multiplier:1.0
                                                                         constant:0.0];
        NSLayoutConstraint *imageViewLeft = [NSLayoutConstraint constraintWithItem:self.wheelOver
                                                                         attribute:NSLayoutAttributeLeft
                                                                         relatedBy:NSLayoutRelationEqual
                                                                            toItem:self
                                                                         attribute:NSLayoutAttributeLeft
                                                                        multiplier:1.0
                                                                          constant:0.0];
        NSLayoutConstraint *imageViewRight = [NSLayoutConstraint constraintWithItem:self.wheelOver
                                                                          attribute:NSLayoutAttributeRight
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:self
                                                                          attribute:NSLayoutAttributeRight
                                                                         multiplier:1.0
                                                                           constant:0.0];
        NSLayoutConstraint *imageViewBottom = [NSLayoutConstraint constraintWithItem:self.wheelOver
                                                                           attribute:NSLayoutAttributeBottom
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:self
                                                                           attribute:NSLayoutAttributeBottom
                                                                          multiplier:1.0
                                                                            constant:0.0];

        [self addConstraints:@[imageViewTop, imageViewLeft, imageViewRight, imageViewBottom]];
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
    self.animationDecelerationFactor        = kAZWheelPickerDefaultDeceleration;
    self.currentIndex                       = -1;
    self.wheelOver.hidden                   = YES;
//end

    self.isTouchDown                        = YES;
    self.isTouchMoved                       = NO;
    self.isRotatingByTimerWhenThisTapHappen = NO;

    if (self.inertiaTimer) {

        self.isRotatingByTimerWhenThisTapHappen = YES;
        [self stopInertiaTimer];
    }

    CGPoint pos = [[touches anyObject] locationInView:self];
    self.lastAtan2      = atan2(pos.y - CGRectGetWidth(self.theWheel.frame) / 2.0,
                                pos.x - CGRectGetHeight(self.theWheel.frame) / 2.0);

    self.lastMovedTime1 = 0;
    self.lastMovedTime2 = 0;
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event {

    self.isTouchMoved = YES;

    if (self.isTouchDown) {

        CGPoint pos     = [[touches anyObject] locationInView:self];
        float thisAtan2 = atan2(pos.y - CGRectGetWidth(self.theWheel.frame) / 2.0,
                                pos.x - CGRectGetHeight(self.theWheel.frame) / 2.0);

        CGFloat delta   = thisAtan2 - self.lastAtan2;

        // don't allow ccw movement
        if (delta < 0) {

            return;
        }

        // check if the next rotation will change the index and tell delegate
        int index             = [self rotation2index:_currentRotation];
        int nextRotationIndex = [self rotation2index:_currentRotation + delta];

        if (index != nextRotationIndex) {

            if ([self.delegate respondsToSelector:@selector(wheelView:willPassThroughIndex:withVelocity:)]) {

                [self.delegate wheelView:self willPassThroughIndex:nextRotationIndex withVelocity:delta];
            }
        }

        self.lastDelta          = delta;
        _currentRotation       += self.lastDelta;
        //NSLog(@"_currentRotation %f",_currentRotation);

        self.theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);


        self.lastAtan2          = thisAtan2;

        self.lastMovedTime1     = self.lastMovedTime2;
        self.lastMovedTime2     = [NSDate timeIntervalSinceReferenceDate];
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

- (float)randomFloatBetween:(float)smallNumber and:(float)bigNumber {
    float diff = bigNumber - smallNumber;

    return (((float)(arc4random() % ((unsigned)RAND_MAX + 1)) / RAND_MAX) * diff) + smallNumber;
}

- (void)continueByInertia2 {

    NSTimeInterval interval = (self.lastMovedTime2 - self.lastMovedTime1);
    CGFloat minDelta = self.enforceMinimumSpeed ? kMinimumDeltaEnforce : kMinimumDeltaNoEnforce;

    // only allow clockwise rotation
    // if we don't enforce minimum speed,
    // then, if speed is lower than minimum don't consider the wheel spinning
    // let it end the movement but allow for gestures to continue spinning it
    self.currentSpeed = fabsf(self.lastDelta);
    if(self.enforceMinimumSpeed){
    
        self.currentSpeed = MAX(self.currentSpeed, minDelta);
    }
    
    self.fullySpinning = self.currentSpeed >= minDelta;
    
    if(!self.fullySpinning
       && [self.delegate respondsToSelector:@selector(wheelView:startSpinSpeed:belowMinimumSpeed:)]){
    
        [self.delegate wheelView:self startSpinSpeed:self.currentSpeed belowMinimumSpeed:minDelta];
    }

    //NSLog(@"speed: %f", self.currentSpeed);
    //NSLog(@"-----------------");
    
    if(self.fullySpinning
       && [self.delegate respondsToSelector:@selector(wheelViewDidStartSpinning:)]){
    
        [self.delegate wheelViewDidStartSpinning:self];
    }
    self.canBreak          = NO;
    self.chooseSectorSpeed = [self randomFloatBetween:kAZWheelPickerMinChooseSectorSpeed
                                                  and:kAZWheelPickerMaxChooseSectorSpeed];

    self.inertiaTimer      = [NSTimer scheduledTimerWithTimeInterval:kTimePerFrame
                                                              target:self
                                                            selector:@selector(onInertiaTimer2)
                                                            userInfo:nil
                                                             repeats:YES];
    [self onInertiaTimer2];             // execute once immediately

}

- (void)onInertiaTimer2 {

    _currentRotation   += _currentSpeed;
    _theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);
    if(self.fullySpinning && ( _desiredIndex == -1 || !_canBreak)){
    
        _currentSpeed = MAX(_chooseSectorSpeed,_currentSpeed*_animationDecelerationFactor);
    } else if(!self.fullySpinning || _currentSpeed > kAZWheelPickerDefaultMinimumSpeed){
        
        _currentSpeed *= _animationDecelerationFactor;
    }
    //_currentSpeed *= _animationDecelerationFactor;

    int index = [self rotation2index:_currentRotation];

    // choose the desired index, at kAZWheelPickerChooseSectorSpeed speed, a full turn of the wheel is garanteed
    if (!_canBreak && _desiredIndex != -1 && fabsf(_currentSpeed) <= _chooseSectorSpeed) {

        //NSLog(@"chooseSpeed: %f", _currentSpeed);

        if (_currentIndex != index) {

            _currentIndex = index;

            int distanceToIndex = self.currentIndex - self.desiredIndex;

            if (distanceToIndex < 0) {
                distanceToIndex = distanceToIndex + self.numberOfSectors;
            }

            if (distanceToIndex == self.numberOfSectors - 1) {
                _canBreak = YES;
                //NSLog(@"setting can break true");
            }

            //NSLog(@"distance to index %d speed %f",distanceToIndex,_currentSpeed);
        }
    }
    
    BOOL shouldStopDueToSpeed = _desiredIndex != -1 && fabsf(_currentSpeed) <= kAZWheelPickerDefaultMinimumSpeed;
    BOOL forceStop = NO;
    // if we can break and will go over our desired index then stop
    if (!shouldStopDueToSpeed
        && _canBreak
        && _desiredIndex == [self rotation2index:_currentRotation]
        && _desiredIndex != [self rotation2index:_currentRotation + _currentSpeed]) {

        forceStop = YES;
        //NSLog(@"Forcing the wheel to stop at speed %f",_currentSpeed);
    }

    //stop the wheel
    if (forceStop || shouldStopDueToSpeed) {

        if (_desiredIndex != -1
            && _desiredIndex != index) {

            // this may happen if we would stop a bit before or after the desired index
            //NSLog(@"Can't stop because we are not on the desired index");

        } else {

            [self stopInertiaTimer];

            NSAssert(self.fullySpinning
                     && _desiredIndex != -1
                     && index==_desiredIndex,
                     @"selecting wrong index");
            
            //NSLog(@"wheel stopped");
            //NSLog(@"Rotation: %f", self.currentRotation);
            //NSLog(@"index: %d", index);


            [self placeWheelOverAtIndex:index];

            //NSLog(@"-----------------");

            [self fixPositionByRotationAnimated:YES];
            
            if (self.fullySpinning && [self.delegate respondsToSelector:@selector(wheelViewDidEndSpinning:)]) {
                
                [self.delegate wheelViewDidEndSpinning:self];
            }
        }
    }

    // if we are still rotating, check if the next rotation will change the index and tell delegate
    if (self.inertiaTimer) {

        int nextRotationIndex = [self rotation2index:_currentRotation + _currentSpeed];

        if (index != nextRotationIndex) {

            if ([self.delegate respondsToSelector:@selector(wheelView:willPassThroughIndex:withVelocity:)]) {

                [self.delegate wheelView:self willPassThroughIndex:nextRotationIndex withVelocity:_currentSpeed];
            }
        }
    }
}

- (void)placeWheelOverAtIndex:(int)index {

    //NSLog(@"Placing over at %d", index);
//    [self.theWheel addSubview:self.wheelOver];

    self.wheelOver.hidden    = NO;

    self.wheelOver.transform = CGAffineTransformMakeRotation(-[self index2rotation:index]);
}

- (int)distanceToIndex:(NSUInteger)index {

    int dist = self.currentIndex - self.desiredIndex;

    if (dist < 0) {
        dist = dist + self.numberOfSectors;
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
    
    // if we are setting indeterminate index
    // then don't notify delegate of value change nor move the wheel
    if(selectedIndex == -1){
        
        return;
    }

    CGFloat oldAngle   = _currentRotation;
    CGFloat newAngle   = [self index2rotation:selectedIndex];

    _currentRotation = newAngle;

    CGFloat a = [self distanceBetweenAnglesAlpha:newAngle beta:oldAngle];
    //NSLog(@"Correcting angle %f: %@", a, a < 0 ? @"YES" : @"NO");
    [self stopInertiaTimer];

    if (isChanged) {

        [self sendActionsForControlEvents:UIControlEventValueChanged];

        if ([self.delegate respondsToSelector:@selector(wheelView:didSelectItemAtIndex:)]) {

            [self.delegate wheelView:self didSelectItemAtIndex:selectedIndex];
        }
    }

    [UIView animateWithDuration:animated ? kCorrectionAnimationDuration : 0
                          delay:0.8
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{

         self.theWheel.transform = CGAffineTransformMakeRotation(_currentRotation);

     }
                     completion:^(BOOL finished) {

         if (animated && [self.delegate respondsToSelector:@selector(wheelViewDidEndSpinning:)]) {

             [self.delegate wheelViewDidEndSpinning:self];
         }
     }];
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

@end
