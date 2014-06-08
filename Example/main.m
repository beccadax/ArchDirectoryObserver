
#define NSLog(...) printf("%s\n", [NSString stringWithFormat:__VA_ARGS__].UTF8String)

#import <ArchDirectoryObserver/ArchDirectoryObserver.h>

static NSURL *TestFolder (){ static NSURL *testF; return testF = testF ?: ({

  testF = [NSURL fileURLWithPath:[@"/tmp".stringByStandardizingPath stringByAppendingFormat:@"/randomFolder%i", arc4random_uniform(4000)]];

  [NSFileManager.defaultManager createDirectoryAtURL:testF withIntermediateDirectories:YES attributes:nil error:nil]; testF; });
}

void LookupChangesSince(NSString* tokenPath) {

  TokenArchive *a = [TokenArchive tokenFromArchiveAtPath:tokenPath];  NSLog(@"Coerced token from archive: %@", a);

  ArchDirectoryObservationResumeToken token = a.token;

  [NSOperationQueue.mainQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
    [TestFolder() checkHistoryOf:ArchDirectoryRelatedChildren|ArchDirectoryRelatedDescendant|ArchDirectoryRelatedAncestor
                since:token
               review:^(ArchDirectoryRelationship relation,
            ArchDirectoryObserverDescendantReason reason,
                                             BOOL finished){
      NSLog(@"got %@, %@, fin:%@",  DescribeRelationship(relation),
                                    DescribeReason(reason),
                                    finished ? @"FINAL" : @"STILL GOING");
    }];
  }]];

//  system([@"open " stringByAppendingString:u.path].UTF8String);

  for (NSString* file in @[@"alpha",@"theta", @"vageenathon"]) { // This is to force changes to directory for testing.
    [file writeToURL:[TestFolder() URLByAppendingPathComponent:file] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  }
}

int main(int argc, const char * argv[]) {

  @autoreleasepool {

    [TestFolder() getNextToken:^(NSURL *a, ArchDirectoryObservationResumeToken t) {
        NSLog(@"finally got token! Creating archive...", nil);
        TokenArchive *archive = [TokenArchive tokenWithToken:t forURL:TestFolder()];
        NSLog(@"Created token archive:%@", archive);
        [archive writeToFile:@"savedToken.json"];
        LookupChangesSince(@"savedToken.json");
    }];

    [NSRunLoop.currentRunLoop run];

  }
    return 0;
}

