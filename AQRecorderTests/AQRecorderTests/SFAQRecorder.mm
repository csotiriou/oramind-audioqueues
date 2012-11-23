//
//  SFAQRecorder.cpp
//  SongIDTest2
//
//  Created by Christos Sotiriou on 10/23/12.
//  Copyright (c) 2012 Christos Sotiriou. All rights reserved.
//

#include "SFAQRecorder.h"
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>

#define kBufferDurationSeconds .1

#define kSendEndOfStreamIntervalSeconds 7 // < 1 for never
#define kHTTPResponseCompletionTimeoutSeconds -1 // < 1 for never
#define kMultipleResponses 0

#define kHostProtocol @"http://"
#define kHostAddr @"search.midomi.com"
#define kHostURI @"/v2/?method=search&type=identify"
#define kHostPort 443
#define kHTTPHeaderUserAgent @"AppNumber=48000 APIVersion=2.1.0.0 DEV=Qrator UID=dkl109sas19s"
#define kHTTPHeaderMIMEType @"audio/x-speex"

#define FRAME_SIZE 110
#define TAG_HTTP_REQUEST_HEADER 1
#define TAG_HTTP_REQUEST_AUDIO_FRAME 3
#define TAG_HTTP_RESPONSE_HEADER 10
#define TAG_HTTP_RESPONSE_CONTENT 11
#define TAG_HTTP_REQUEST_FINAL_CHUNK 12




int numberOfPackets = 0;


/* C++ wrapper methods*/

SFRecorder::SFRecorder (id<SFRecordDelegate> del){
	init();
	delegate = del;
}

SFRecorder::SFRecorder (id<SFRecordDelegate> del, NSString * outputPath){
	init();
	outputFileURLRef = CFURLCreateWithString(kCFAllocatorDefault, (CFStringRef)outputPath, NULL);
	delegate = del;
}

void SFRecorder::init()
{
	delegate = nil;
	mIsRunning = false;
	mRecordPacket = 0;
	outputFileURLRef = NULL;
}

SFRecorder::SFRecorder()
{
	AudioQueueDispose(mQueue, TRUE);
	AudioFileClose(mRecordFile);
	if (mFileName) CFRelease(mFileName);
}


SFRecorder::~SFRecorder()
{
	AudioQueueDispose(mQueue, TRUE);
	AudioFileClose(mRecordFile);
	if (mFileName) CFRelease(mFileName);
	if (outputFileURLRef != NULL) CFRelease(outputFileURLRef);
}

void SFRecorder::startRecord()
{
	int i, bufferByteSize;
	UInt32 size;
	
	try {
		numberOfPackets = 0;
		
		// specify the recording format
		SetupAudioFormat(kAudioFormatLinearPCM);
		
		AudioQueueNewInput(  &mRecordFormat,
						   MyInputBufferHandler,
						   this /* userData */,
						   NULL /* run loop */, NULL /* run loop mode */,
						   0 /* flags */, &mQueue);
		mRecordPacket = 0;
		
		size = sizeof(mRecordFormat);
		AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &mRecordFormat, &size);
		
		bufferByteSize = ComputeRecordBufferSize(&mRecordFormat, kBufferDurationSeconds);	// enough bytes for half a second
		
		if (outputFileURLRef != NULL) {
			OSStatus status = AudioFileCreateWithURL(outputFileURLRef, kAudioFileCAFType, &mRecordFormat, kAudioFileFlags_EraseFile, &mRecordFile);
			XThrowIfError(status, "AudioFileCreateWithURL failed");
		}
	
		AudioFileCreateWithURL(outputFileURLRef, kAudioFileCAFType, &mRecordFormat, kAudioFileFlags_EraseFile, &mRecordFile);


		CopyEncoderCookieToFile();
		
		size = sizeof(mRecordFormat);
		XThrowIfError(AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription, &mRecordFormat, &size), "couldn't get queue's format");
		
		for (i = 0; i < kNumberRecordBuffers; ++i) {
			XThrowIfError(AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]), "AudioQueueAllocateBuffer failed");
			XThrowIfError(AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL), "AudioQueueEnqueueBuffer failed");
		}
		mIsRunning = true;
		
		XThrowIfError(AudioQueueStart(mQueue, NULL), "AudioQueueStart failed");
		
		
	} catch (CAXException e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}catch (...) {
		fprintf(stderr, "An unknown error occurred\n");;
	}
	
}

void SFRecorder::stopRecord()
{
	if (mIsRunning == true) {
		mIsRunning = false;
		XThrowIfError(AudioQueueStop(mQueue, true), "AudioQueueStop failed");
		// a codec may update its cookie at the end of an encoding session, so reapply it to the file now
		CopyEncoderCookieToFile();
		//if (mFileName)
		//		{
		//		CFRelease(mFileName);
		//		mFileName = NULL;
		//}
		AudioQueueDispose(mQueue, true);
		AudioFileClose(mRecordFile);
		if ([this->getDelegate() respondsToSelector:@selector(sfRecorderDidStopRecording:withFileURL:)]) {
			[this->getDelegate() sfRecorderDidStopRecording:this withFileURL:(this->outputFileURLRef != NULL? (__bridge NSURL *)this->outputFileURLRef : NULL)];
		}
	}
	
	SFDebugLog(@"stopped recording");
}



void SFRecorder::SetupAudioFormat(UInt32 inFormatID)
{
	
	
#if TARGET_API_MAC_OSX
	mRecordFormat.mSampleRate = 44100;
	mRecordFormat.mChannelsPerFrame = 2;
#else
	memset(&mRecordFormat, 0, sizeof(mRecordFormat));
	UInt32 size = sizeof(mRecordFormat.mSampleRate);
	XThrowIfError(AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareSampleRate, &size, &mRecordFormat.mSampleRate), "couldn't get hardware sample rate");

	size = sizeof(mRecordFormat.mChannelsPerFrame);
	XThrowIfError(AudioSessionGetProperty(	kAudioSessionProperty_CurrentHardwareInputNumberChannels,
										  &size,
										  &mRecordFormat.mChannelsPerFrame), "couldn't get input channel count");
#endif
	
	mRecordFormat.mFormatID = inFormatID;
	if (inFormatID == kAudioFormatLinearPCM){
		// if we want pcm, default to signed 16-bit little-endian
		
		mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		//		mRecordFormat.mBitsPerChannel = 16;
		
		
		mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame = (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
		mRecordFormat.mFramesPerPacket = 1;
		
		mRecordFormat.mFormatID         = kAudioFormatLinearPCM;
        mRecordFormat.mSampleRate       = 32000.0;
        mRecordFormat.mChannelsPerFrame = 1;
        mRecordFormat.mBitsPerChannel   = 16;
        mRecordFormat.mBytesPerPacket   =  mRecordFormat.mBytesPerFrame = mRecordFormat.mChannelsPerFrame * sizeof (SInt16);
        mRecordFormat.mFramesPerPacket  = 1;
	}
}


UInt32 SFRecorder::ComputeRecordBufferSize(const AudioStreamBasicDescription *format, float seconds){
	static const int maxBufferSize = 0x50000;
    
    int maxPacketSize = format->mBytesPerPacket;
    if (maxPacketSize == 0) {
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize);
    }
    
    Float64 numBytesForTime = DataFormat().mSampleRate * maxPacketSize * seconds;
	return (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);
}

id<SFRecordDelegate> SFRecorder::getDelegate(){
	return delegate;
}

void SFRecorder::MyInputBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer, const AudioTimeStamp *inStartTime, UInt32 inNumPackets, const AudioStreamPacketDescription *inPacketDesc)
{
	SFRecorder *aqr = (SFRecorder *)inUserData;
	try {
		if (inNumPackets > 0) {
			// write packets to file
			XThrowIfError(AudioFileWritePackets(aqr->mRecordFile, FALSE, inBuffer->mAudioDataByteSize, inPacketDesc, aqr->mRecordPacket, &inNumPackets, inBuffer->mAudioData), "AudioFileWritePackets failed");
			aqr->mRecordPacket += inNumPackets;
		}
		
		if ([aqr->getDelegate() respondsToSelector:@selector(sfRecorder:hasInputBufferWithAudioQueue:andAudioBuffer:startTimeStamp:packetNumbers:andPacketDecriptor:)]) {
			[aqr->delegate sfRecorder:aqr hasInputBufferWithAudioQueue:inAQ andAudioBuffer:inBuffer startTimeStamp:inStartTime packetNumbers:inNumPackets andPacketDecriptor:inPacketDesc];
		}
		
		numberOfPackets ++;
		SFDebugLog(@"packet number: %i", numberOfPackets);
		
		AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
	} catch (CAXException e) {
		char buf[256];
		fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
	}
}


// ____________________________________________________________________________________
// Copy a queue's encoder's magic cookie to an audio file.
void SFRecorder::CopyEncoderCookieToFile()
{
	UInt32 propertySize;
	// get the magic cookie, if any, from the converter
	OSStatus err = AudioQueueGetPropertySize(mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
	
	// we can get a noErr result and also a propertySize == 0
	// -- if the file format does support magic cookies, but this file doesn't have one.
	if (err == noErr && propertySize > 0) {
		Byte *magicCookie = new Byte[propertySize];
		UInt32 magicCookieSize;
		XThrowIfError(AudioQueueGetProperty(mQueue, kAudioQueueProperty_MagicCookie, magicCookie, &propertySize), "get audio converter's magic cookie");
		magicCookieSize = propertySize;	// the converter lies and tell us the wrong size
		
		// now set the magic cookie on the output file
		UInt32 willEatTheCookie = false;
		// the converter wants to give us one; will the file take it?
		err = AudioFileGetPropertyInfo(mRecordFile, kAudioFilePropertyMagicCookieData, NULL, &willEatTheCookie);
		if (err == noErr && willEatTheCookie) {
			err = AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, magicCookieSize, magicCookie);
			XThrowIfError(err, "set audio file's magic cookie");
		}
		delete[] magicCookie;
	}
}

/* 
 -----------------------------------------------------------------------------------------
 *********************************************************************************
 *********************************************************************************
 *********************************************************************************
 -----------------------------------------------------------------------------------------
 */




@interface SFRecorderWrapper () <SFRecordDelegate>
@property (nonatomic) CFURLRef outputURL;
@end

@implementation SFRecorderWrapper

- (SFRecorderWrapper *)initWithDelegate:(id<SFRecorderWrapperDelegate>)delegate andOutputPath:(NSString *)outputPath
{
    self = [super init];
    if (self) {
        self.delegate = delegate;
		self.recorder = new SFRecorder(self, outputPath);
		self.outputFileName = outputPath;
		self.outputURL = NULL;
    }
    return self;
}

- (void)setOutputFileName:(NSString *)outputFileName
{
	_outputFileName = outputFileName;
	if (self.outputURL != NULL) {
		CFRelease(_outputURL);
	}
	self.outputURL = (CFURLRef)CFBridgingRetain([NSURL URLWithString:_outputFileName]);
	CFRelease(_outputURL);
}




- (void)startRecord
{
	
	self.recorder->startRecord();
}


- (void)stopRecord
{
	self.recorder->stopRecord();
}

- (void)sfRecorder:(SFRecorder *)identificator hasInputBufferWithAudioQueue:(AudioQueueRef)inAQ andAudioBuffer:(AudioQueueBufferRef)inBuffer startTimeStamp:(const AudioTimeStamp *)inStartTime packetNumbers:(UInt32)inNumPackets andPacketDecriptor:(const AudioStreamPacketDescription *)inPacketDesc
{
	SFDebugLog(@"buffer ready!");
	if ([self.delegate respondsToSelector:@selector(sfRecorder:didRecordInputBufferWithAudioQueue:andAudioBuffer:startTimeStamp:packetNumbers:andPacketDecriptor:lowLevelRecorder:)]) {
		[self.delegate sfRecorder:self didRecordInputBufferWithAudioQueue:inAQ andAudioBuffer:inBuffer startTimeStamp:inStartTime packetNumbers:inNumPackets andPacketDecriptor:inPacketDesc lowLevelRecorder:self.recorder];
	}
	
	
}

- (BOOL)recording
{
	return self.recorder->IsRunning();
}

- (void)sfRecorderDidStopRecording:(SFRecorder *)recorder withFileURL:(NSURL *)outputFileURL
{
	if ([self.delegate respondsToSelector:@selector(sfRecorderWrapperDidStopRecording:withFileURL:)]) {
		[self.delegate sfRecorderWrapperDidStopRecording:self withFileURL:outputFileURL];
	}
}

@end