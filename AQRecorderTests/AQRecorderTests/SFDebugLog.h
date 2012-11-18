//
//  SFDebugLog.h
//  TaxiPassenger
//
//  Created by Christos Sotiriou on 9/29/11.
//  Copyright 2011 Oramind. All rights reserved.
//

#import <Foundation/Foundation.h>




#ifdef DEBUG_LOGGING
	#ifdef FILE_LOGGING
		#define SFDebugLog(args...) DDLogVerbose(args) 
	#else
		#define SFDebugLog(args...) _SFDebugLog(__FILE__,__LINE__,__PRETTY_FUNCTION__,args);
#endif
#else
	#define SFDebugLog(x...)
#endif

void _SFDebugLog(const char *file, int lineNumber, const char *funcName, NSString *format,...);
