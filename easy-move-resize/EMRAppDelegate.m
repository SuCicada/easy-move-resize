#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"
#import "EMRPreferences.h"

@implementation EMRAppDelegate {
    EMRPreferences *preferences;
}

- (id) init  {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
        preferences = [[EMRPreferences alloc] initWithUserDefaults:userDefaults];
    }
    return self;
}

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {

    EMRAppDelegate *ourDelegate = (__bridge EMRAppDelegate*)refcon;
    int keyModifierFlags = [ourDelegate modifierFlags];
    bool shouldMiddleClickResize = [ourDelegate shouldMiddleClickResize];
    bool resizeOnly = [ourDelegate resizeOnly];
    CGEventType resizeModifierDown = kCGEventRightMouseDown;
    CGEventType resizeModifierDragged = kCGEventRightMouseDragged;
    CGEventType resizeModifierUp = kCGEventRightMouseUp;
    bool handled = NO;

    if (![ourDelegate sessionActive]) {
        return event;
    }

    if (keyModifierFlags == 0) {
        // No modifier keys set. Disable behaviour.
        return event;
    }
    
//    NSLog(@"keyModifierFlags: %d ", keyModifierFlags);
    
    if (shouldMiddleClickResize){
//        resizeModifierDown = kCGEventOtherMouseDown;
//        resizeModifierDragged = kCGEventOtherMouseDragged;
//        resizeModifierUp = kCGEventOtherMouseUp;
        resizeModifierDown = kCGEventLeftMouseDown;
        resizeModifierDragged = kCGEventLeftMouseDragged;
        resizeModifierUp = kCGEventLeftMouseUp;
    }
    
    EMRMoveResize* moveResize = [EMRMoveResize instance];

    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        // need to re-enable our eventTap (We got disabled.  Usually happens on a slow resizing app)
        CGEventTapEnable([moveResize eventTap], true);
        return event;
    }
    
    CGEventFlags flags = CGEventGetFlags(event);
    
    
    int moveKeyModifierFlag = kCGEventFlagMaskAlternate | kCGEventFlagMaskControl;
    int resizeKeyModifierFlag = kCGEventFlagMaskAlternate | kCGEventFlagMaskControl | kCGEventFlagMaskShift;
    
    int mode = 0; // 1.move 2.resize
    
    if ((flags & (moveKeyModifierFlag)) == (moveKeyModifierFlag)) {
        mode = 1;
//        NSLog(@"Control+Option");
    }
    if ((flags & (resizeKeyModifierFlag)) == (resizeKeyModifierFlag)) {
        mode = 2;
//        NSLog(@"Shift+Control+Option");
    }
    
    
    if (mode == 0) {
        // didn't find our expected modifiers; this event isn't for us
//        NSLog(@"not keyModifierFlags, skip");
        return event;
    }

    int ignoredKeysMask = (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn) ^ keyModifierFlags;
    
    if (flags & ignoredKeysMask) {
        // also ignore this event if we've got extra modifiers (i.e. holding down Cmd+Ctrl+Alt should not invoke our action)
        NSLog(@"ignoredKeysMask, skip");
        return event;
    }
    
    
    
    // move or resize
    if ((type == kCGEventLeftMouseDown && !resizeOnly)
            || type == resizeModifierDown) {
        // 2. 获取鼠标点击位置
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:CACurrentMediaTime()];

        AXUIElementRef _systemWideElement;
        AXUIElementRef _clickedWindow = NULL;
        _systemWideElement = AXUIElementCreateSystemWide();

// 3. 使用 AXUIElementCopyElementAtPosition 获取鼠标位置下的元素
        AXUIElementRef _element;
        NSLog(@"Trying to get element at position: (%.2f, %.2f)", mouseLocation.x, mouseLocation.y);

        AXError error = AXUIElementCopyElementAtPosition(_systemWideElement, 
                                                (float)mouseLocation.x, 
                                                (float)mouseLocation.y, 
                                                &_element);

        NSLog(@"AXUIElementCopyElementAtPosition result: %d", error);

        // 检查具体的错误码
        switch(error) {
            case kAXErrorSuccess:
                NSLog(@"Success");
                break;
            case kAXErrorFailure:
                NSLog(@"General failure");
                break;
            case kAXErrorIllegalArgument:
                NSLog(@"Illegal argument");
                break;
            case kAXErrorInvalidUIElement:
                NSLog(@"Invalid UI element");
                break;
            case kAXErrorInvalidUIElementObserver:
                NSLog(@"Invalid observer");
                break;
            case kAXErrorCannotComplete:
                NSLog(@"Cannot complete");
                break;
            case kAXErrorAttributeUnsupported:
                NSLog(@"Attribute unsupported");
                break;
            case kAXErrorActionUnsupported:
                NSLog(@"Action unsupported");
                break;
            case kAXErrorNotificationUnsupported:
                NSLog(@"Notification unsupported");
                break;
            case kAXErrorNotImplemented:
                NSLog(@"Not implemented");
                break;
            case kAXErrorNotificationAlreadyRegistered:
                NSLog(@"Notification already registered");
                break;
            case kAXErrorNotificationNotRegistered:
                NSLog(@"Notification not registered");
                break;
            case kAXErrorAPIDisabled:
                NSLog(@"API disabled - check accessibility permissions");
                break;
            case kAXErrorNoValue:
                NSLog(@"No value");
                break;
            case kAXErrorParameterizedAttributeUnsupported:
                NSLog(@"Parameterized attribute unsupported");
                break;
            case kAXErrorNotEnoughPrecision:
                NSLog(@"Not enough precision");
                break;
            default:
                NSLog(@"Unknown error: %d", error);
                break;
        }

        // 在AXUIElementCopyElementAtPosition失败后添加备用方案
        if ((AXUIElementCopyElementAtPosition(_systemWideElement, (float) mouseLocation.x, (float) mouseLocation.y, &_element) == kAXErrorSuccess) && _element) {
    // 4. 检查获取到的元素的角色
            CFTypeRef _role;
            if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &_role) == kAXErrorSuccess) {
                NSString *roleString = (__bridge NSString *)_role;
                NSLog(@"Element role: %@", roleString);  // 添加日志，查看元素的角色
                
                _clickedWindow = findWindowForElement(_element);
                if (_clickedWindow) {
                    NSLog(@"Found window through hierarchy");
                }
                
                if (_role != NULL) CFRelease(_role);
            } else {
                NSLog(@"Failed to get role");  // 获取角色失败
            }
            
            if (_element != NULL) CFRelease(_element);
        } else {
            NSLog(@"Failed to get element at position: %f, %f", mouseLocation.x, mouseLocation.y);
            NSLog(@"Trying to 备用方案：使用CGWindowListCopyWindowInfo获取窗口信息");
            // 备用方案：使用CGWindowListCopyWindowInfo获取窗口信息
            _clickedWindow = getWindowAtPosition(mouseLocation);
            if (_clickedWindow) {
                NSLog(@"Found window through CGWindowListCopyWindowInfo");
            }
        }
        CFRelease(_systemWideElement);
        
        if (_clickedWindow == NULL) {
            NSLog(@"Failed to find window");
            [moveResize setTracking:0];
            return event;
        }

        pid_t PID;
        NSRunningApplication* app = nil;
        if(_clickedWindow && !AXUIElementGetPid(_clickedWindow, &PID)) {
            app = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
            if ([[ourDelegate getDisabledApps] objectForKey:[app bundleIdentifier]] != nil) {
                [moveResize setTracking:0];
                return event;
            }
            [ourDelegate setMostRecentApp:app];
        }

        if([ourDelegate shouldBringWindowToFront]){
            if (app != nil && _clickedWindow != NULL) {
                [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
                AXUIElementPerformAction(_clickedWindow, kAXRaiseAction);
            }
        }
        
        CFTypeRef _cPosition = nil;
        NSPoint cTopLeft;
        
        NSLog(@" _clickedWindow %p",_clickedWindow);
        if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow,
                                          (__bridge CFStringRef)NSAccessibilityPositionAttribute,
                                          &_cPosition
                                          ) == kAXErrorSuccess) {
            NSLog(@" in AXUIElementCopyAttributeValue ");
            if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
                NSLog(@"ERROR: Could not decode position: %f,%f",cTopLeft.x,cTopLeft.y);
                cTopLeft = NSMakePoint(0, 0);
            }
            CFRelease(_cPosition);
        }
        
        cTopLeft.x = (int) cTopLeft.x;
        cTopLeft.y = (int) cTopLeft.y;

        // save clicked window info
        [moveResize setWndPosition:cTopLeft];
        [moveResize setWindow:_clickedWindow];
        
        NSLog(@"[kCGEventLeftMouseDown] cTopLeft: %f, %f ", cTopLeft.x,cTopLeft.y);
        
        if (_clickedWindow != nil) CFRelease(_clickedWindow);
        handled = YES;
    }

    // move
    if (type == kCGEventLeftMouseDragged
            && [moveResize tracking] > 0 && mode==1) {
        AXUIElementRef _clickedWindow = [moveResize window];
        double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSPoint thePoint;
        thePoint.x = cTopLeft.x + deltaX;
        thePoint.y = cTopLeft.y + deltaY;
        [moveResize setWndPosition:thePoint];
        CFTypeRef _position;

        // actually applying the change is expensive, so only do it every kMoveFilterInterval seconds
        if (CACurrentMediaTime() - [moveResize tracking] > kMoveFilterInterval) {
            _position = (CFTypeRef) (AXValueCreate(kAXValueCGPointType, (const void *) &thePoint));
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef) NSAccessibilityPositionAttribute, (CFTypeRef *) _position);
            if (_position != NULL) CFRelease(_position);
            [moveResize setTracking:CACurrentMediaTime()];
        }
        handled = YES;
    }

    if (type == resizeModifierDown && mode == 2) {
        AXUIElementRef _clickedWindow = [moveResize window];

        // on resizeModifierDown click, record which direction we should resize in on the drag
        struct ResizeSection resizeSection;

        CGPoint clickPoint = CGEventGetLocation(event);

        NSPoint cTopLeft = [moveResize wndPosition];

        clickPoint.x -= cTopLeft.x;
        clickPoint.y -= cTopLeft.y;

        CFTypeRef _cSize;
        NSSize cSize;
        if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
                || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
            NSLog(@"ERROR: Could not decode size");
            return NULL;
        }
        CFRelease(_cSize);

        NSSize wndSize = cSize;

//        if (clickPoint.x < wndSize.width/3) {
//            resizeSection.xResizeDirection = left;
//        } else if (clickPoint.x > 2*wndSize.width/3) {
//            resizeSection.xResizeDirection = right;
//        } else {
            resizeSection.xResizeDirection = right;
//        }

//        if (clickPoint.y < wndSize.height/3) {
//            resizeSection.yResizeDirection = bottom;
//        } else  if (clickPoint.y > 2*wndSize.height/3) {
//            resizeSection.yResizeDirection = top;
//        } else {
            resizeSection.yResizeDirection = top;
//        }

        [moveResize setWndSize:wndSize];
        [moveResize setResizeSection:resizeSection];
        handled = YES;
    }
    
    // resize drag
    if (type == resizeModifierDragged
            && [moveResize tracking] > 0 && mode==2 ) {
        AXUIElementRef _clickedWindow = [moveResize window];
        struct ResizeSection resizeSection = [moveResize resizeSection];
        int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);
//        NSLog(@"deltaX: %d, deltaY: %d", deltaX, deltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSSize wndSize = [moveResize wndSize];

        switch (resizeSection.xResizeDirection) {
            case right:
                wndSize.width += deltaX;
                break;
            case left:
                wndSize.width -= deltaX;
                cTopLeft.x += deltaX;
                break;
            case noX:
                // nothing to do
                break;
            default:
                [NSException raise:@"Unknown xResizeSection" format:@"No case for %d", resizeSection.xResizeDirection];
        }

        switch (resizeSection.yResizeDirection) {
            case top:
                wndSize.height += deltaY;
                break;
            case bottom:
                wndSize.height -= deltaY;
                cTopLeft.y += deltaY;
                break;
            case noY:
                // nothing to do
                break;
            default:
                [NSException raise:@"Unknown yResizeSection" format:@"No case for %d", resizeSection.yResizeDirection];
        }
        
//        NSLog(@"cTopLeft: %f, %f . wndSize: %f, %f", cTopLeft.x,cTopLeft.y,
//              wndSize.width, wndSize.height);
        
        [moveResize setWndPosition:cTopLeft];
        [moveResize setWndSize:wndSize];

        // actually applying the change is expensive, so only do it every kResizeFilterInterval events
        if (CACurrentMediaTime() - [moveResize tracking] > kResizeFilterInterval) {
            // only make a call to update the position if we need to
            if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                AXUIElementSetAttributeValue(_clickedWindow,
                                             (__bridge CFStringRef)NSAccessibilityPositionAttribute,
                                             (CFTypeRef *)_position);
                
                CFRelease(_position);
            }

            CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
            AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow,
                                         (__bridge CFStringRef)NSAccessibilitySizeAttribute,
                                         (CFTypeRef *)_size);
            CFRelease(_size);
            [moveResize setTracking:CACurrentMediaTime()];
        }
        handled = YES;
    }

    if ((type == kCGEventLeftMouseUp || type == resizeModifierUp)
        && [moveResize tracking] > 0) {
        [moveResize setTracking:0];
        handled = YES;
    }
    
    if (handled) {
        return NULL;
    }
    else {
        return event;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    const void * keys[] = { kAXTrustedCheckOptionPrompt };
    const void * values[] = { kCFBooleanTrue };

    CFDictionaryRef options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    if (!AXIsProcessTrustedWithOptions(options)) {
        // don't have permission to do our thing right now... AXIsProcessTrustedWithOptions prompted the user to fix
        // this, so hopefully on next launch we'll be good to go
        NSLog(@"Missing permissions");
        exit(1);
    }
    
    [self initMenuItems];

    // Retrieve the Key press modifier flags to activate move/resize actions.
    keyModifierFlags = [preferences modifierFlags];
    
    CFRunLoopSourceRef runLoopSource;

    CGEventMask eventMask = CGEventMaskBit( kCGEventLeftMouseDown )
                    | CGEventMaskBit( kCGEventRightMouseDown )
                    | CGEventMaskBit( kCGEventOtherMouseDown )
                    | CGEventMaskBit( kCGEventLeftMouseDragged )
                    | CGEventMaskBit( kCGEventRightMouseDragged )
                    | CGEventMaskBit( kCGEventOtherMouseDragged )
                    | CGEventMaskBit( kCGEventLeftMouseUp )
                    | CGEventMaskBit( kCGEventRightMouseUp )
                    | CGEventMaskBit( kCGEventOtherMouseUp )
    ;

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);


    EMRMoveResize *moveResize = [EMRMoveResize instance];
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];
    CFRelease(runLoopSource);

    _sessionActive = true;
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameActive:)
            name:NSWorkspaceSessionDidBecomeActiveNotification
            object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameInactive:)
            name:NSWorkspaceSessionDidResignActiveNotification
            object:nil];
    
    [self reconstructDisabledAppsSubmenu];
}

- (void)becameActive:(NSNotification*) notification {
    _sessionActive = true;
}

- (void)becameInactive:(NSNotification*) notification {
    _sessionActive = false;
}

-(void)awakeFromNib{
    NSImage *icon = [NSImage imageNamed:@"MenuIcon"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:icon];
    [statusMenu setAutoenablesItems:NO];
    [[statusMenu itemAtIndex:0] setEnabled:NO];
}

- (void)enableRunLoopSource:(EMRMoveResize*)moveResize {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
    CGEventTapEnable([moveResize eventTap], true);
}

- (void)disableRunLoopSource:(EMRMoveResize*)moveResize {
    CGEventTapEnable([moveResize eventTap], false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
}

- (void)initMenuItems {
    [_altMenu setState:0];
    [_cmdMenu setState:0];
    [_ctrlMenu setState:0];
    [_shiftMenu setState:0];
    [_fnMenu setState:0];
    [_disabledMenu setState:0];
    [_bringWindowFrontMenu setState:0];
    [_middleClickResizeMenu setState:0];

    bool shouldBringWindowToFront = [preferences shouldBringWindowToFront];
    bool shouldMiddleClickResize = [preferences shouldMiddleClickResize];
    bool resizeOnly = [preferences resizeOnly];

    if(shouldBringWindowToFront){
        [_bringWindowFrontMenu setState:1];
    }
    if(shouldMiddleClickResize){
        [_middleClickResizeMenu setState:1];
    }
    if(resizeOnly){
        [_resizeOnlyMenu setState:1];
    }
    
    NSSet* flags = [preferences getFlagStringSet];
    if ([flags containsObject:ALT_KEY]) {
        [_altMenu setState:1];
    }
    if ([flags containsObject:CMD_KEY]) {
        [_cmdMenu setState:1];
    }
    if ([flags containsObject:CTRL_KEY]) {
        [_ctrlMenu setState:1];
    }
    if ([flags containsObject:SHIFT_KEY]) {
        [_shiftMenu setState:1];
    }
    if ([flags containsObject:FN_KEY]) {
        [_fnMenu setState:1];
    }
}

- (IBAction)modifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setModifierKey:[menu title] enabled:newState];
    keyModifierFlags = [preferences modifierFlags];
}

- (IBAction)resetToDefaults:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    [preferences setToDefaults];
    [self initMenuItems];
    [self setMenusEnabled:YES];
    [self enableRunLoopSource:moveResize];
    keyModifierFlags = [preferences modifierFlags];
}

- (IBAction)toggleBringWindowToFront:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldBringWindowToFront:newState];
}

- (IBAction)toggleMiddleClickResize:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldMiddleClickResize:newState];
}

- (IBAction)toggleDisabled:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    if ([_disabledMenu state] == 0) {
        // We are enabled, disable
        [_disabledMenu setState:YES];
        [self setMenusEnabled:NO];
        [self disableRunLoopSource:moveResize];
    }
    else {
        // We are disabled, enable
        [_disabledMenu setState:NO];
        [self setMenusEnabled:YES];
        [self enableRunLoopSource:moveResize];
    }
}

- (IBAction)toggleResizeOnly:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setResizeOnly:newState];
}

- (IBAction)disableLastApp:(id)sender {
    [preferences setDisabledForApp:[lastApp bundleIdentifier] withLocalizedName:[lastApp localizedName] disabled:YES];
    [_lastAppMenu setEnabled:FALSE];
    [self reconstructDisabledAppsSubmenu];
}

- (IBAction)enableDisabledApp:(id)sender {
    NSString *bundleId = [sender representedObject];
    [preferences setDisabledForApp:bundleId withLocalizedName:nil disabled:NO];
    if (lastApp != nil && [[lastApp bundleIdentifier] isEqualToString:bundleId]) {
        [_lastAppMenu setEnabled:YES];
    }
    [self reconstructDisabledAppsSubmenu];
}

- (int)modifierFlags {
    return keyModifierFlags;
}
- (void) setMostRecentApp:(NSRunningApplication*)app {
    lastApp = app;
    [_lastAppMenu setTitle:[NSString stringWithFormat:@"Disable for %@", [app localizedName]]];
    [_lastAppMenu setEnabled:YES];
}
- (NSDictionary*) getDisabledApps {
    return [preferences getDisabledApps];
}
-(BOOL)shouldBringWindowToFront {
    return [preferences shouldBringWindowToFront];
}
-(BOOL)shouldMiddleClickResize {
    return [preferences shouldMiddleClickResize];
}
-(BOOL)resizeOnly {
    return [preferences resizeOnly];
}

- (void)setMenusEnabled:(BOOL)enabled {
    [_altMenu setEnabled:enabled];
    [_cmdMenu setEnabled:enabled];
    [_ctrlMenu setEnabled:enabled];
    [_shiftMenu setEnabled:enabled];
    [_fnMenu setEnabled:enabled];
    [_bringWindowFrontMenu setEnabled:enabled];
    [_middleClickResizeMenu setEnabled:enabled];
}

- (void)reconstructDisabledAppsSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    NSDictionary *disabledApps = [self getDisabledApps];
    for (id bundleIdentifier in disabledApps) {
        NSMenuItem *item = [submenu addItemWithTitle:[disabledApps objectForKey:bundleIdentifier] action:@selector(enableDisabledApp:) keyEquivalent:@""];
        [item setRepresentedObject:bundleIdentifier];
    }
    [_disabledAppsMenu setSubmenu:submenu];
    [_disabledAppsMenu setEnabled:([disabledApps count] > 0)];
}

AXUIElementRef findWindowForElement(AXUIElementRef element) {
    if (!element) return NULL;
    
    // 检查当前元素是否为窗口
    CFTypeRef role = NULL;
    AXUIElementRef result = NULL;
    
    if (AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &role) == kAXErrorSuccess) {
        if (role) {
            NSString *roleString = (__bridge NSString *)role;
            if ([roleString isEqualToString:NSAccessibilityWindowRole]) {
                CFRetain(element);
                result = element;
            }
            CFRelease(role);
            if (result) return result;
        }
    }
    
    // 尝试获取元素的窗口属性
    CFTypeRef window = NULL;
    if (AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)NSAccessibilityWindowAttribute, &window) == kAXErrorSuccess) {
        if (window) {
            result = (AXUIElementRef)window;
            return result;
        }
    }
    
    // 如果上述方法都失败，尝试获取父元素并递归查找
    CFTypeRef parent = NULL;
    if (AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)NSAccessibilityParentAttribute, &parent) == kAXErrorSuccess) {
        if (parent) {
            result = findWindowForElement((AXUIElementRef)parent);
            CFRelease(parent);
            return result;
        }
    }
    
    return NULL;
}



// 检查窗口是否应该被过滤（透明、不可见或特殊窗口）
bool shouldFilterWindow(CFDictionaryRef window) {
    // 1. 检查窗口透明度
    CFNumberRef alphaValue = CFDictionaryGetValue(window, kCGWindowAlpha);
    float alpha = 1.0f;
    if (alphaValue) {
        CFNumberGetValue(alphaValue, kCFNumberFloatType, &alpha);
    }
    // 过滤完全透明的窗口
    if (alpha < 0.1f) {
        NSLog(@"  ✗ Filtering transparent window (alpha: %.2f)", alpha);
        return true;
    }
    
    // 2. 检查窗口是否在屏幕上
    CFBooleanRef isOnScreen = CFDictionaryGetValue(window, kCGWindowIsOnscreen);
    bool onScreen = true;
    if (isOnScreen) {
        onScreen = CFBooleanGetValue(isOnScreen);
    }
   // 过滤不在屏幕上的窗口
    if (!onScreen) {
        NSLog(@"  ✗ Filtering off-screen window");
        return true;
    }
    
    // 3. 检查窗口层级
    CFNumberRef windowLayer = CFDictionaryGetValue(window, kCGWindowLayer);
    int layer = 0;
    if (windowLayer) {
        CFNumberGetValue(windowLayer, kCFNumberSInt32Type, &layer);
    }
    // 过滤高层级窗口（工具提示、菜单等）
    if (layer > 10) {
        NSLog(@"  ✗ Filtering high-layer window (layer: %d)", layer);
        return true;
    }
    
    // // 4. 获取窗口边界
    // CFDictionaryRef bounds = CFDictionaryGetValue(window, kCGWindowBounds);
    // if (!bounds) return true; // 过滤掉没有边界的窗口
    
    // CGRect windowRect;
    // if (!CGRectMakeWithDictionaryRepresentation(bounds, &windowRect)) return true;
    
    
  
    // // === 过滤条件 ===
    
    // // 过滤异常小的窗口（可能是透明覆盖）
    // if (windowRect.size.width < 10 || windowRect.size.height < 10) {
    //     NSLog(@"  ✗ Filtering tiny window (%.0fx%.0f)", 
    //           windowRect.size.width, windowRect.size.height);
    //     return true;
    // }

//  // 5. 获取应用名称
//     CFStringRef windowOwnerName = CFDictionaryGetValue(window, kCGWindowOwnerName);
//     NSString *ownerName = windowOwnerName ? (__bridge NSString*)windowOwnerName : @"";
   
    //   // 6. 获取窗口名称
    // CFStringRef windowName = CFDictionaryGetValue(window, kCGWindowName);
    // NSString *winName = windowName ? (__bridge NSString*)windowName : @"";
    
    
    // 过滤已知的透明覆盖应用
    // NSArray *transparentApps = @[@"Bartender 4", @"HacKit", @"TouchBarServer", 
    //                             @"Dock", @"WindowServer", @"Spotlight", @"PopClip",
    //                             @"Overflow 3", @"BetterTouchTool", @"Karabiner-Elements",
    //                             @"Control Room", @"CleanMyMac", @"Finder"];
    // if ([transparentApps containsObject:ownerName]) {
    //     NSLog(@"  ✗ Filtering known transparent app: %@", ownerName);
    //     return true;
    // }
    
    // // 过滤特定的窗口名称模式
    // NSArray *transparentWindowPatterns = @[@"Transparent", @"Overlay", @"HUD", 
    //                                       @"TouchBar", @"Invisible", @"Desktop",
    //                                       @"Wallpaper"];
    // for (NSString *pattern in transparentWindowPatterns) {
    //     if ([winName containsString:pattern] || [ownerName containsString:pattern]) {
    //         NSLog(@"  ✗ Filtering window with transparent pattern: %@ (%@)", winName, ownerName);
    //         return true;
    //     }
    // }
    
    // NSLog(@"  ✓ Window passed filter: %@ - %@ (layer: %d, alpha: %.2f)", ownerName, winName, layer, alpha);
    return false; // 不过滤此窗口
}

AXUIElementRef getWindowAtPosition(CGPoint position) {
    // 这个API直接从窗口服务器获取信息，绕过了应用层的辅助功能实现。
    CFArrayRef windowList = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    );
    
    if (!windowList) {
        return NULL;
    }
    // NSLog(@"windowList: %@", windowList);
    CFIndex count = CFArrayGetCount(windowList);
    AXUIElementRef result = NULL;
    
    NSLog(@"Found %ld windows, checking z-order from front to back", count);
    
    for (CFIndex i = 0; i < count; i++) {
        CFDictionaryRef window = CFArrayGetValueAtIndex(windowList, i);
        
        // 首先过滤不需要的窗口
        if (shouldFilterWindow(window)) {
            continue; // 跳过被过滤的窗口
        }
        
        // 获取窗口边界
        CFDictionaryRef bounds = CFDictionaryGetValue(window, kCGWindowBounds);
        if (!bounds) continue;
        
        CGRect windowRect;
        if (!CGRectMakeWithDictionaryRepresentation(bounds, &windowRect)) continue;
        
        // 检查点击位置是否在窗口内, 这里就是找到特定窗口的
        if (CGRectContainsPoint(windowRect, position)) {
            NSLog(@"✓ Position (%.2f, %.2f) is inside viable window %ld", 
                  position.x, position.y, i);
            // 获取窗口的PID
            CFNumberRef pidNumber = CFDictionaryGetValue(window, kCGWindowOwnerPID);
            if (!pidNumber) continue;
            
            pid_t pid;
            CFNumberGetValue(pidNumber, kCFNumberSInt32Type, &pid);
            
            // 获取窗口号
            CFNumberRef windowNumber = CFDictionaryGetValue(window, kCGWindowNumber);
            if (!windowNumber) continue;
            
            CGWindowID windowID;
            CFNumberGetValue(windowNumber, kCFNumberSInt32Type, &windowID);

            CFStringRef windowOwnerName = CFDictionaryGetValue(window, kCGWindowOwnerName);
            NSString *ownerName = windowOwnerName ? (__bridge NSString*)windowOwnerName : @"Unknown";
            NSLog(@"  → Trying to find AX element for PID: %d (%@)", pid, ownerName);
            // 尝试通过PID创建AXUIElement并查找对应的窗口
            AXUIElementRef app = AXUIElementCreateApplication(pid);
            if (app) {
                CFArrayRef windows = NULL;
                if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, (CFTypeRef*)&windows) == kAXErrorSuccess) {
                    if (windows) {
                        CFIndex windowCount = CFArrayGetCount(windows);
                        NSLog(@"windowCount: %d", windowCount);
                        // for (CFIndex j = 0; j < windowCount; j++) {
                        //     AXUIElementRef axWindow = CFArrayGetValueAtIndex(windows, j);
                            
                            
                        //     CFTypeRef titleValue = NULL;
                        //     AXError result = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute, &titleValue);
                        //     if (result == kAXErrorSuccess && titleValue) {
                        //         NSString *title = (__bridge NSString *)titleValue;
                        //         NSString *retainedTitle = [title copy]; // 创建副本
                        //         CFRelease(titleValue);
                        //         NSLog(@"title: %@", retainedTitle);
                        //     }
                        // }

                        for (CFIndex j = 0; j < windowCount; j++) {
                            AXUIElementRef axWindow = CFArrayGetValueAtIndex(windows, j);
                            
                            
                            // 获取窗口位置和大小来匹配
                            CFTypeRef positionValue = NULL;
                            CFTypeRef sizeValue = NULL;
                            
                            if (AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute, &positionValue) == kAXErrorSuccess &&
                                AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute, &sizeValue) == kAXErrorSuccess) {
                                
                                CGPoint axPosition;
                                CGSize axSize;
                                
                                if (AXValueGetValue(positionValue, kAXValueCGPointType, &axPosition) &&
                                    AXValueGetValue(sizeValue, kAXValueCGSizeType, &axSize)) {
                                    
                                    CGRect axRect = CGRectMake(axPosition.x, axPosition.y, axSize.width, axSize.height);
                                    
                                    // 检查是否匹配（允许一定误差）
                                    if (fabs(axRect.origin.x - windowRect.origin.x) < 5 &&
                                        fabs(axRect.origin.y - windowRect.origin.y) < 5 &&
                                        fabs(axRect.size.width - windowRect.size.width) < 5 &&
                                        fabs(axRect.size.height - windowRect.size.height) < 5) {
                                        
                                        NSLog(@"    ✓ Found matching AX window!");
                                        
                                        // 获取窗口标题确认
                                        CFTypeRef titleValue = NULL;
                                        if (AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute, &titleValue) == kAXErrorSuccess && titleValue) {
                                            NSLog(@"    Window title: %@", (__bridge NSString*)titleValue);
                                            CFRelease(titleValue);
                                        }
                                        
                                        CFRetain(axWindow);
                                        result = axWindow;
                                    }
                                }
                                
                                if (positionValue) CFRelease(positionValue);
                                if (sizeValue) CFRelease(sizeValue);
                                
                                if (result) break;
                            }
                        }
                        CFRelease(windows);
                    }
                }
                CFRelease(app);
                
                // 如果找到了匹配的窗口，就返回（这是最前面的可见窗口）
                if (result) {
                    NSLog(@"✓ Successfully found topmost viable window at position");
                    break;
                }
            }
        }
    }
    
    CFRelease(windowList);
    return result;
}

@end
