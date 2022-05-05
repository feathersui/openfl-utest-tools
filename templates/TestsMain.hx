/*
	openfl-utest-tools
	Copyright 2022 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

import openfl.display.Sprite;
import utest.Runner;
import utest.ui.Report;

class TestsMain extends Sprite {
	public function new() {
		super();
		var runner = new Runner();::foreach (qualifiedNames)::
		runner.addCase(new ::__current__::());::end::
		#if html5
		new utest.ui.text.PrintReport(runner);
		var aggregator = new utest.ui.common.ResultAggregator(runner, true);
		aggregator.onComplete.add(function(result:utest.ui.common.PackageResult):Void {
			Reflect.setField(js.Lib.global, "utestResult", result);
		});
		#else
		Report.create(runner);
		#end
		runner.run();
	}
}
