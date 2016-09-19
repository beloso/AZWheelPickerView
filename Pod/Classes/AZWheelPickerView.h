//
//  AZWheelPickerView.h
//  az-garage
//
//  Created by Yang Zhang on 12/27/12.
//  Copyright (c) 2012 Albert Zhang. All rights reserved.
//

#import <UIKit/UIKit.h>

#if !__has_feature(objc_arc)
#error AZWheelPickerView must be built with ARC.
// You can turn on ARC for only AZWheelPickerView files by adding -fobjc-arc to the build phase for each of its files.
#endif

@protocol AZWheelPickerViewDelegate;

@interface AZWheelPickerView : UIControl
{
	@private
	UIImageView *theWheel;
	
	CGSize wheelSize;
	
	BOOL isTouchDown;
	BOOL isTouchMoved;
	float lastAtan2;
	
	float lastDuration;
	float currentSpeed;
	NSTimeInterval lastMovedTime1;
	NSTimeInterval lastMovedTime2;
	
	NSTimer *inertiaTimer;
	BOOL isRotatingByTimerWhenThisTapHappen;
}

@property (nonatomic, weak) id<AZWheelPickerViewDelegate> delegate;

/**
 The UIImage of the spin wheel. Generally it is circle.
 */
@property (nonatomic, strong) UIImage *wheelImage;

/**
 The initial rotation of the wheel. In most case the wheel's position is not match
 with the pointer, you can set a inital rotation to correct it.
 */
@property (nonatomic, assign) float wheelInitialRotation;

/**
 A wheel is made up by several sectors each of them have the same angle.
 Specify the number of sectors here.
 */
@property (nonatomic, assign) int numberOfSectors;

/**
 The index is inside [0, numberOfSectors - 1]
 */
@property (nonatomic, assign) int selectedIndex;

/**
 The deceleration of the animation. The default is kAZWheelPickerDefaultDeceleration (0.97).
 */
@property (nonatomic, assign) float animationDecelerationFactor;

@property (nonatomic, assign) float maximumSpeed;
@property (nonatomic, assign) float minimumSpeed;

/**
 If set to YES, the UIControlEventValueChanged event will be send every time a sector pass by
 when animating. Else the event will be send after the animation stopped.
 */
@property (nonatomic, assign) BOOL continuousTrigger;

- (void)setSelectedIndex:(int)selectedIndex animated:(BOOL)animated;

@end


@protocol AZWheelPickerViewDelegate <NSObject>

@optional
- (void)wheelViewDidStartSpinning:(AZWheelPickerView *)wheelView;
- (void)wheelViewDidEndSpinning:(AZWheelPickerView *)wheelView;

- (void)wheelView:(AZWheelPickerView *)wheelView didSelectItemAtIndex:(NSUInteger)index;

@end