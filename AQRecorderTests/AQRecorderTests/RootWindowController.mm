//
//  RootWindowController.m
//  AQRecorderTests
//
//  Created by Christos Sotiriou on 11/24/12.
//  Copyright (c) 2012 Oramind. All rights reserved.
//

#import "RootWindowController.h"
#import "SFAQRecorder.h"
#import "SFDebugLog.h"

@interface RootWindowController () <SFRecorderWrapperDelegate>
@property (nonatomic, strong) SFRecorderWrapper *recorder;
@end

@implementation RootWindowController


- (id)init
{
    self = [super init];
    if (self) {
		self.recorder = [[SFRecorderWrapper alloc] initWithDelegate:self andOutputPath:[@"~/Desktop/output.wav" stringByStandardizingPath]];
    }
    return self;
}

- (IBAction)startRecord:(id)sender {
	if (self.recorder.recording) {
		[self.recorder stopRecord];
	}else{
		[self.recorder startRecord];
		[self.recordButton setTitle:@"stop"];		
	}
}

- (void)sfRecorder:(SFRecorderWrapper *)identificator didRecordInputBufferWithAudioQueue:(AudioQueueRef)inAQ andAudioBuffer:(AudioQueueBufferRef)inBuffer startTimeStamp:(const AudioTimeStamp *)inStartTime packetNumbers:(UInt32)inNumPackets andPacketDecriptor:(const AudioStreamPacketDescription *)inPacketDesc lowLevelRecorder:(SFRecorder *)recorder
{
	NSLog(@"this is a log");
}
@end
