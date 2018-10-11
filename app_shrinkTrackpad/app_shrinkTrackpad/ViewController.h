//
//  ViewController.h
//  app_shrinkTrackpad
//
//  Created by aa on 10/6/18.
//  Copyright © 2018 aa. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController
@property (weak) IBOutlet NSTextField *label_centernote;
@property (weak) IBOutlet NSTextField *label_leftUpper;
@property (weak) IBOutlet NSTextField *label_leftLower;
@property (weak) IBOutlet NSTextField *label_rightUpper;
@property (weak) IBOutlet NSTextField *label_rightLower;
@property (weak) IBOutlet NSButton *button_steps;

@property (weak) IBOutlet NSButton *button_reset;
@property (weak) IBOutlet NSTextField *label_ISP_indic;
@property (weak) IBOutlet NSTextField *label_root_indic;
@property (weak) IBOutlet NSTextField *label_author;
@property (weak) IBOutlet NSTextField *label_donat;


@property (weak) IBOutlet NSButton *direct_left;
@property (weak) IBOutlet NSButton *direct_right;
@property (weak) IBOutlet NSButton *direct_up;
@property (weak) IBOutlet NSButton *direct_down;

@end

