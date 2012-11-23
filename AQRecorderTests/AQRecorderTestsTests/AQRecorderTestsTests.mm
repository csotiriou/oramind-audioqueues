//
//  AQRecorderTestsTests.m
//  AQRecorderTestsTests
//
//  Created by Christos Sotiriou on 11/18/12.
//  Copyright (c) 2012 Oramind. All rights reserved.
//

#import "AQRecorderTestsTests.h"
#import "SFAQRecorder.h"

@interface AQRecorderTestsTests () <SFRecorderWrapperDelegate>
@property (nonatomic, strong) SFRecorderWrapper *recorder;
@end

@implementation AQRecorderTestsTests

- (void)setUp
{
    [super setUp];
    _recorder = [[SFRecorderWrapper alloc] initWithDelegate:self andOutputPath:[@"~/Desktop/myWav.wav" stringByStandardizingPath]];

	
    // Set-up code here.
}

- (void)sfRecorder:(SFRecorderWrapper *)identificator didRecordInputBufferWithAudioQueue:(AudioQueueRef)inAQ andAudioBuffer:(AudioQueueBufferRef)inBuffer startTimeStamp:(const AudioTimeStamp *)inStartTime packetNumbers:(UInt32)inNumPackets andPacketDecriptor:(const AudioStreamPacketDescription *)inPacketDesc lowLevelRecorder:(SFRecorder *)recorder
{
	
}


- (void)tearDown
{
	// Tear-down code here.
    NSLog(@"this is a test case");
    [super tearDown];
}

- (void)testExample
{
//    STFail(@"Unit tests are not implemented yet in AQRecorderTestsTests");
	NSLog(@"this is a new unit test!");
	
	[_recorder startRecord];
	[_recorder performSelector:@selector(stopRecord) withObject:nil afterDelay:5];
}

- (void)dealloc
{
	SFDebugLog(@"deallocating");
}

@end
