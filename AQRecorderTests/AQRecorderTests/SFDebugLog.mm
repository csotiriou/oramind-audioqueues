//
//  SFDebugLog.m
//  TaxiPassenger
//
//  Created by Christos Sotiriou on 9/29/11.
//  Copyright 2011 Oramind. All rights reserved.
//

#import "SFDebugLog.h"



void _SFDebugLog(const char *file, int lineNumber, const char *funcName, NSString *format,...) {
	@autoreleasepool {
		va_list ap;
		
		va_start (ap, format);
		if (![format hasSuffix: @"\n"]) {
			format = [format stringByAppendingString: @"\n"];
		}
		NSString *body =  [[NSString alloc] initWithFormat: format arguments: ap];
		va_end (ap);
		const char *threadName = [[[NSThread currentThread] name] UTF8String];
		NSString *fileName=[[NSString stringWithUTF8String:file] lastPathComponent];
		NSDate *date = [NSDate date];
		if (threadName) {
			fprintf(stderr,"%s %s/%s (%s:%d) %s", [[date description] UTF8String], threadName,funcName,[fileName UTF8String],lineNumber,[body UTF8String]);
		} else {
			fprintf(stderr,"%s %p/%s (%s:%d) %s", [[date description] UTF8String], [NSThread currentThread],funcName,[fileName UTF8String],lineNumber,[body UTF8String]);
		}
	}
}

