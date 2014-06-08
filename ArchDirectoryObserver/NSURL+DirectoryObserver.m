
//  NSURL+DirectoryObserver.m  Packer
//  Created by Brent Royal-Gordon on 1/2/11.  Copyright 2011 Architechies. All rights reserved.

#import "ArchDirectoryObserver.h"
#import "ArchDirectoryObservationCenter.h"
@import ObjectiveC;

typedef void(^DidChange)(NSURL*changed, BOOL historic, BOOL finished);

/*! @abstract Private helper  class, temporarily observes a URL to coerce a token out of it.
    @note We hold a weak reference to the URL, and use associated Objects to piggyback 
          our reference count onto the URL object until we're done, obviating the need to "retain the observer".
    @note  Iterface declaration is up here, so it's visible to the NSURL category, but implementation is down below.
*/
@interface TokenHelper : NSObject <ArchDirectoryObserver>
+ (instancetype) tokenForURL:(NSURL*)u withOptions:(ArchDirectoryObserverOptions)optns nextToken:(NextToken)nT;
+ (instancetype)   checkURL:(NSURL*)u regarding:(ArchDirectoryRelationship)related since:(ArchDirectoryObservationResumeToken)token then:(WhileYouWereAway)report;
@property(copy) NextToken nextToken;
@property(copy) WhileYouWereAway report;
@property(weak) NSURL *URL;
@end

@implementation NSURL (DirectoryObserver)

- (void) checkHistoryOf:(ArchDirectoryRelationship)relations
                  since:(ArchDirectoryObservationResumeToken)t
                 review:(WhileYouWereAway)report { NSParameterAssert(t);

  [TokenHelper checkURL:self regarding:relations since:t then:report];
}

- (void) getNextTokenWithOptions:(ArchDirectoryObserverOptions)optns nextToken:(NextToken)nT{

  [TokenHelper tokenForURL:self withOptions:optns nextToken:nT];
}
- (void) getNextToken:(NextToken)nT {   [self getNextTokenWithOptions:0 nextToken:nT]; }

- (void)addDirectoryObserver:(id <ArchDirectoryObserver>)observer
                     options:(ArchDirectoryObserverOptions)options
                 resumeToken:(id)resumeToken {
    
    [ArchDirectoryObservationCenter.mainObservationCenter addObserver:observer
                                                    forDirectoryAtURL:self
                                                          ignoresSelf: !(options & ArchDirectoryObserverObservesSelf)
                                                           responsive:!!(options & ArchDirectoryObserverResponsive)
                                                          resumeToken:resumeToken];
}
- (void)         removeDirectoryObserver:(id<ArchDirectoryObserver>)obsrvr {

    [ArchDirectoryObservationCenter.mainObservationCenter removeObserver:obsrvr
                                                       forDirectoryAtURL:self];
}
+ (void) removeObserverForAllDirectories:(id<ArchDirectoryObserver>)obsrvr {

    [ArchDirectoryObservationCenter.mainObservationCenter removeObserverForAllDirectories:obsrvr];
}
+ (ArchDirectoryObservationResumeToken) laterOfDirectoryObservationResumeToken:(ArchDirectoryObservationResumeToken)t1
                                                                andResumeToken:(ArchDirectoryObservationResumeToken)t2 {

    return [ArchDirectoryObservationCenter.mainObservationCenter laterOfResumeToken:t1
                                                                     andResumeToken:t2];
}

@end

@implementation TokenHelper { id token; BOOL historySearch; ArchDirectoryRelationship rSearch; } @synthesize allNew;

+ (instancetype) tokenForURL:(NSURL*)u withOptions:(ArchDirectoryObserverOptions)optns nextToken:(NextToken)nT {

  TokenHelper * x = self.new; x.URL = u; x.nextToken = [nT copy]; x->historySearch = NO;
  objc_setAssociatedObject(u, @selector(nextToken), x, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [u addDirectoryObserver:x options:optns resumeToken:nil]; return x; // we return ourself, but no one need bother retaining it!
}

/*! @abstract Consolidated callback selector, as we might get the token from one of any of the three <ArchDirectoryObserver> methods.
    @warning This should only get called ONCE!  Need to rework die method, otherwise. */
- (void) gotToken:(ArchDirectoryObservationResumeToken)gotToken {

  self.nextToken(self.URL,gotToken); [self die];   //we got the token... dispatch the callback, and die.
}

+ (instancetype) checkURL:(NSURL*)u                             regarding:(ArchDirectoryRelationship)related
                    since:(ArchDirectoryObservationResumeToken)token then:(WhileYouWereAway)report {

  TokenHelper*x = self.new; x.URL = u; x->rSearch = related; x.report = [report copy]; x->historySearch = YES; x->token = token;
  objc_setAssociatedObject(u, _cmd, x, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [u addDirectoryObserver:x options:1 resumeToken:x->token];  return x;
}

- (void)observedDirectory:(NSURL*)observed childrenAtURLDidChange:(NSURL*)changed
               historical:(BOOL)wasHist               resumeToken:(ArchDirectoryObservationResumeToken)rToken {

  NSLog(@"Files in children at %@ have changed! (%@)", changed.path, self.allNew?@"ALLNEW":@"historical");
 !historySearch ? [self gotToken:rToken] : rSearch & ArchDirectoryRelatedChildren ?  _report(ArchDirectoryRelatedChildren,99,self.allNew) : nil;
}

- (void)observedDirectory:(NSURL*)observed               descendantsAtURLDidChange:(NSURL*)changed
                   reason:(ArchDirectoryObserverDescendantReason)reason historical:(BOOL)wasHist
              resumeToken:(ArchDirectoryObservationResumeToken)rToken {

  NSLog(@"Descendents below %@ have changed! (%@)", changed.path, self.allNew?@"ALL NEW!":@"HISTORIC");
  !historySearch ? [self gotToken:rToken] : rSearch & ArchDirectoryRelatedDescendant ? _report(ArchDirectoryRelatedDescendant,reason, self.allNew) : nil;
}

- (void)observedDirectory:(NSURL*)observed ancestorAtURLDidChange:(NSURL*)changed
               historical:(BOOL)wasHist               resumeToken:(ArchDirectoryObservationResumeToken)rToken {

  NSLog(@"%@, ancestor of your directory, has changed!", changed.path);
  !historySearch ? [self gotToken:rToken] : rSearch & ArchDirectoryRelatedAncestor ? _report(ArchDirectoryRelatedAncestor,99, self.allNew) : nil;
}

/* Remove ourselves from the URL's associated objects, and stop all observations */
- (void) die { [NSURL removeObserverForAllDirectories:self]; objc_setAssociatedObject(self.URL, @selector(nextToken), nil, 0); }

@end
