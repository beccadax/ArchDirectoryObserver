

//#define LogBlue(frmt, ...) NSLog()

//#define XCODE_COLORS_ESCAPE @"\033["
//#define XCODE_CO/LORS_RESET_FG  XCODE_COLORS_ESCAPE @"fg;" // Clear any foreground color
//#define XCODE_/.COLORS_RESET_BG  XCODE_COLORS_ESCAPE @"bg;" // Clear any background color
//#define XCODE/_COLORS_RESET     XCODE_COLORS_ESCAPE    // Clear any foreground or background color
//#define RAND/O [NSString stringWithFormat:@"%i,%i,%i;;",,arc4random % 255,arc4random % 255]
#define NSLog(...) printf("\033[fg%i,%i,%i;%s\033[;\n"  ,arc4random_uniform(255)+1,arc4random_uniform(255)+1,arc4random_uniform(233)+1,[NSString stringWithFormat: __VA_ARGS__].UTF8String)
//#define NSLogI(frmt, ...) printf("%s\n",[NSString stringWithFormat:(XCODE_COLORS_ESCAPE @"fg0,0,0;" XC/ODE_COLORS_ESCAPE "bg255,255,255;" frmt XCODE_COLORS_RESET), ##__VA_ARGS__].UTF8String)

#import <ArchDirectoryObserver/ArchDirectoryObserver.h>
static NSURL *u;

//@import AtoZ;
@interface TestWatcher : NSObject <ArchDirectoryObserver> @end
@implementation TestWatcher
/*
- (void)observedDirectory:(NSURL*)obsrvdURL childrenAtURLDidChange:(NSURL*)changedURL
               historical:(BOOL)hist               resumeToken:(ArchDirectoryObservationResumeToken)rt {
    NSLog(@"Files in %@ have changed!", changedURL.path);
}
- (void)observedDirectory:(NSURL*)obsrvdURL         descendantsAtURLDidChange:(NSURL*)changedURL
                   reason:(ArchDirectoryObserverDescendantReason)r historical:(BOOL)h
              resumeToken:(ArchDirectoryObservationResumeToken)rt {

    NSLog(@"Descendents below %@ have changed!", changedURL.path);
}
- (void)observedDirectory:(NSURL*)obsrvdURL ancestorAtURLDidChange:(NSURL*)changedURL
               historical:(BOOL)h                      resumeToken:(ArchDirectoryObservationResumeToken)rt {

    NSLog(@"%@, ancestor of your directory, has changed!", changedURL.path);
}
*/
void LookupChangesSince(NSString* tokenPath) {

  NSData *codedData = [NSData.alloc initWithContentsOfFile:tokenPath];
  NSKeyedUnarchiver *unarchiver = [NSKeyedUnarchiver.alloc initForReadingWithData:codedData];
  id diskt = [unarchiver decodeObjectForKey:@"token"];
  [unarchiver finishDecoding];
  id token = [diskt valueForKey:@"token"];
  NSLog(@"token from disk %@. ",[diskt valueForKey:@"description"]);

  [NSOperationQueue.mainQueue addOperation:[NSBlockOperation blockOperationWithBlock:^{
    [u checkHistoryOf:ArchDirectoryRelatedChildren|ArchDirectoryRelatedDescendant|ArchDirectoryRelatedAncestor
                since:token
               review:^(ArchDirectoryRelationship relation,
                                                          ArchDirectoryObserverDescendantReason t,
                                                                                           BOOL fin){
      NSLog(@"got %@, %@, fin:%@",DescribeRelationship(relation), DescribeReason(t),fin ? @"FINAL":@"STILLGOING");
    }];
  }]];
  system([@"open " stringByAppendingString:u.path].UTF8String);
  [@[@"alpha",@"theta", @"vageenathon"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {


    NSError *r; id z = [u URLByAppendingPathComponent:obj];
    [obj writeToURL:z atomically:YES encoding:NSUTF8StringEncoding error:&r];
//    NSLog(@"Writing %@ to..  %@.e:%@", obj, z, r);

  }];
  // [data isEqualToData:codedData]?@"YES" :@"NO");
}
@end

void SaveToken(NSURL *a, id t) {  NSMutableData *data = NSMutableData.new;
  NSKeyedArchiver *archiver = [NSKeyedArchiver.alloc initForWritingWithMutableData:data];
  [archiver encodeObject:@{@"url":a, @"token":t, @"description":NSDate.date.description} forKey:@"token"];
  [archiver finishEncoding];
  [data writeToFile:@"savedToken.json" atomically:YES];
}

int main(int argc, const char * argv[]) {  @autoreleasepool {


  u = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]] isDirectory:YES];

  [NSFileManager.defaultManager createDirectoryAtURL:u withIntermediateDirectories:YES attributes:nil error:nil];
  [u getNextToken:^(NSURL *a, ArchDirectoryObservationResumeToken t) {
      NSLog(@"finally got token! %@", t);
      SaveToken(a, t);
      LookupChangesSince(@"savedToken.json");
  }];

//          saveAsJSON ([NSArchiver archivedDataWithRootObject:t]);
//          id plist = readFromJSONFile (@"plist.json");
//          NSLog (@"read JSON: %@", plist);

//      NSLog(@"Token:%@", t);
//      TestWatcher *w = TestWatcher.new;
//      [u addDirectoryObserver:w options:0 resumeToken:t];

      [NSRunLoop.currentRunLoop run];
  }
    return 0;
}

