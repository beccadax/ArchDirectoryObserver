
//  ArchDirectoryObserver.h  Packer
//  Created by Brent Royal-Gordon on 12/29/10. Copyright 2010 Architechies. All rights reserved.

#import "ArchDirectoryObserver.h"
@import CoreServices;

/*! @abstract The observation center is where all the action happens.  
    @note     You usually only need to work with it if you want to observe on a background thread.
              The interface is not terribly different from the NSURL (DirectoryObserver) category.
 */

@interface ArchDirectoryObservationCenter : NSObject

- initWithRunLoop:(NSRunLoop*)runLoop;

+ (instancetype) mainObservationCenter;

@property (readonly) NSRunLoop * runLoop;

/*! @warning We will retain the url, but you have to retain the observer. */

- (void)                     addObserver:(id <ArchDirectoryObserver>)obsrvr forDirectoryAtURL:(NSURL*)url
                             ignoresSelf:(BOOL)ignoresSelf                         responsive:(BOOL)responsive
                                                                                  resumeToken:(id)resumeToken;

- (void)                  removeObserver:(id <ArchDirectoryObserver>)obsrvr forDirectoryAtURL:(NSURL*)url;

- (void) removeObserverForAllDirectories:(id <ArchDirectoryObserver>)obsrvr;

- (ArchDirectoryObservationResumeToken)laterOfResumeToken:(ArchDirectoryObservationResumeToken)t1
                                           andResumeToken:(ArchDirectoryObservationResumeToken)t2;
@end

