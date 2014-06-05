//
//  NSURL+DirectoryObserver.m
//  Packer
//
//  Created by Brent Royal-Gordon on 1/2/11.
//  Copyright 2011 Architechies. All rights reserved.
//
#import "ArchDirectoryObserver.h"
#import "ArchDirectoryObservationCenter.h"
@import ObjectiveC;

typedef void(^DidChange)(NSURL*changed, BOOL historic, BOOL finished);

@interface TokenHelper : NSObject <ArchDirectoryObserver>
+ (instancetype) tokenForURL:(NSURL*)u withOptions:(ArchDirectoryObserverOptions)optns nextToken:(NextToken)nT;
+ (instancetype) checkURL:(NSURL*)u regarding:(ArchDirectoryRelationship)related since:(ArchDirectoryObservationResumeToken)token then:(WhileYouWereAway)report;
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

+ (instancetype) checkURL:(NSURL*)u regarding:(ArchDirectoryRelationship)related since:(ArchDirectoryObservationResumeToken)token then:(WhileYouWereAway)report {

  TokenHelper*x = self.new; x.URL = u; x->rSearch = related; x.report = [report copy]; x->historySearch = YES; x->token = token;
  objc_setAssociatedObject(u, _cmd, x, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [u addDirectoryObserver:x options:1 resumeToken:x->token];  return x;
}

+ (instancetype) tokenForURL:(NSURL*)u withOptions:(ArchDirectoryObserverOptions)optns nextToken:(NextToken)nT {

  TokenHelper * x = self.new; x.URL = u; x.nextToken = [nT copy]; x->historySearch = NO;
  objc_setAssociatedObject(u, @selector(nextToken), x, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [u addDirectoryObserver:x options:optns resumeToken:nil]; return x;
}
- (void) die { [NSURL removeObserverForAllDirectories:self]; objc_setAssociatedObject(self.URL, @selector(nextToken), nil, 0); }

- (void) gotToken:(ArchDirectoryObservationResumeToken)t { //if (rSearch != (ArchDirectoryRelationship)-99) return;

 self.nextToken(self.URL,t); [self die];
}

- (void)observedDirectory:(NSURL*)observedURL childrenAtURLDidChange:(NSURL*)changedURL historical:(BOOL)historicCh resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {

  NSLog(@"Files in children at %@ have changed! (%@)", changedURL.path, self.allNew?@"ALLNEW":@"historical");
 !historySearch ? [self gotToken:resumeToken] : rSearch & ArchDirectoryRelatedChildren ?  _report(ArchDirectoryRelatedChildren,99,self.allNew) : nil;
}

- (void)observedDirectory:(NSURL*)observedURL descendantsAtURLDidChange:(NSURL*)changedURL reason:(ArchDirectoryObserverDescendantReason)reason historical:(BOOL)historicCh resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {

  NSLog(@"Descendents below %@ have changed! (%@)", changedURL.path, self.allNew?@"ALL NEW!":@"histrical");
  !historySearch ? [self gotToken:resumeToken] : rSearch & ArchDirectoryRelatedDescendant ? _report(ArchDirectoryRelatedDescendant,reason, self.allNew) : nil;
}

- (void)observedDirectory:(NSURL*)observedURL ancestorAtURLDidChange:(NSURL*)changedURL historical:(BOOL)historicCh resumeToken:(ArchDirectoryObservationResumeToken)resumeToken {

  NSLog(@"%@, ancestor of your directory, has changed!", changedURL.path);
  !historySearch ? [self gotToken:resumeToken] : rSearch & ArchDirectoryRelatedAncestor ? _report(ArchDirectoryRelatedAncestor,99, self.allNew) : nil;
}

@end
