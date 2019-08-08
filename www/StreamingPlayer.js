"use strict";
function StreamingPlayer() {

    var _eventHandlers = {};

    this.addListener = function(name,callback) {
        if(!_eventHandlers[name]) {
            _eventHandlers[name] = [];
        }
        _eventHandlers[name].push(callback);
        document.addEventListener(name,callback,false);
    };

    this.removeListener = function(name,callback) {
        if(_eventHandlers[name] && _eventHandlers[name].length) {
            _eventHandlers[name].forEach(function(v,k){
                if(callback === v) {
                    _eventHandlers[name].splice(k,1);
                }
            });
        }
        document.removeEventListener(name,callback);
    }

    this.removeListeners = function(name) {
        if(_eventHandlers[name] && _eventHandlers[name].length) {
            _eventHandlers[name].forEach(function(v,k){
                this.removeListener(name,v);
            });
        }
    }

}

StreamingPlayer.prototype.play = function (url, options) {
    var _url = url;
	options = options || {};
    if( Object.prototype.toString.call( url ) === '[object Array]' ) {
        _url = url.join('|');
    }
	cordova.exec(options.successCallback || null, options.errorCallback || null, "StreamingPlayer", "play", [_url, options]);
};

StreamingPlayer.prototype.pause = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "pause", []);
};

StreamingPlayer.prototype.close = function(win, fail) {
    cordova.exec(win, fail, "StreamingPlayer", "close", []);
};

StreamingPlayer.prototype.onPlay = function(callback) {
    this.addListener("streamingplayer:play", callback, false);
};

StreamingPlayer.prototype.onPause = function(callback) {
    this.addListener("streamingplayer:pause", callback, false);
};

StreamingPlayer.prototype.onClose = function(callback) {
    this.addListener("streamingplayer:close", callback, false);
};

StreamingPlayer.prototype.onTrackStatusChange = function(callback) {
    this.addListener("streamingplayer:trackStatusChange", callback, false);
};

StreamingPlayer.prototype.onTrackStart = function(callback) {
    this.addListener("streamingplayer:trackStart", callback, false);
};

StreamingPlayer.prototype.onTrackEnd = function(callback) {
    this.addListener("streamingplayer:trackEnd", callback, false);
};

StreamingPlayer.prototype.onTrackChange = function(callback) {
    this.addListener("streamingplayer:trackChange", callback, false);
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

StreamingPlayer.prototype.clearListeners = function() {
    [
        "streamingplayer:play",
        "streamingplayer:pause",
        "streamingplayer:close",
        "streamingplayer:trackStatusChange",
        "streamingplayer:trackStart",
        "streamingplayer:trackEnd",
        "streamingplayer:trackChange",
    ].forEach(function(v){
        this.removeListeners(v);
    });
};

StreamingPlayer.install = function () {
	if (!window.plugins) {
		window.plugins = {};
	}
	window.plugins.StreamingPlayer = new StreamingPlayer();
	return window.plugins.StreamingPlayer;
};

cordova.addConstructor(StreamingPlayer.install);

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
