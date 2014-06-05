//
//  ArchDirectoryObserver.h
//  Packer
//
//  Created by Brent Royal-Gordon on 12/29/10.
//  Copyright 2010 Architechies. All rights reserved.
//

#import "ArchDirectoryObserver.h"
@import CoreServices;

// The observation center is where all the action happens.  You usually only need to work with it if you want to observe on a background thread.  The interface is not terribly different from the NSURL (DirectoryObserver) category.

@interface ArchDirectoryObservationCenter : NSObject {  @private NSMutableArray * eventStreams; NSRunLoop * runLoop; }

+ (ArchDirectoryObservationCenter*)mainObservationCenter; - (id)initWithRunLoop:(NSRunLoop*)runLoop;

@property (readonly) NSRunLoop * runLoop;


// We will retain the url, but you have to retain the observer.
- (void)                     addObserver:(id <ArchDirectoryObserver>)obsrvr forDirectoryAtURL:(NSURL*)url
                             ignoresSelf:(BOOL)ignoresSelf                         responsive:(BOOL)responsive
                                                                                  resumeToken:(id)resumeToken;

- (void)                  removeObserver:(id <ArchDirectoryObserver>)obsrvr forDirectoryAtURL:(NSURL*)url;
- (void) removeObserverForAllDirectories:(id <ArchDirectoryObserver>)obsrvr;

- (ArchDirectoryObservationResumeToken)laterOfResumeToken:(ArchDirectoryObservationResumeToken)t1
                                           andResumeToken:(ArchDirectoryObservationResumeToken)t2;

@end

