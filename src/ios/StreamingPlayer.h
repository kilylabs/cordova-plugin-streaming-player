#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Cordova/CDVPlugin.h>
#import <AVFoundation/AVFoundation.h>

@interface StreamingPlayer : CDVPlugin
@property (nonatomic, strong) AVAudioSession* avSession;

- (void)playVideo:(CDVInvokedUrlCommand*)command;
- (void)playAudio:(CDVInvokedUrlCommand*)command;

@end
