#import "StreamingPlayer.h"
#import <Cordova/CDV.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import "LandscapeVideo.h"
#import "PortraitVideo.h"
#import "AVQueuePlayerPrevious.h"

@interface StreamingPlayer()
- (void)play:(CDVInvokedUrlCommand *) command;
- (void)pause:(CDVInvokedUrlCommand *) command;
- (void)close:(CDVInvokedUrlCommand *) command;
- (void)nextTrack:(CDVInvokedUrlCommand *) command;
- (void)prevTrack:(CDVInvokedUrlCommand *) command;
- (void)playTrackId:(CDVInvokedUrlCommand *) command;

- (void)parseOptions:(NSDictionary *) options;
- (void)startPlayer:(NSString*)uri;
- (void)moviePlayBackDidFinish:(NSNotification*)notification;
- (void)timerTick:(NSTimer*)timer;
- (void)respondToSwipeGesture:(UISwipeGestureRecognizer *)sender;
- (void)sendResult:(NSString*)errorMsg;
- (void)next;
- (void)prev;
- (void)cleanup;
- (void)fireEvent:(NSString *) name data:(NSDictionary *)data;
@end

@implementation StreamingPlayer {
    NSString* callbackId;
    AVPlayerViewController *moviePlayer;
    BOOL shouldAutoClose;
    BOOL initFullscreen;
    NSString *mOrientation;
    AVQueuePlayerPrevious *movie;
    NSTimer *timer;
}

-(void)play:(CDVInvokedUrlCommand *) command {
    NSLog(@"play called");
    callbackId = command.callbackId;

    [self ignoreMute];
    NSString *mediaUrl  = [command.arguments objectAtIndex:0];
    [self parseOptions:[command.arguments objectAtIndex:1]];
    [self startPlayer:mediaUrl];
    [self sendResult:@""];
}

-(void)pause:(CDVInvokedUrlCommand *) command {
    NSLog(@"pause called");
    callbackId = command.callbackId;
    if (moviePlayer.player) {
        [moviePlayer.player pause];
        int index = [movie getIndex];
        [self
         fireEvent:@"streamingplayer:pause"
         data:@{
                @"index" : [NSNumber numberWithInt:index]
                }];
    }
    [self sendResult:@""];
}

-(void)close:(CDVInvokedUrlCommand *) command {
    NSLog(@"close called");
    callbackId = command.callbackId;
    [self cleanup];
    [self sendResult:@""];
}

-(void)nextTrack:(CDVInvokedUrlCommand *) command {
    NSLog(@"nextTrack called");
    callbackId = command.callbackId;
    [self next];
    [self sendResult:@""];
}

-(void)prevTrack:(CDVInvokedUrlCommand *) command {
    NSLog(@"prevTrack called");
    callbackId = command.callbackId;
    [self prev];
    [self sendResult:@""];
}

-(void)playTrackId:(CDVInvokedUrlCommand *) command {
    int idx  = [[command.arguments objectAtIndex:0] intValue];
    NSLog(@"playTrackId called, idx is %d",idx);
    callbackId = command.callbackId;
    if (movie) {
        [movie playItemIdx:idx];
    }
    [self sendResult:@""];
}

-(void) next{
    if(![movie isAtEnd]) {
        [movie advanceToNextItem];
        int index = [movie getIndex];
        [self
         fireEvent:@"streamingplayer:trackChange"
         data:@{
                @"index" : [NSNumber numberWithInt:index],
                @"direction" : @1,
         }];
    }
}

-(void) prev{
    if(![movie isAtBeginning]) {
        [movie playPreviousItem];
        int index = [movie getIndex];
        [self
         fireEvent:@"streamingplayer:trackChange"
         data:@{
                @"index" : [NSNumber numberWithInt:index],
                @"direction" : @0,
         }];
    }
}


-(void)parseOptions:(NSDictionary *)options {
    // Common options
    mOrientation = options[@"orientation"] ?: @"default";
    
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"shouldAutoClose"]) {
        shouldAutoClose = [[options objectForKey:@"shouldAutoClose"] boolValue];
    } else {
        shouldAutoClose = YES;
    }
    
    if (![options isKindOfClass:[NSNull class]] && [options objectForKey:@"initFullscreen"]) {
        initFullscreen = [[options objectForKey:@"initFullscreen"] boolValue];
    } else {
        initFullscreen = YES;
    }
    
}

-(void)startPlayer:(NSString*)uri {
    NSLog(@"startplayer called");
    
    NSArray *urls = [uri componentsSeparatedByString:@"|"];   //take the one array for split the string
    NSMutableArray *items = [NSMutableArray new];
    
    int i;
    int count;
    
    for (i = 0, count = [urls count]; i < count; i = i + 1)
    {
        [items addObject:[AVPlayerItem playerItemWithURL:[NSURL URLWithString:[urls objectAtIndex:i]]]];
    }
    
    movie = [[AVQueuePlayerPrevious alloc] initWithItems:items];
    [self handleOrientation];
    [self handleGestures];
    
    [moviePlayer setPlayer:movie];
    [moviePlayer setShowsPlaybackControls:YES];
    [moviePlayer setUpdatesNowPlayingInfoCenter:YES];
    
    if(@available(iOS 11.0, *)) { [moviePlayer setEntersFullScreenWhenPlaybackBegins:YES]; }
    
    // present modally so we get a close button
    [self.viewController presentViewController:moviePlayer animated:YES completion:^(void){
        [self->moviePlayer.player play];
    }];
    
    // setup listners
    [self handleListeners];
}

- (void) handleListeners {
    
    // Listen for re-maximize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // Listen for minimize
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    // Listen for status change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appMovieStatusChange:)
                                                 name:@"AVPlayerStatusChangeNotification"
                                               object:moviePlayer.player.currentItem];

    // Listen for playback finishing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];
    
    // Listen for errors
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:moviePlayer.player.currentItem];
    
    [movie addObserver:self forKeyPath:@"status" options:0 context:nil];

    
    /* Listen for click on the "Done" button
     
     // Deprecated.. AVPlayerController doesn't offer a "Done" listener... thanks apple. We'll listen for an error when playback finishes
     [[NSNotificationCenter defaultCenter] addObserver:self
     selector:@selector(doneButtonClick:)
     name:MPMoviePlayerWillExitFullscreenNotification
     object:nil];
     */

    timer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                     target:self
                                   selector:@selector(timerTick:)
                                   userInfo:nil
                                    repeats:YES];

}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == movie && [keyPath isEqualToString:@"status"]) {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:@"AVPlayerStatusChangeNotification"
         object:movie.currentItem];
    }
}

// Ignore the mute button
-(void)ignoreMute {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
}

- (void) handleGestures {
    // Get buried nested view
    UIView *contentView = [moviePlayer.view valueForKey:@"contentView"];
    
    // loop through gestures, remove swipes
    for (UIGestureRecognizer *recognizer in contentView.gestureRecognizers) {
        NSLog(@"gesture loop ");
        NSLog(@"%@", recognizer);
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIRotationGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
        if ([recognizer isKindOfClass:[UISwipeGestureRecognizer class]]) {
            [contentView removeGestureRecognizer:recognizer];
        }
    }
    
    UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget: self action: @selector(respondToSwipeGesture:)];
    swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
    [contentView addGestureRecognizer:swipeRight];
    
    UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget: self action: @selector(respondToSwipeGesture:)];
    swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
    [contentView addGestureRecognizer:swipeLeft];

    
}

- (void) respondToSwipeGesture:(UISwipeGestureRecognizer *)sender {
    if ( sender.direction == UISwipeGestureRecognizerDirectionLeft ){
        NSLog(@" *** SWIPE LEFT ***");
        [self next];
    }
    if ( sender.direction == UISwipeGestureRecognizerDirectionRight ){
        NSLog(@" *** SWIPE RIGHT ***");
        [self prev];
    }
    if ( sender.direction== UISwipeGestureRecognizerDirectionUp ){
        NSLog(@" *** SWIPE UP ***");
        
    }
    if ( sender.direction == UISwipeGestureRecognizerDirectionDown ){
        NSLog(@" *** SWIPE DOWN ***");
        
    }
}

- (void) handleOrientation {
    // hnadle the subclassing of the view based on the orientation variable
    if ([mOrientation isEqualToString:@"landscape"]) {
        moviePlayer            =  [[LandscapeAVPlayerViewController alloc] init];
    } else if ([mOrientation isEqualToString:@"portrait"]) {
        moviePlayer            =  [[PortraitAVPlayerViewController alloc] init];
    } else {
        moviePlayer            =  [[AVPlayerViewController alloc] init];
    }
}

- (void) appDidEnterBackground:(NSNotification*)notification {
    NSLog(@"appDidEnterBackground");
}

- (void) appDidBecomeActive:(NSNotification*)notification {
    NSLog(@"appDidBecomeActive");
}

- (void)appMovieStatusChange:(NSNotification*)notification {
    NSLog(@"appStatusChange %@", notification.userInfo);
    
    int index = [movie getIndex];
    NSString* status = [NSString stringWithFormat:@"%ld",(long)movie.currentItem.status];
    [self
     fireEvent:@"streamingplayer:trackStatusChange"
     data:@{
            @"index" : [NSNumber numberWithInt:index],
            @"status" : status,
            }];
    if(AVPlayerStatusReadyToPlay == movie.currentItem.status) {
        [self
         fireEvent:@"streamingplayer:play"
         data:@{
                @"index" : [NSNumber numberWithInt:index]
                }];
    }
}

- (void) moviePlayBackDidFinish:(NSNotification*)notification {
    NSLog(@"Playback did finish with error message being %@", notification.userInfo);
    int index = [movie getIndex];

    [self
     fireEvent:@"streamingplayer:trackEnd"
     data:@{
            @"index" : [NSNumber numberWithInt:index],
            @"direction" : @0,
    }];
    
    NSDictionary *notificationUserInfo = [notification userInfo];
    NSNumber *errorValue = [notificationUserInfo objectForKey:AVPlayerItemFailedToPlayToEndTimeErrorKey];
    NSString *errorMsg;
    if (errorValue) {
        NSError *mediaPlayerError = [notificationUserInfo objectForKey:@"error"];
        if (mediaPlayerError) {
            errorMsg = [mediaPlayerError localizedDescription];
        } else {
            errorMsg = @"Unknown error.";
        }
        NSLog(@"Playback failed: %@", errorMsg);
    }
    
    [self sendResult: errorMsg];
}

- (void) sendResult:(NSString*)errorMsg {
//    if (false || [errorMsg length] != 0) {
        CDVPluginResult* pluginResult;
        if ([errorMsg length] != 0) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorMsg];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:true];
        }
        NSLog(@"Sending result %@", pluginResult);
        [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
//    }
}

-(void) timerTick:(NSTimer*)timer {
    //NSLog(@"Checking for is closed");
    if (moviePlayer.player.rate == 0 &&
        (moviePlayer.isBeingDismissed || moviePlayer.nextResponder == nil)) {
        NSLog(@"Close button clicked");
        [self cleanup];
        [self
         fireEvent:@"streamingplayer:close"
         data:@{
                }];
        
    }
}


- (void)cleanup {
    NSLog(@"Clean up called");
    initFullscreen = false;
    
    // Remove playback finished listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemDidPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove playback finished error listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:AVPlayerItemFailedToPlayToEndTimeNotification
     object:moviePlayer.player.currentItem];
    // Remove orientation change listener
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];
    
    if (moviePlayer) {
        [moviePlayer.player pause];
        [moviePlayer dismissViewControllerAnimated:YES completion:nil];
        moviePlayer = nil;
    }
    
    if(timer) {
        [timer  invalidate];
        timer = nil;
    }
}

-(void) fireEvent:(NSString *) name data:(NSDictionary *) data {
    NSLog(@"firing event %@ with data %@", name, data);

    NSString *function = [NSString stringWithFormat:@"cordova.fireDocumentEvent('%@', %s)", name, [[self toJSONString:data] UTF8String]];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[self webView] isKindOfClass:WKWebView.class])
          [(WKWebView*)[self webView] evaluateJavaScript:function completionHandler:^(id result, NSError *error) {}];
        else
          [(UIWebView*)[self webView] stringByEvaluatingJavaScriptFromString: function];
    });
}

-(NSString *) toJSONString:(NSDictionary *) data {
    return dictionaryAsJSONString(data);
}

NSString* dictionaryAsJSONString(NSDictionary *dict) {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *jsonString;
    if (! jsonData) {
        jsonString = [NSString stringWithFormat:@"Error creating JSON for  %@", error];
        NSLog(@"%@", jsonString);
    } else {
        jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
    return jsonString;
}

@end
