/*
 * dpf-webui
 * Copyright (C) 2021 Luciano Iam <oss@lucianoiam.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any purpose with
 * or without fee is hereby granted, provided that the above copyright notice and this
 * permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS. IN
 * NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL
 * DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#include "CocoaWebWidget.hpp"

// Avoid symbol name collisions
#define OBJC_INTERFACE_NAME_HELPER_1(INAME, SEP, SUFFIX) INAME ## SEP ## SUFFIX
#define OBJC_INTERFACE_NAME_HELPER_2(INAME, SUFFIX) OBJC_INTERFACE_NAME_HELPER_1(INAME, _, SUFFIX)
#define OBJC_INTERFACE_NAME(INAME) OBJC_INTERFACE_NAME_HELPER_2(INAME, PROJECT_ID_HASH)

#define DistrhoWebView         OBJC_INTERFACE_NAME(DistrhoWebView)
#define DistrhoWebViewDelegate OBJC_INTERFACE_NAME(DistrhoWebViewDelegate)

#define fWebView         ((DistrhoWebView*)fView)
#define fWebViewDelegate ((DistrhoWebViewDelegate*)fDelegate)

#define JS_POST_MESSAGE_SHIM "window.webviewHost.postMessage = (args) => window.webkit.messageHandlers.host.postMessage(args);"

// Do not assume an autorelease pool exists or ARC is enabled.

USE_NAMESPACE_DISTRHO

@interface DistrhoWebView: WKWebView
@property (readonly, nonatomic) CocoaWebWidget* cppWidget;
@property (readonly, nonatomic) NSView* pluginRootView;
@end

@interface DistrhoWebViewDelegate: NSObject<WKNavigationDelegate, WKScriptMessageHandler>
@property (assign, nonatomic) CocoaWebWidget *cppWidget;
@end

CocoaWebWidget::CocoaWebWidget(Window& windowToMapTo)
    : AbstractWebWidget(windowToMapTo)
{
    // Create the web view
    fView = [[DistrhoWebView alloc] initWithFrame:CGRectZero];
    fWebView.hidden = YES;

    // Create a ObjC object that responds to some web view callbacks
    fDelegate = [[DistrhoWebViewDelegate alloc] init];
    fWebViewDelegate.cppWidget = this;
    fWebView.navigationDelegate = fWebViewDelegate;
    [fWebView.configuration.userContentController addScriptMessageHandler:fWebViewDelegate name:@"host"];

    // windowId is either a PuglCairoView* or PuglOpenGLViewDGL* depending
    // on the value of UI_TYPE in the Makefile. Both are NSView subclasses.
    NSView *parentView = (NSView *)windowToMapTo.getNativeWindowHandle();
    [parentView addSubview:fWebView];

    String js = String(JS_POST_MESSAGE_SHIM);
    injectDefaultScripts(js);
}

CocoaWebWidget::~CocoaWebWidget()
{
    [fWebView removeFromSuperview];
    [fWebView release];
    [fWebViewDelegate release];
}

void CocoaWebWidget::onResize(const ResizeEvent& ev)
{
    // There is a mismatch between DGL and AppKit coordinates
    // https://github.com/DISTRHO/DPF/issues/291
    CGFloat k = [NSScreen mainScreen].backingScaleFactor;
    CGRect frame;
    frame.origin.x = 0;
    frame.origin.y = 0;
    frame.size.width = (CGFloat)ev.size.getWidth() / k;
    frame.size.height = (CGFloat)ev.size.getHeight() / k;
    fWebView.frame = frame;
}

bool CocoaWebWidget::onKeyboard(const KeyboardEvent& ev)
{
    // Some hosts like REAPER prevent the web view from getting keyboard focus.
    // The parent widget should call this method to allow routing keyboard
    // events to the web view and make input work in such cases.

    if ((fLastKeyboardEvent.mod != ev.mod) || (fLastKeyboardEvent.flags != ev.flags)
        || (fLastKeyboardEvent.time != ev.time) || (fLastKeyboardEvent.press != ev.press)
        || (fLastKeyboardEvent.key != ev.key) || (fLastKeyboardEvent.keycode != ev.keycode)) {

        fLastKeyboardEvent = ev;

        // FIXME
        NSLog(@"onKeyboard()");

        if (ev.press) {
            NSEvent *event = [NSEvent keyEventWithType: NSEventTypeKeyDown
                location: NSZeroPoint
                modifierFlags: 0  // FIXME ie, NSEventModifierFlagShift
                timestamp: ev.time
                windowNumber: 0
                context: nil
                characters:  @"a" // FIXME
                charactersIgnoringModifiers: @"a" // FIXME
                isARepeat: NO
                keyCode: ev.keycode
            ];

            [fWebView keyDown:event];
        } else {
            NSEvent *event = [NSEvent keyEventWithType: NSEventTypeKeyUp
                location: NSZeroPoint
                modifierFlags: 0  // FIXME ie, NSEventModifierFlagShift
                timestamp: ev.time
                windowNumber: 0
                context: nil
                characters:  @"a" // FIXME
                charactersIgnoringModifiers: @"a" // FIXME
                isARepeat: NO
                keyCode: ev.keycode
            ];

            [fWebView keyUp:event];
        }
    } else {
        // Break loop. Unfortunately this breaks key repetition as well, the
        // solution is to have non-zero timestamps in KeyboardEvent ev.
    }

    return isGrabKeyboardInput(); // true = stop propagation
}

void CocoaWebWidget::setBackgroundColor(uint32_t rgba)
{
    // macOS WKWebView apparently does not offer a method for setting a background color, so the
    // background is removed altogether to reveal the underneath window paint. Do it safely.
    (void)rgba;

    if ([fWebView respondsToSelector:@selector(_setDrawsBackground:)]) {
        @try {
            NSNumber *no = [[NSNumber alloc] initWithBool:NO];
            [fWebView setValue:no forKey:@"drawsBackground"];
            [no release];
        }
        @catch (NSException *e) {
            NSLog(@"Could not set transparent color for WKWebView");
        }
    }
}

void CocoaWebWidget::navigate(String& url)
{
    NSString *urlStr = [[NSString alloc] initWithCString:url encoding:NSUTF8StringEncoding];
    NSURL *urlObj = [[NSURL alloc] initWithString:urlStr];
    [fWebView loadFileURL:urlObj allowingReadAccessToURL:urlObj];
    [urlObj release];
    [urlStr release];
}

void CocoaWebWidget::runScript(String& source)
{
    NSString *js = [[NSString alloc] initWithCString:source encoding:NSUTF8StringEncoding];
    [fWebView evaluateJavaScript:js completionHandler: nil];
    [js release];
}

void CocoaWebWidget::injectScript(String& source)
{
    NSString *js = [[NSString alloc] initWithCString:source encoding:NSUTF8StringEncoding];
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [fWebView.configuration.userContentController addUserScript:script];
    [script release];
    [js release];
}

@implementation DistrhoWebView

- (CocoaWebWidget *)cppWidget
{
    return ((DistrhoWebViewDelegate *)self.navigationDelegate).cppWidget;
}

- (NSView *)pluginRootView
{
    return self.superview.superview;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    // Allow the web view to immediately process clicks when the plugin window
    // is unfocused, otherwise the first click is swallowed to focus web view.
    return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    // Ignore key shortcuts like Cmd+Q and Cmd+H
    return NO;
}

// Optionally route keyboard events from the web view to plugin root window so
// they are ultimately handled by the host. This for example allows playing the
// virtual keyboard on Live while the web view UI is open.

- (void)keyDown:(NSEvent *)event
{
    [super keyDown:event];
    if (!self.cppWidget->isGrabKeyboardInput()) {
        [self.pluginRootView keyDown:event];
    }
}

- (void)keyUp:(NSEvent *)event
{
    [super keyUp:event];
    if (!self.cppWidget->isGrabKeyboardInput()) {
        [self.pluginRootView keyUp:event];
    }
}

- (void)flagsChanged:(NSEvent *)event
{
    [super flagsChanged:event];
    if (!self.cppWidget->isGrabKeyboardInput()) {
        [self.pluginRootView flagsChanged:event];
    }
}

@end

@implementation DistrhoWebViewDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    self.cppWidget->didFinishNavigation();
    webView.hidden = NO;
}

- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message
{
    if (![message.body isKindOfClass:[NSArray class]]) {
        return;
    }

    ScriptValueVector args;

    for (id objcArg : (NSArray *)message.body) {
        if (CFGetTypeID(objcArg) == CFBooleanGetTypeID()) {
            args.push_back(ScriptValue(static_cast<bool>([objcArg boolValue])));
        } else if ([objcArg isKindOfClass:[NSNumber class]]) {
            args.push_back(ScriptValue([objcArg doubleValue]));
        } else if ([objcArg isKindOfClass:[NSString class]]) {
            args.push_back(ScriptValue(String([objcArg cStringUsingEncoding:NSUTF8StringEncoding])));
        } else {
            args.push_back(ScriptValue()); // null
        }
    }

    self.cppWidget->didReceiveScriptMessage(args);
}

@end
