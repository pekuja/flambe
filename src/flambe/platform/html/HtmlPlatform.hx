//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.platform.html;

import js.Lib;

import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.Stage;
import flambe.display.Texture;
import flambe.Entity;
import flambe.input.Keyboard;
import flambe.input.KeyEvent;
import flambe.input.Pointer;
import flambe.input.PointerEvent;
import flambe.platform.Platform;
import flambe.platform.BasicKeyboard;
import flambe.platform.BasicPointer;
import flambe.platform.MainLoop;
import flambe.storage.Storage;
import flambe.System;
import flambe.util.Logger;
import flambe.util.Promise;
import flambe.util.Signal1;

class HtmlPlatform
    implements Platform
{
    private static var log :Logger; // This needs to be initialized later

    public var stage (getStage, null) :Stage;
    public var storage (getStorage, null) :Storage;
    public var pointer (getPointer, null) :Pointer;
    public var keyboard (getKeyboard, null) :Keyboard;
    public var locale (getLocale, null) :String;

    public var mainLoop (default, null) :MainLoop;
    public var renderer :Renderer;

    public static var instance /*(default, null)*/ = new HtmlPlatform();

    private function new ()
    {
    }

    public function init ()
    {
        log = Log.log;
        log.info("Initializing HTML platform");

#if debug
        haxe.Firebug.redirectTraces();
#end

        var canvas :Dynamic = null;
        try {
            // Use the canvas assigned to us by the flambe.js embedder
            canvas = (untyped Lib.window).flambe.canvas;
        } catch (error :Dynamic) {
        }
        if (canvas == null) {
            log.error("Could not find a Flambe canvas! Are you not embedding with flambe.js?");
            return;
        }

        // Allow the canvas to trap keyboard focus
        canvas.setAttribute("tabindex", "0");
        // ...but hide the focus rectangle
        canvas.style.outlineStyle = "none";

        // Browser optimization hints
        canvas.setAttribute("moz-opaque", "true");
        // canvas.style.webkitTransform = "translateZ(0)";
        // canvas.style.backgroundColor = "#000";

        _stage = new HtmlStage(canvas);
        _pointer = new BasicPointer();
        _keyboard = new BasicKeyboard();

        renderer = new CanvasRenderer(canvas);
        mainLoop = new MainLoop();

        var container = canvas.parentNode;
        container.style.overflow = "hidden";

        var onMouse = function (event) {
            var bounds = event.target.getBoundingClientRect();
            var x = getX(event, bounds);
            var y = getY(event, bounds);

            switch (event.type) {
            case "mousedown":
                event.preventDefault();
                _pointer.submitDown(x, y);
                event.target.focus();

            case "mousemove":
                _pointer.submitMove(x, y);

            case "mouseup":
                _pointer.submitUp(x, y);
            }
        };
        canvas.addEventListener("mousedown", onMouse, false);
        canvas.addEventListener("mousemove", onMouse, false);
        canvas.addEventListener("mouseup", onMouse, false);

        var pointerTouchId = -1;
        var onTouch = function (event) {
            var type = event.type;
            var changedTouches :Array<Dynamic> = event.changedTouches;

            var pointerTouch = null;
            if (type == "touchstart") {
                if (pointerTouchId == -1) {
                    pointerTouch = event.changedTouches[0];
                }
            } else {
                for (touch in changedTouches) {
                    if (touch.identifier == pointerTouchId) {
                        pointerTouch = touch;
                        break;
                    }
                }
            }

            if (pointerTouch != null) {
                var bounds = event.target.getBoundingClientRect();
                var x = getX(pointerTouch, bounds);
                var y = getY(pointerTouch, bounds);

                switch (type) {
                case "touchstart":
                    event.preventDefault();
                    if (HtmlUtil.SHOULD_HIDE_MOBILE_BROWSER) {
                        HtmlUtil.hideMobileBrowser();
                    }
                    pointerTouchId = pointerTouch.identifier;
                    _pointer.submitDown(x, y);

                case "touchmove":
                    event.preventDefault();
                    _pointer.submitMove(x, y);

                case "touchend", "touchcancel":
                    pointerTouchId = -1;
                    _pointer.submitUp(x, y);
                }
            }
        };
        canvas.addEventListener("touchstart", onTouch, false);
        canvas.addEventListener("touchmove", onTouch, false);
        canvas.addEventListener("touchend", onTouch, false);
        canvas.addEventListener("touchcancel", onTouch, false);

        var onKey = function (event) {
            var charCode = event.keyCode;
            switch (event.type) {
            case "keydown":
                event.preventDefault();
                _keyboard.submitDown(charCode);
            case "keyup":
                _keyboard.submitUp(charCode);
            }
        };
        canvas.addEventListener("keydown", onKey, false);
        canvas.addEventListener("keyup", onKey, false);

        // Handle uncaught errors
        var oldErrorHandler = (untyped Lib.window).onerror;
        (untyped Lib.window).onerror = function (message, url, line) {
            System.uncaughtError.emit(message);
            return (oldErrorHandler != null) ? oldErrorHandler(message, url, line) : false;
        };

        // Handle visibility changes if the browser supports them
        // http://www.w3.org/TR/page-visibility/
        var hiddenApi = HtmlUtil.loadExtension("hidden", Lib.document);
        if (hiddenApi.value != null) {
            var onVisibilityChanged = function () {
                System.hidden._ = Reflect.field(Lib.document, hiddenApi.field);
            };
            onVisibilityChanged(); // Update now
            (untyped Lib.document).addEventListener(hiddenApi.prefix + "visibilitychange",
                onVisibilityChanged, false);
        }

        _lastUpdate = Date.now().getTime();

        // Use requestAnimationFrame if available, otherwise a 60 FPS setInterval
        // https://developer.mozilla.org/en/DOM/window.mozRequestAnimationFrame
        var requestAnimationFrame = HtmlUtil.loadExtension("requestAnimationFrame").value;
        if (requestAnimationFrame != null) {
            // Use the high resolution, monotonic timer if available
            // http://www.w3.org/TR/hr-time/
            var performance :{ now :Void -> Float } = untyped Lib.window.performance;
            var hasPerfNow = (performance != null) && HtmlUtil.polyfill("now", performance);

            if (hasPerfNow) {
                // performance.now is relative to navigationStart, rather than a timestamp
                _lastUpdate = performance.now();
            } else {
                log.warn("No monotonic timer support, falling back to the system date");
            }

            var updateFrame = null;
            updateFrame = function (now :Float) {
                update(hasPerfNow ? performance.now() : now);
                requestAnimationFrame(updateFrame, canvas);
            };
            requestAnimationFrame(updateFrame, canvas);

        } else {
            log.warn("No requestAnimationFrame support, falling back to setInterval");
            (untyped Lib.window).setInterval(function () {
                update(Date.now().getTime());
            }, 1000/60);
        }
    }

    public function loadAssetPack (manifest :Manifest) :Promise<AssetPack>
    {
        return new HtmlAssetPackLoader(manifest).promise;
    }

    public function getStage () :Stage
    {
        return _stage;
    }

    public function getStorage () :Storage
    {
        if (_storage == null) {
            var localStorage = null;
            try {
                localStorage = (untyped Lib.window).localStorage;
            } catch (error :Dynamic) {
                // Browsers may throw an error on accessing localStorage:
                // http://dev.w3.org/html5/webstorage/#dom-localstorage
            }
            if (localStorage != null) {
                _storage = new HtmlStorage(localStorage);
            } else {
                log.warn("localStorage is unavailable, falling back to unpersisted storage");
                _storage = new DummyStorage();
            }
        }
        return _storage;
    }

    public function getLocale () :String
    {
        return untyped Lib.window.navigator.language;
    }

    public function callNative (funcName :String, params :Array<Dynamic>) :Dynamic
    {
        if (params == null) {
            params = [];
        }
        var func = Reflect.field(Lib.window, funcName);
        try {
            return Reflect.callMethod(null, func, params);
        } catch (e :Dynamic) {
            log.warn("Error calling native method", ["error", e]);
            return null;
        }
    }

    public function createLogHandler (tag :String) :LogHandler
    {
#if !flambe_disable_logging
        if (HtmlLogHandler.isSupported()) {
            return new HtmlLogHandler(tag);
        }
#end
        return null;
    }

    private function update (now :Float)
    {
        var dt = (now - _lastUpdate)/1000;
        _lastUpdate = now;

        mainLoop.update(dt);
        mainLoop.render(renderer);
    }

    public function getPointer () :Pointer
    {
        return _pointer;
    }

    public function getKeyboard () :Keyboard
    {
        return _keyboard;
    }

    private function getX (event :Dynamic, bounds :Dynamic) :Float
    {
        return _stage.devicePixelRatio*(event.clientX - bounds.left);
    }

    private function getY (event :Dynamic, bounds :Dynamic) :Float
    {
        return _stage.devicePixelRatio*(event.clientY - bounds.top);
    }

    private static var _instance :HtmlPlatform;

    private var _stage :HtmlStage;
    private var _pointer :BasicPointer;
    private var _keyboard :BasicKeyboard;
    private var _storage :Storage;

    private var _lastUpdate :Float;
}
