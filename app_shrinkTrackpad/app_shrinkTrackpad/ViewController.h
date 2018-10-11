/*
 * This file is part of the https://github.com/cocoahuke/shrink_trackpad distribution
 * Copyright (c) 2018 cocoahuke.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
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

