"use strict";
function StreamingPlayer() {
}

StreamingPlayer.prototype.play = function (url, options) {
	options = options || {};
	cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingPlayer", "play", [url, options]);
};

StreamingPlayer.prototype.pause = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "pause", []);
};

StreamingPlayer.prototype.close = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "close", []);
};

StreamingPlayer.prototype.onPlay = function(callback) {
    document.addEventListener("streamingplayer:play", callback, false);
};

StreamingPlayer.prototype.onPause = function(callback) {
    document.addEventListener("streamingplayer:pause", callback, false);
};

StreamingPlayer.prototype.onTrackStart = function(callback) {
    document.addEventListener("streamingplayer:trackStart", callback, false);
};

StreamingPlayer.prototype.onTrackEnd = function(callback) {
    document.addEventListener("streamingplayer:trackEnd", callback, false);
};

StreamingPlayer.prototype.nextTrack = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "nextTrack", []);
};

StreamingPlayer.prototype.prevTrack = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "prevTrack", []);
};

StreamingPlayer.prototype.playTrackId = function(idx, win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "playTrackId", [idx]);
};

StreamingPlayer.install = function () {
	if (!window.plugins) {
		window.plugins = {};
	}
	window.plugins.streamingPlayer = new StreamingPlayer();
	return window.plugins.streamingPlayer;
};

cordova.addConstructor(StreamingPlayer.install);

// This channel receives nfcEvent data from native code
// and fires JavaScript events.
require('cordova/channel').onCordovaReady.subscribe(function() {
    function success(message) {
        if (!message.type) {
            console.log(message);
        } else {
            var e = document.createEvent('Events');
            e.initEvent(message.type);
            e.data = message.data;
            document.dispatchEvent(e);
        }
    }
    require('cordova/exec')(success, null, 'StreamingPlayer', 'channel', []);
});
