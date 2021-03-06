//
// Flambe - Rapid game development
// https://github.com/aduros/flambe/blob/master/LICENSE.txt

package flambe.script;

import flambe.animation.AnimatedFloat;
import flambe.animation.Easing;
import flambe.animation.Tween;
import flambe.Entity;

/**
 * An action that tweens an AnimatedFloat to a certain value.
 */
class AnimateTo
    implements Action
{
    public function new (value :AnimatedFloat, to :Float, seconds :Float, easing :EasingFunction)
    {
        _value = value;
        _to = to;
        _seconds = seconds;
        _easing = easing;
    }

    public function update (dt :Float, actor :Entity) :Bool
    {
        if (_tween == null) {
            _tween = new Tween(_value._, _to, _seconds, _easing);
            _value.behavior = _tween;
            _value.update(dt); // Fake an update to account for this frame
        }
        if (_value.behavior != _tween) {
            _tween = null;
            return true;
        }
        return false;
    }

    private var _tween :Tween;

    private var _value :AnimatedFloat;
    private var _to :Float;
    private var _seconds :Float;
    private var _easing :EasingFunction;
}
