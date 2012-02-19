//
//  ArchDirectoryObserver.h
//  Packer
//
//  Created by Brent Royal-Gordon on 12/29/10.
//  Copyright 2010 Architechies. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>
#import "ArchDirectoryObserverTypes.h"

@interface ArchDirectoryObservationCenter : NSObject {
@private
    NSMutableArray * eventStreams;
    NSRunLoop * runLoop;
}

+ (ArchDirectoryObservationCenter*)mainObservationCenter;

- (id)initWithRunLoop:(NSRunLoop*)runLoop;

@property (readonly) NSRunLoop * runLoop;

// We will retain the url, but you have to retain the observer.
- (void)addObserver:(id <ArchDirectoryObserver>)observer forDirectoryAtURL:(NSURL*)url ignoresSelf:(BOOL)ignoresSelf responsive:(BOOL)responsive resumeToken:(id)resumeToken;
- (void)removeObserver:(id <ArchDirectoryObserver>)observer forDirectoryAtURL:(NSURL*)url;
- (void)removeObserverForAllDirectories:(id <ArchDirectoryObserver>)observer;

- (ArchDirectoryObservationResumeToken)laterOfResumeToken:(ArchDirectoryObservationResumeToken)token1 andResumeToken:(ArchDirectoryObservationResumeToken)token2;

@end

