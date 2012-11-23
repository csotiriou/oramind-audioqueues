//
//  RootWindowController.h
//  AQRecorderTests
//
//  Created by Christos Sotiriou on 11/24/12.
//  Copyright (c) 2012 Oramind. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RootWindowController : NSViewController
@property (weak) IBOutlet NSButton *recordButton;
- (IBAction)startRecord:(id)sender;

@end
