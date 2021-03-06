//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.platform;

import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.Stage;
import flambe.display.Texture;
import flambe.Entity;
import flambe.input.Keyboard;
import flambe.input.Pointer;
import flambe.storage.Storage;
import flambe.util.Logger;
import flambe.util.Promise;

interface Platform
{
    var stage (getStage, null) :Stage;

    var storage (getStorage, null) :Storage;

    var pointer (getPointer, null) :Pointer;

    var keyboard (getKeyboard, null) :Keyboard;

    var locale (getLocale, null) :String;

    function loadAssetPack (manifest :Manifest) :Promise<AssetPack>;

    function callNative (funcName :String, params :Array<Dynamic>) :Dynamic;

    function createLogHandler (tag :String) :LogHandler;

    function init () :Void;
}
