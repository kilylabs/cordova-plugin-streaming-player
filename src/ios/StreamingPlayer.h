#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Cordova/CDVPlugin.h>
#import <AVFoundation/AVFoundation.h>
#import <WebKit/WebKit.h>

@interface StreamingPlayer : CDVPlugin
@property (nonatomic, strong) AVAudioSession* avSession;

- (void)play:(CDVInvokedUrlCommand *) command;
- (void)pause:(CDVInvokedUrlCommand *) command;
- (void)close:(CDVInvokedUrlCommand *) command;
- (void)nextTrack:(CDVInvokedUrlCommand *) command;
- (void)prevTrack:(CDVInvokedUrlCommand *) command;
- (void)playTrackId:(CDVInvokedUrlCommand *) command;

@end
