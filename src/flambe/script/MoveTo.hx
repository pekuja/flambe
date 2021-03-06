//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.script;

import flambe.animation.Easing;
import flambe.animation.Tween;
import flambe.display.Sprite;
import flambe.Entity;

/**
 * An action that translates the owner's sprite to a certain position.
 */
class MoveTo
    implements Action
{
    public function new (
        x :Float, y :Float, seconds :Float, easingX :EasingFunction, ?easingY :EasingFunction)
    {
        _x = x;
        _y = y;
        _seconds = seconds;
        _easingX = easingX;
        _easingY = easingY;
    }

    public function update (dt :Float, actor :Entity) :Bool
    {
        var sprite = actor.get(Sprite);
        if (_tweenX == null) {
            _tweenX = new Tween(sprite.x._, _x, _seconds, _easingX);
            sprite.x.behavior = _tweenX;
            sprite.x.update(dt); // Fake an update to account for this frame

            _tweenY = new Tween(sprite.y._, _y, _seconds,
                (_easingY != null) ? _easingY : _easingX);
            sprite.y.behavior = _tweenY;
            sprite.y.update(dt); // Fake an update to account for this frame
        }
        if (sprite.x.behavior != _tweenX && sprite.y.behavior != _tweenY) {
            _tweenX = null;
            _tweenY = null;
            return true;
        }
        return false;
    }

    private var _tweenX :Tween;
    private var _tweenY :Tween;

    private var _x :Float;
    private var _y :Float;
    private var _seconds :Float;
    private var _easingX :EasingFunction;
    private var _easingY :EasingFunction;
}
