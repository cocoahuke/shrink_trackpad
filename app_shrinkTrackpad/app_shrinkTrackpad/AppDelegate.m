//
//  AppDelegate.m
//  app_shrinkTrackpad
//
//  Created by aa on 10/6/18.
//  Copyright © 2018 aa. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    NSWindow *mainWindow = [[NSApplication sharedApplication] mainWindow];
    mainWindow.styleMask &= ~NSWindowStyleMaskResizable;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender{
    return YES;
}


@end
