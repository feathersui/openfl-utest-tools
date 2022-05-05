import haxe.Timer;
import openfl.Lib;
import openfl.display.Sprite;
import utest.Assert;
import utest.Async;
import utest.Test;

class SampleTestCase extends Test {
	private var _sprite:Sprite;

	/**
		The `setup()` method is called immediately before every test method.
	**/
	public function setup():Void {
		_sprite = new Sprite();
		Lib.current.addChild(_sprite);
	}

	/**
		The `teardown()` method is called immediately after every test method.
	**/
	public function teardown():Void {
		Lib.current.removeChild(_sprite);
		this._sprite = null;
	}

	/**
		Start the name of each test method with "test".
	**/
	public function testSample():Void {
		// Each test must include one or more assertions
		Assert.notNull(_sprite);
	}

	/**
		Asynchronous test methods should accept one `Async` argument. Call
		`async.done()` when all assertions are complete.
	**/
	@:timeout(1000)
	public function testSampleAsync(async:Async):Void {
		Timer.delay(() -> {
			Assert.notNull(_sprite);
			async.done();
		}, 250);
	}
}
