//
//  SFAQRecorder.h
//  SongIDTest2
//
//  Created by Christos Sotiriou on 10/23/12.
//  Copyright (c) 2012 Christos Sotiriou. All rights reserved.
//

#ifndef SongIDTest2_SFAQRecorder_h
#define SongIDTest2_SFAQRecorder_h

#include <AudioToolbox/AudioToolbox.h>
#include <Foundation/Foundation.h>
#include <libkern/OSAtomic.h>
#import "CAStreamBasicDescription.h"
#import "CAXException.h"

#define kNumberRecordBuffers	3

class SFRecorder;

@protocol SFRecordDelegate <NSObject>
- (void)sfRecorder:(SFRecorder *)identificator hasInputBufferWithAudioQueue:(AudioQueueRef)inAQ andAudioBuffer:(AudioQueueBufferRef)inBuffer startTimeStamp: (const AudioTimeStamp *)inStartTime packetNumbers:(UInt32)inNumPackets andPacketDecriptor:(const AudioStreamPacketDescription *)inPacketDesc;
@optional
- (void)sfRecorderDidStartRecording:(SFRecorder *)identificator;
- (void)sfRecorderDidStopRecording:(SFRecorder *)recorder withFileURL:(NSURL *)outputFileURL;
@end

class SFRecorder {
	CFStringRef					mFileName;
	AudioQueueRef				mQueue;
	AudioQueueBufferRef			mBuffers[kNumberRecordBuffers];
	AudioFileID					mRecordFile;
	SInt64						mRecordPacket; // current packet number in record file
	CAStreamBasicDescription mRecordFormat;
	Boolean						mIsRunning;
	CFURLRef					outputFileURLRef;
	
	//	void			CopyEncoderCookieToFile();
	void			SetupAudioFormat(UInt32 inFormatID);
	UInt32				ComputeRecordBufferSize(const AudioStreamBasicDescription *format, float seconds);
	
	static void MyInputBufferHandler(void *								inUserData,
									 AudioQueueRef						inAQ,
									 AudioQueueBufferRef					inBuffer,
									 const AudioTimeStamp *				inStartTime,
									 UInt32								inNumPackets,
									 const AudioStreamPacketDescription*	inPacketDesc);
	void CopyEncoderCookieToFile();

	void init();
	id<SFRecordDelegate> delegate = nil;

public:
	SFRecorder();
	SFRecorder (id<SFRecordDelegate> del);
	SFRecorder (id<SFRecordDelegate> del, NSString * outputPath);
	~SFRecorder();
	
	
	void startRecord();
	void stopRecord();
	id<SFRecordDelegate> getDelegate();
	
	AudioQueueRef				getAudioQeue()				{ return mQueue;}
	CAStreamBasicDescription	DataFormat()				{ return mRecordFormat; }
	UInt32						GetNumberChannels() const	{ return mRecordFormat.NumberChannels(); }
	CFStringRef					GetFileName() const			{ return mFileName; }
	AudioQueueRef				Queue() const				{ return mQueue; }
	Boolean						IsRunning() const			{ return mIsRunning; }
	UInt64						startTime;

};
#endif




/* Objective C wrapper */
@class SFRecorderWrapper;

@protocol SFRecorderWrapperDelegate <NSObject>
- (void)sfRecorder:(SFRecorderWrapper *)identificator didRecordInputBufferWithAudioQueue:(AudioQueueRef)inAQ andAudioBuffer:(AudioQueueBufferRef)inBuffer startTimeStamp: (const AudioTimeStamp *)inStartTime packetNumbers:(UInt32)inNumPackets andPacketDecriptor:(const AudioStreamPacketDescription *)inPacketDesc lowLevelRecorder:(SFRecorder *)recorder;
@optional
- (void)sfRecorderWrapperDidStartRecording:(SFRecorderWrapper *)wrapper;
- (void)sfRecorderWrapperDidStopRecording:(SFRecorderWrapper *)wrapper withFileURL:(NSURL *)outputFileURL;
@end

@interface SFRecorderWrapper : NSObject
@property (nonatomic, strong) NSString *outputFileName;
@property (nonatomic, assign) id<SFRecorderWrapperDelegate> delegate;
@property (nonatomic) SFRecorder *recorder;
@property (nonatomic, readonly) BOOL recording;

- (SFRecorderWrapper *)initWithDelegate:(id<SFRecorderWrapperDelegate>)delegate andOutputPath:(NSString *)outputPath;
- (void)startRecord;
- (void)stopRecord;

@end