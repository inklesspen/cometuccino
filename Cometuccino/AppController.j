/*
 * AppController.j
 *
 * Created by __Me__ on __Date__.
 * Copyright 2008 __MyCompanyName__. All rights reserved.
 */

@import <Foundation/CPObject.j>
@import "HTTPServer.j"


@implementation AppController : CPObject
{
	HttpServer _server;
	CPString _label;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{
	_label = "foo";
	_server = [[HttpServer alloc] initWithLabel: _label delegate: self];
	
    var theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView];

    var label = [[CPTextField alloc] initWithFrame:CGRectMakeZero()];
	
	var address = window.location.protocol + "//" + _label + "." + window.location.host;

    [label setStringValue:@"Try visiting " + address];
    [label setFont:[CPFont boldSystemFontOfSize:24.0]];

    [label sizeToFit];

    [label setAutoresizingMask:CPViewMinXMargin | CPViewMaxXMargin | CPViewMinYMargin | CPViewMaxYMargin];
    [label setFrameOrigin:CGPointMake((CGRectGetWidth([contentView bounds]) - CGRectGetWidth([label frame])) / 2.0, (CGRectGetHeight([contentView bounds]) - CGRectGetHeight([label frame])) / 2.0)];

    [contentView addSubview:label];

    [theWindow orderFront:self];

    // Uncomment the following line to turn on the standard menu bar.
    //[CPMenu setMenuBarVisible:YES];
}

- (void)HTTPrequest:(HttpRequest) httpreq
{
	[httpreq respondWithStatus: 200 text: "OK" headers: {"Content-Type":"text/plain"} body: "Hello World, served from within your Cappuccino app"];
}

@end
