//
//  AZWheelPickerView.m
//  az-garage
//
//  Created by Yang Zhang on 12/27/12.
//  Copyright (c) 2012 Albert Zhang. All rights reserved.
//

#import "AZWheelPickerView.h"
#import <QuartzCore/QuartzCore.h>

#define kAZWheelPickerDefaultDeceleration       0.97
#define kAZWheelPickerDefaultMinimumSpeed       0.01
#define kAZWheelPickerInertiaTimerAcceptableMaxInterval (1.0 / 30.0) // xx fps
#define kAZWheelPickerInertiaTimerAcceptableMinInterval (1.0 / 60.0) // xx fps

@interface AZWheelPickerView ()

@property (nonatomic, assign) CGFloat currentRotation;
@property (nonatomic, strong) CABasicAnimation *rotatingAnimation;

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
    self.minimumSpeed                = kAZWheelPickerDefaultMinimumSpeed;
    self.maximumSpeed                = INT_MAX;
    self.continuousTrigger           = NO;
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

    if (!theWheel) {
        theWheel           = [[UIImageView alloc] initWithImage:self.wheelImage];
        theWheel.transform = CGAffineTransformMakeRotation(self.wheelInitialRotation);
        [self addSubview:theWheel];

        wheelSize          = self.wheelImage.size;
    }

    [self fixPositionByIndexAnimated:NO];
}

#pragma mark -

- (void)stopInertiaTimer {

    if (inertiaTimer) {

        [inertiaTimer invalidate];
        inertiaTimer = nil;
    }
}

#pragma mark -

- (void)touchesBegan:(NSSet *)touches
           withEvent:(UIEvent *)event {

    isTouchDown                        = YES;
    isTouchMoved                       = NO;
    isRotatingByTimerWhenThisTapHappen = NO;

    if (inertiaTimer) {

        isRotatingByTimerWhenThisTapHappen = YES;
        [self stopInertiaTimer];
    }

    CGPoint pos = [[touches anyObject] locationInView:self];
    lastAtan2      = atan2(pos.y - wheelSize.width / 2,
                           pos.x - wheelSize.height / 2);

    lastMovedTime1 = 0;
    lastMovedTime2 = 0;
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event {

    isTouchMoved = YES;

    if (isTouchDown) {

        CGPoint pos     = [[touches anyObject] locationInView:self];
        float thisAtan2 = atan2(pos.y - wheelSize.width / 2,
                                pos.x - wheelSize.height / 2);

        float dur       = thisAtan2 - lastAtan2;

        if (self.continuousTrigger) {

            self.currentRotation += dur;

        } else {

            _currentRotation += dur;

            [self rotateToCurrentRotationAnimated:NO];
        }

        lastAtan2      = thisAtan2;

        lastMovedTime1 = lastMovedTime2;
        lastMovedTime2 = [NSDate timeIntervalSinceReferenceDate];

        lastDuration   = dur;
    }
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event {

    isTouchDown = NO;

    [self handleTouchesEndedOrCancelled:touches];

}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event {

    isTouchDown = NO;

    [self handleTouchesEndedOrCancelled:touches];
}

- (void)handleTouchesEndedOrCancelled:(NSSet *)touches {

    if (isTouchMoved) {

        [self continueByInertia];

    } else {

        [self fixPositionByRotationAnimated:YES];
    }
}

#pragma mark -


- (void)continueByInertia {

    NSTimeInterval interval = (lastMovedTime2 - lastMovedTime1);

    if (inertiaTimer) {

        return;
    } else if (interval == 0 || interval > kAZWheelPickerInertiaTimerAcceptableMaxInterval) {

        [self fixPositionByRotationAnimated:YES];

    } else {

        currentSpeed = MIN(lastDuration, self.maximumSpeed);

        if (interval < kAZWheelPickerInertiaTimerAcceptableMinInterval) {

            currentSpeed = kAZWheelPickerInertiaTimerAcceptableMinInterval * currentSpeed / interval;
            interval     = kAZWheelPickerInertiaTimerAcceptableMinInterval;
        }

        inertiaTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                        target:self
                                                      selector:@selector(onInertiaTimer)
                                                      userInfo:nil
                                                       repeats:YES];
        [self onInertiaTimer];     // excute once immediately

        if (self.delegate &&
            [self.delegate conformsToProtocol:@protocol(AZWheelPickerViewDelegate)] &&
            [self.delegate respondsToSelector:@selector(wheelViewDidStartSpinning:)]) {

            [self.delegate wheelViewDidStartSpinning:self];
        }
    }
}

- (void)onInertiaTimer {

    if (self.continuousTrigger) {

        self.currentRotation += currentSpeed;

    } else {

        _currentRotation += currentSpeed;
        [self rotateToCurrentRotationAnimated:NO];

    }

    currentSpeed *= self.animationDecelerationFactor;
    currentSpeed  = MAX(currentSpeed, self.minimumSpeed);

    if (fabsf(currentSpeed) < 0.01) {

        [self stopInertiaTimer];
        [self fixPositionByRotationAnimated:YES];

        if (self.delegate &&
            [self.delegate conformsToProtocol:@protocol(AZWheelPickerViewDelegate)] &&
            [self.delegate respondsToSelector:@selector(wheelViewDidEndSpinning:)]) {

            [self.delegate wheelViewDidEndSpinning:self];
        }
    }
}

#pragma mark -

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

- (void)rotateToCurrentRotationAnimated:(BOOL)animated {

    [self rotateToCurrentRotationAnimated:animated completion:nil];
}

- (void)rotateToCurrentRotationAnimated:(BOOL)animated completion:(void (^)(void))completion {

    [self rotateToCurrentRotationAnimated:animated needsCorrection:NO completion:completion];
}

- (void)rotateToCurrentRotationAnimated:(BOOL)animated
                        needsCorrection:(BOOL)correction
                             completion:(void (^)(void))completion {

    CGFloat duration = 1.0;
    CGFloat maxSteps = 2.0;
    
    typeof(self) weakself = self;
    [UIView animateKeyframesWithDuration:currentSpeed
                                   delay:0.0
                                 options:UIViewKeyframeAnimationOptionCalculationModeLinear
                              animations:^{

         if (!correction) {

             [UIView addKeyframeWithRelativeStartTime:0
                                     relativeDuration:1.0 / duration
                                           animations:^{
                  theWheel.transform = CGAffineTransformMakeRotation(weakself.currentRotation);
              }];

         } else {
             
             [UIView addKeyframeWithRelativeStartTime:0
                                     relativeDuration:duration / maxSteps
                                           animations:^{
                  theWheel.transform = CGAffineTransformRotate(theWheel.transform, M_PI);
              }];

             [UIView addKeyframeWithRelativeStartTime:1.0 / maxSteps
                                     relativeDuration:duration / maxSteps
                                           animations:^{
                  theWheel.transform = CGAffineTransformMakeRotation(weakself.currentRotation);
              }];
         }
     }
                              completion:^(BOOL finished) {
         if (completion) {

             completion();
         }
     }];

//    dispatch_block_t animationBlock = ^{
//
//        theWheel.transform = CGAffineTransformMakeRotation(self.currentRotation);
//    };
//
//    [UIView animateWithDuration:animated ? 0.3 : 0.0
//                     animations:^{
//                         animationBlock();
//                     }
//                     completion:^(BOOL finished) {
//
//                         if (completion) {
//
//                             completion();
//                         }
//                     }];
}

- (void)setCurrentRotation:(float)currentRotation {

    [self setCurrentRotation:currentRotation animated:NO];
}

- (void)setCurrentRotation:(float)currentRotation
                  animated:(BOOL)animated {

    _currentRotation = currentRotation;

    int index      = [self rotation2index:currentRotation];

    BOOL isChanged = (_selectedIndex != index);
    _selectedIndex = index;

    [self stopInertiaTimer];
    [self rotateToCurrentRotationAnimated:animated completion:^{

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

            [self.delegate wheelView:self didSelectItemAtIndex:index];
        }
    }
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
    [self rotateToCurrentRotationAnimated:animated needsCorrection:(a < 0) completion:^{

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
