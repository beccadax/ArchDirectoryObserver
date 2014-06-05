
//  ArchDirectoryObserver.m  Packer
//  Created by Brent Royal-Gordon on 12/29/10.  Copyright 2010 Architechies. All rights reserved.

#define PURGESTREAM(X)   ({ FSEventStreamStop(X); FSEventStreamInvalidate(X); FSEventStreamRelease(X); })

#import "ArchDirectoryObservationCenter.h"

@interface ArchDirectoryEventStream : NSObject

- initWithObserver:(id<ArchDirectoryObserver>)o center:(ArchDirectoryObservationCenter*)c directoryURL:(NSURL*)u
       ignoresSelf:(BOOL)i                  responsive:(BOOL)r                         resumeAtEventID:(FSEventStreamEventId)e;

@property            BOOL historical;
@property (readonly) NSURL * URL;
@property (readonly) FSEventStreamRef eventStream;
@property (readonly) FSEventStreamEventId lastEventID;
@property (readonly) id <ArchDirectoryObserver> observer;
@property (readonly) ArchDirectoryObservationCenter * center;
@end

@implementation ArchDirectoryObservationCenter  + (instancetype) mainObservationCenter {

  static id singleton;  static dispatch_once_t once;  return dispatch_once(&once, ^{

    singleton = [ArchDirectoryObservationCenter.alloc initWithRunLoop:NSRunLoop.mainRunLoop]; }), singleton;
}

@synthesize runLoop;  - initWithRunLoop:(NSRunLoop*)rloop {

  return self = [super init] ? runLoop = rloop, eventStreams = NSMutableArray.new, self : nil;
}

- (ArchDirectoryEventStream*)eventStreamWithObserver:(id<ArchDirectoryObserver>)observer forDirectoryAtURL:(NSURL*)url {

  id x = [eventStreams filteredArrayUsingPredicate:
                   [NSPredicate predicateWithBlock:^BOOL(ArchDirectoryEventStream * evStream, NSDictionary *b) {

    return observer == evStream.observer && [url isEqual:evStream.URL]; }]]; return x ? [x firstObject] : nil;
}

- resumeTokenForEventID:(FSEventStreamEventId)eventID {

  return [NSKeyedArchiver archivedDataWithRootObject:[NSNumber numberWithUnsignedLongLong:eventID]];
}

- (FSEventStreamEventId) eventIDForResumeToken:(ArchDirectoryObservationResumeToken)token {

  return token && token != NSNull.null ? [[NSKeyedUnarchiver unarchiveObjectWithData:(NSData*)token] unsignedLongLongValue]
                                       : kFSEventStreamEventIdSinceNow;
}

- (ArchDirectoryObservationResumeToken)laterOfResumeToken:(ArchDirectoryObservationResumeToken)t1
                                           andResumeToken:(ArchDirectoryObservationResumeToken)t2 {

  return [self eventIDForResumeToken:t1] > [self eventIDForResumeToken:t2] ? t1 : t2;
}

- (void)                     addObserver:(id<ArchDirectoryObserver>)observer forDirectoryAtURL:(NSURL *)url
                             ignoresSelf:(BOOL)ignoresSelf                          responsive:(BOOL)responsive
                                                                                   resumeToken:(id)resumeToken {
  if([self eventStreamWithObserver:observer forDirectoryAtURL:url])
    @throw [NSException exceptionWithName:NSRangeException
                                   reason:[NSString stringWithFormat:@"The observer %@ is already observing the directory %@.", observer, url]
                                userInfo:nil];

  FSEventStreamEventId eventID = [self eventIDForResumeToken:resumeToken];

  [eventStreams addObject:[ArchDirectoryEventStream.alloc initWithObserver:observer center:self directoryURL:url ignoresSelf:ignoresSelf responsive:responsive resumeAtEventID:eventID]];
}

- (void)                  removeObserver:(id<ArchDirectoryObserver>)observer forDirectoryAtURL:(NSURL *)url {

  ArchDirectoryEventStream * eventStream = [self eventStreamWithObserver:observer forDirectoryAtURL:url];

  if(!eventStream) @throw [NSException exceptionWithName:NSRangeException
                                                  reason:[NSString stringWithFormat:@"The observer %@ is not observing the directory %@.", observer, url]
                                                userInfo:nil];
  [eventStreams removeObject:eventStream];
}

- (void) removeObserverForAllDirectories:(id <ArchDirectoryObserver>)observer {

  NSMutableIndexSet * doomedIndexes = NSMutableIndexSet.indexSet;

  [eventStreams enumerateObjectsUsingBlock:^(ArchDirectoryEventStream * stream, NSUInteger idx, BOOL *stop) {
    if(stream.observer == observer) [doomedIndexes addIndex:idx];
  }];
  [eventStreams removeObjectsAtIndexes:doomedIndexes];
}

@end

@implementation ArchDirectoryEventStream {  @private

  BOOL historical; NSURL * URL; ArchDirectoryObservationCenter * center;
  FSEventStreamRef eventStream;   id <ArchDirectoryObserver>   observer;  }

  @synthesize center, eventStream, observer, URL, historical;

const FSEventStreamEventFlags kArchDirectoryEventStreamNeedsDescendantScanMask = kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagMount |
                                                                                         kFSEventStreamEventFlagUnmount | kFSEventStreamEventFlagEventIdsWrapped;
static void ArchDirectoryEventStreamCallback(const FSEventStreamRef streamRef,
                                             void * context,
                                             size_t numEvents,
                                             NSArray * eventPaths,
                                             const FSEventStreamEventFlags eventFlags[],
                                             const FSEventStreamEventId eventIds[]) {
  ArchDirectoryEventStream * self = (__bridge id)context;

  for(size_t i = 0; i < numEvents; i++) {
    NSURL * thisEventURL                    = [NSURL fileURLWithPath:[eventPaths objectAtIndex:i]];
    FSEventStreamEventFlags thisEventFlags  = eventFlags[i];
    id thisResumeToken                      = [self.center resumeTokenForEventID:eventIds[i]];

    if(thisEventFlags & kFSEventStreamEventFlagHistoryDone)

    { NSLog(@"HISTORY DONE!"); self.historical = NO;  }

    else if(thisEventFlags & kArchDirectoryEventStreamNeedsDescendantScanMask) {

      ArchDirectoryObserverDescendantReason reason =

      thisEventFlags & (kFSEventStreamEventFlagKernelDropped
                     |  kFSEventStreamEventFlagUserDropped)   ? ArchDirectoryObserverEventDroppedReason    :
      thisEventFlags & kFSEventStreamEventFlagMount           ? ArchDirectoryObserverVolumeMountedReason   :
      thisEventFlags & kFSEventStreamEventFlagUnmount         ? ArchDirectoryObserverVolumeUnmountedReason :
      thisEventFlags & kFSEventStreamEventFlagEventIdsWrapped ? ArchDirectoryObserverEventIDsWrappedReason :
                                                                ArchDirectoryObserverCoalescedReason       ;

      [self.observer observedDirectory:self.URL descendantsAtURLDidChange:thisEventURL
                                reason:reason historical:self.historical        resumeToken:thisResumeToken];
    }
    else if(thisEventFlags & kFSEventStreamEventFlagRootChanged)
      [self.observer observedDirectory:self.URL ancestorAtURLDidChange:thisEventURL
                            historical:self.historical     resumeToken:thisResumeToken];
    else  [self.observer observedDirectory:self.URL childrenAtURLDidChange:thisEventURL
                                historical:self.historical     resumeToken:thisResumeToken];
  }
}

- initWithObserver:(id<ArchDirectoryObserver>)obs center:(ArchDirectoryObservationCenter*)cent directoryURL:(NSURL *)url ignoresSelf:(BOOL)ignoresSelf responsive:(BOOL)responsive resumeAtEventID:(FSEventStreamEventId)eventID {

  if(!(self = [super init])) return nil;
  center    = cent;
  observer  = obs;
  URL       = [url copy];

  FSEventStreamContext context;
  context.copyDescription         = NULL;
  context.release                 = NULL;
  context.retain                  = NULL;
  context.version                 = 0;
  context.info                    = (__bridge void*)self;

  FSEventStreamCreateFlags flags  = kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagUseCFTypes;
  CFTimeInterval latency          = 5.0;

  if(ignoresSelf)                 flags |= kFSEventStreamCreateFlagIgnoreSelf;
  if(responsive) { latency = 1.0; flags |= kFSEventStreamCreateFlagNoDefer;     }

  eventStream = FSEventStreamCreate(NULL, (FSEventStreamCallback)ArchDirectoryEventStreamCallback, &context, (__bridge CFArrayRef)[NSArray arrayWithObject:[url path]], eventID, latency, flags);

  FSEventStreamScheduleWithRunLoop(eventStream, [center.runLoop getCFRunLoop], kCFRunLoopCommonModes);
  FSEventStreamStart(eventStream);

  if(eventID == kFSEventStreamEventIdSinceNow)
    [observer observedDirectory:URL descendantsAtURLDidChange:URL reason:ArchDirectoryObserverNoHistoryReason historical:YES resumeToken:[self.center resumeTokenForEventID:eventID]];
    else { historical = YES; [(NSObject*)self.observer setValue:@NO forKey:@"allNew"];}
  //:@selector(setHistorical:)] ?: [self.observer setHistorical:YES]; }
  return self;
}

- (FSEventStreamEventId) lastEventID { return FSEventStreamGetLatestEventId(self.eventStream); }

- (void) finalize { PURGESTREAM(eventStream); }
- (void) dealloc  { PURGESTREAM(eventStream); }

@end
