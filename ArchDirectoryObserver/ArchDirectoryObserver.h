
//  ArchDirectoryObserver.h  ArchDirectoryObserver
//  Created by Brent Royal-Gordon on 2/19/12.  Copyright (c) 2012 Architechies. All rights reserved.

@import Foundation;

/*! This opaque token is used to resume observation at a given point in time.  
    Each @c ArchDirectoryObserver callback passes you one; if you 
      - save it (in a `plist` or `NSCoder` archive) and 
      - pass it back in when registering the observer...
    observation will pick up where it left off, even if the process has quit since then.
*/
typedef id <NSCopying, NSCoding> ArchDirectoryObservationResumeToken;

/*! These constants indicate the reason that the observation center believes a descendant scan is needed. */
typedef NS_ENUM(int,ArchDirectoryObserverDescendantReason) {
  ArchDirectoryObserverNoHistoryReason = 0,   ArchDirectoryObserverCoalescedReason,     ArchDirectoryObserverEventDroppedReason,
  ArchDirectoryObserverEventIDsWrappedReason, ArchDirectoryObserverVolumeMountedReason, ArchDirectoryObserverVolumeUnmountedReason };

NS_INLINE NSString* DescribeReason(ArchDirectoryObserverDescendantReason r){ return

  @[@"An observer was added w/ nil resumeToken, so dir's history is unknown.",
    @"The observatio. center coalesced events nearby events.",
    @"Events came too fast and some were dropped.",
    @"Event ID numbers have wrapped and so the history is not reliable.",
    @"A volume was mounted in a subdirectory.",
    @"A volume was unmounted in a subdirectory.", @"UNKNOWN REASON"][MIN(r,6)];
}

typedef NS_OPTIONS(int,ArchDirectoryRelationship)
{
    ArchDirectoryRelatedChildren    = 1 << 0,
    ArchDirectoryRelatedDescendant  = 1 << 1,
    ArchDirectoryRelatedAncestor    = 1 << 2
};
NS_INLINE NSString *DescribeRelationship (ArchDirectoryRelationship r) { return @[@"Child", @"Descnendant", @"ancestor"][r]; }

typedef void(^NextToken)(NSURL*url,    ArchDirectoryObservationResumeToken t);
typedef void(^WhileYouWereAway)(ArchDirectoryRelationship relation, ArchDirectoryObserverDescendantReason t, BOOL final);

@protocol ArchDirectoryObserver <NSObject>  @optional

@property (readonly) BOOL allNew; //  StreamEventFlagHistoryDone = YES

/*! At least one file in the directory indicated by changedURL has changed. 
  You should examine the directory at changedURL to see which files changed.
  @param oURL The URL of the dorectory you're observing.
  @param cURL The URL of the actual directory that changed. This could be a subdirectory.
  @param hist If YES, the event occured sometime b4 the observer was added. If NO, it occurred just now.
  @param rt   The resume token to save if you want to pick back up from this event.
*/
- (void) observedDirectory:(NSURL*)oURL childrenAtURLDidChange:(NSURL*)cURL
                historical:(BOOL)hist              resumeToken:(ArchDirectoryObservationResumeToken)rt;

/*! At least one file somewhere inside--but not necessarily directly descended from--changedURL has changed.  
    You should examine the directory at changedURL and all subdirectories to see which files changed.
  @param oURL The URL of the dorectory you're observing.
  @param cURL The URL of the actual directory that changed. This could be a subdirectory.
  @param r    The reason the observation center can't pinpoint the changed directory. You may want to ignore some reasons -- for example, \c ArchDirectoryObserverNoHistoryReason ... simply means that you didn't pass a resume token when adding the observer, and so you should do an initial scan of the directory.
  @param hist If YES, the event occured sometime b4 the observer was added.  If NO, it occurred just now.
  @param rt   The resume token to save if you want to pick back up from this event.
*/
- (void)observedDirectory:(NSURL*)oURL             descendantsAtURLDidChange:(NSURL*)cURL
                   reason:(ArchDirectoryObserverDescendantReason)r historical:(BOOL)historical
              resumeToken:(ArchDirectoryObservationResumeToken)rt;

/*! An ancestor of the observedURL has changed, so the entire directory tree you're observing may have vanished. 
    You  should ensure it still exists.
  @param oURL The URL of the dorectory you're observing.
  @param cURL The URL of the actual dir. that changed. For this call, it will presumably be an ancestor directory.
  @param hist If YES, the event occured sometime before the observer was added.  If NO, it occurred just now.
  @param rt   The resume token to save if you want to pick back up from this event.
*/
- (void)observedDirectory:(NSURL*)oURL ancestorAtURLDidChange:(NSURL*)cURL
               historical:(BOOL)hist              resumeToken:(ArchDirectoryObservationResumeToken)resumeToken;

@end

typedef NS_OPTIONS(int, ArchDirectoryObserverOptions) {

/*! Receive events for THIS process's actions.
    @note If absent, file system changes initiated by the current process will NOT cause the directory observer to be notified. 
 */ ArchDirectoryObserverObservesSelf = 1,
/*! Favor quicker notifications over reduced number of notifications.
    @note If this flag is ABSENT, a timer is started upon the first change, and after five seconds, an observation for all changes during that period is delivered. If this flag is PRESENT, an observation is sent immediately upon the first change; then a 1 second timer is started, and a second observation is delivered for all changes during that period.
    @note Use this flag if you will want a "live" presentation of what has changed.
 */ ArchDirectoryObserverResponsive = 2
};

@interface NSURL (DirectoryObserver)

- (void) checkHistoryOf:(ArchDirectoryRelationship)relations
                  since:(ArchDirectoryObservationResumeToken)t
                 review:(WhileYouWereAway)report;

- (void)            getNextToken:(NextToken)nT;
- (void) getNextTokenWithOptions:(ArchDirectoryObserverOptions)optns
                       nextToken:(NextToken)nT;

/*! @abstract Start observing this URL.
  @param obsrvr The object to send observation messages to.
  @param optns  Modifies the observation's characteristics. See ArchDirectoryObserverOptions above 4 more details.
  @param rt     If you're interested in what has happened to this folder since your app last stopped observing it, pass in the last resume token your directory observer received. @note If you don't, pass nil (and ignore the callback with a NoHistory reason).
  @note Observation is currently only done on the main thread (and particularly, the main run loop).  To use other run loops, you'll need to create your own ArchDirectoryObservationCenter and go from there.
 */
- (void) addDirectoryObserver:(id<ArchDirectoryObserver>)obsrvr options:(ArchDirectoryObserverOptions)optns
                                                            resumeToken:(ArchDirectoryObservationResumeToken)rT;

/*! Remove the observer.  You should do this in dealloc—ArchDirectoryObserver does not use weak pointers. */
- (void) removeDirectoryObserver:(id <ArchDirectoryObserver>)obsrvr;

/*! Class method to remove all observations using a given observer. */
+ (void) removeObserverForAllDirectories:(id <ArchDirectoryObserver>)obsrvr;

/*! Utility method; given two resume tokens, returns the one that represents a later point in time.  You may find this useful when saving resume tokens. */
+ (ArchDirectoryObservationResumeToken)laterOfDirectoryObservationResumeToken:(ArchDirectoryObservationResumeToken)t1
                                                               andResumeToken:(ArchDirectoryObservationResumeToken)t2;

@end


