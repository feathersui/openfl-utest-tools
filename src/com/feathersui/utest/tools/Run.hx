/*
	openfl-utest-tools
	Copyright 2022 Bowler Hat LLC. All Rights Reserved.

	This program is free software. You can redistribute and/or modify it in
	accordance with the terms of the accompanying license agreement.
 */

package com.feathersui.utest.tools;

import haxe.io.Eof;
import sys.io.Process;
import sys.FileSystem;
import hxargs.Args;
import sys.io.File;
import haxe.io.Path;
import haxe.Template;
import com.feathersui.utest.tools.utils.GlobPatterns;

class Run {
	private static final IMPORT_PATTERN = new EReg("\\bimport\\s+utest\\.Test\\s*;", "");
	private static final EXTENDS_PATTERN_WITH_IMPORT = new EReg("\\bclass\\s+\\w+\\s+extends\\s+(?:utest\\.)?Test\\b", "");
	private static final EXTENDS_PATTERN_WITHOUT_IMPORT = new EReg("\\bclass\\s+\\w+\\s+extends\\s+utest\\.Test\\b", "");

	private static var _templatesPath:String;
	private static var _targetPath:String;
	private static var _targetSrcPath:String;
	private static var _limeTargetPlatform:String;
	private static var _testOptions:TestOptions;

	public static function main():Void {
		// generate this path before calling Sys.setCwd()
		_templatesPath = Path.join([Path.directory(Sys.programPath()), "..", "..", "..", "..", "..", "templates"]);

		var args = Sys.args();
		var cwd = args.pop();
		Sys.setCwd(cwd);

		var getDoc:() -> String = null;
		var mainArgHandler = Args.generate([
			@doc("Builds and runs utest tests associated with an OpenFL project")
			["test"] => function() {
				if (args.length == 0) {
					Sys.stderr().writeString("Error: Missing target\n", UTF8);
					var helpArgHandler = createHelpArgHandler();
					helpArgHandler.parse(["test"]);
					Sys.exit(1);
				}
				_limeTargetPlatform = args.shift();
				_testOptions = new TestOptions();
				var testArgHandler = createTestArgHandler(_testOptions);
				testArgHandler.parse(args);
				// populate defaults
				if (_testOptions.project == null) {
					var fallbackProjectPath = Path.join([Sys.getCwd(), "project.xml"]);
					_testOptions.project = fallbackProjectPath;
				}
				if (_testOptions.source == null) {
					var fallbackSourcePath = Path.join([Sys.getCwd(), "tests"]);
					if (FileSystem.exists(fallbackSourcePath)) {
						_testOptions.source = fallbackSourcePath;
					}
				}
				if (_testOptions.include == null) {
					_testOptions.include = GlobPatterns.toEReg("**/*.hx");
				}
				// validate paths
				if (!FileSystem.exists(_testOptions.project)) {
					Sys.stderr().writeString('OpenFL project file not found: ${_testOptions.project}\n', UTF8);
					Sys.exit(1);
				}
				if (_testOptions.source == null) {
					Sys.stderr().writeString('No tests found. Create a \'tests\' directory, or specify the --source option with a custom directory\n', UTF8);
					Sys.exit(1);
				}
				if (!FileSystem.exists(_testOptions.source)) {
					Sys.stderr().writeString('Tests source directory not found: ${_testOptions.source}\n', UTF8);
					Sys.exit(1);
				}
				readProjectFile();
				generateTestSources();
				buildTests();
				runTests();
			},
			@doc("Displays a list of available commands or the usage of a specific command")
			["help"] => function() {
				if (args.length > 0) {
					var helpArgHandler = createHelpArgHandler();
					helpArgHandler.parse(args);
				} else {
					Sys.println("Usage: haxelib run openfl-utest-tools <command> [options]");
					Sys.println("Commands:");
					Sys.println(getDoc());
				}
			},
			_ => function(command:String) {
				Sys.stderr().writeString('Unknown command: ${command}\n', UTF8);
				Sys.exit(1);
			}
		]);
		getDoc = mainArgHandler.getDoc;

		if (args.length == 0) {
			mainArgHandler.parse(["help"]);
			return;
		}
		mainArgHandler.parse(args.splice(0, 1));
	}

	private static function createHelpArgHandler() {
		return Args.generate([
			["test"] => function() {
				Sys.println("Usage: haxelib run openfl-utest-tools test");
			},
			["help"] => function() {
				Sys.println("Usage: haxelib run openfl-utest-tools help <command>");
			},
			_ => function(command:String) {
				Sys.println('Unknown command: ${command}');
				Sys.exit(1);
			}
		]);
	}

	private static function createTestArgHandler(?options:TestOptions) {
		return Args.generate([
			@doc("The path to the OpenFL project.xml file, if not contained in the current working directory")
			["--project"] => function(value:String) {
				if (!Path.isAbsolute(value)) {
					value = Path.join([Sys.getCwd(), value]);
				}
				options.project = value;
			},
			@doc("The source directory containing tests")
			["--source"] => function(value:String) {
				if (!Path.isAbsolute(value)) {
					value = Path.join([Sys.getCwd(), value]);
				}
				options.source = value;
			},
			@doc("The glob pattern for the test files to include. Default **/*.hx")
			["--include"] => function(value:String) {
				options.include = GlobPatterns.toEReg(value);
			},
			@doc("The optional glob pattern for the test files to exclude.")
			["--exclude"] => function(value:String) {
				options.exclude = GlobPatterns.toEReg(value);
			},
			@doc("Show additional detailed output")
			["--verbose"] => function() {
				options.verbose = true;
			},
			_ => function(option:String) {
				Sys.stderr().writeString('Unknown option: ${option}\n', UTF8);
				Sys.exit(1);
			}
		]);
	}

	private static function readProjectFile():Void {
		var projectPath = _testOptions.project;
		if (!Path.isAbsolute(projectPath)) {
			projectPath = Path.join([Sys.getCwd(), projectPath]);
		}
		var projectFileContent:String = null;
		try {
			projectFileContent = File.getContent(projectPath);
		} catch (e:Dynamic) {
			Sys.println('Failed to read project file: ${projectPath}');
			Sys.exit(1);
		}
		_targetPath = Path.join([Sys.getCwd(), "bin", "openfl-utest-tools"]);
		_targetSrcPath = Path.join([_targetPath, "src"]);
	}

	private static function generateTestSources():Void {
		if (_testOptions.verbose) {
			Sys.println("Generating Tests Entry Point...");
		}
		var qualifiedNames = findTestQualifiedNames();
		if (qualifiedNames.length == 0) {
			Sys.println("No tests found");
			Sys.exit(1);
		}

		var testsMainTemplatePath = Path.join([_templatesPath, "TestsMain.hx"]);
		var testsMainTemplateContent:String = null;
		try {
			testsMainTemplateContent = File.getContent(testsMainTemplatePath);
		} catch (e:Dynamic) {
			Sys.println('Failed to read template file: ${testsMainTemplatePath}');
			Sys.exit(1);
		}

		var template = new Template(testsMainTemplateContent);
		var testsMainOutputContent = template.execute({
			qualifiedNames: qualifiedNames
		});
		FileSystem.createDirectory(_targetSrcPath);
		var testsMainOutputPath = Path.join([_targetSrcPath, "TestsMain.hx"]);
		var fileOutput = File.write(testsMainOutputPath, false);
		fileOutput.writeString(testsMainOutputContent, UTF8);
		fileOutput.close();
	}

	private static function buildTests():Void {
		if (_testOptions.verbose) {
			Sys.println("Building Tests...");
			Sys.println('Test Sources: ${_targetSrcPath}');
			Sys.println('Test Output: ${_targetPath}');
		}
		var stdoutDone = false;
		var stderrDone = false;
		var process = new Process("haxelib", [
			"run",
			"openfl",
			"build",
			_testOptions.project,
			_limeTargetPlatform,
			'--source=${_testOptions.source}',
			'--source=${_targetSrcPath}',
			'--app-path=${_targetPath}',
			"--app-file=TestsMain",
			"--app-main=TestsMain",
			'--haxelib=utest'
		]);

		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stdout.readLine();
					Sys.stdout().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stdoutDone = true;
		});
		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stderr.readLine();
					Sys.stderr().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stderrDone = true;
		});

		while (!stdoutDone || !stderrDone) {
			Sys.sleep(1);
		}
		var exitCode = process.exitCode(true);
		if (exitCode != 0) {
			Sys.stderr().writeString('Tests build failed. Process exited with code: ${exitCode}\n', UTF8);
			Sys.exit(exitCode);
		}

		if (_limeTargetPlatform == "html5") {
			var htmlTemplatePath = Path.join([_templatesPath, "index.html"]);
			var htmlOutputPath = Path.join([_targetPath, "html5", "bin", "index.html"]);
			File.copy(htmlTemplatePath, htmlOutputPath);
		}
	}

	private static function runTests():Void {
		if (_testOptions.verbose) {
			Sys.println("Running Tests...");
		}
		if (_limeTargetPlatform == "html5") {
			installPlaywright();
			runTestsHtml5();
		} else {
			runTestsNonHtml5();
		}
	}

	private static function installPlaywright():Void {
		var stdoutDone = false;
		var stderrDone = false;
		Sys.setCwd(_templatesPath);
		var process = new Process("npx", ["playwright", "install"]);

		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stdout.readLine();
					Sys.stdout().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stdoutDone = true;
		});
		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stderr.readLine();
					Sys.stderr().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stderrDone = true;
		});

		while (!stdoutDone || !stderrDone) {
			Sys.sleep(1);
		}
		var exitCode = process.exitCode(true);

		if (exitCode != 0) {
			Sys.stderr().writeString('Playwright initialization failed. Process exited with code: ${exitCode}\n', UTF8);
			Sys.exit(exitCode);
		}
	}

	private static function runTestsHtml5():Void {
		var stdoutDone = false;
		var stderrDone = false;
		Sys.setCwd(_targetPath);
		var process = new Process("node", [Path.join([_templatesPath, "playwright-runner.js"])]);

		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stdout.readLine();
					Sys.stdout().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stdoutDone = true;
		});
		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stderr.readLine();
					Sys.stderr().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stderrDone = true;
		});

		while (!stdoutDone || !stderrDone) {
			Sys.sleep(1);
		}
		var exitCode = process.exitCode(true);
		Sys.exit(exitCode);
	}

	private static function runTestsNonHtml5():Void {
		var stdoutDone = false;
		var stderrDone = false;
		var process = new Process("haxelib", [
			"run",
			"openfl",
			"run",
			_testOptions.project,
			_limeTargetPlatform,
			'--app-path=${_targetPath}',
			"--app-file=TestsMain"
		]);

		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stdout.readLine();
					Sys.stdout().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stdoutDone = true;
		});
		sys.thread.Thread.create(() -> {
			while (true) {
				try {
					var line = process.stderr.readLine();
					Sys.stderr().writeString('${line}\n', UTF8);
				} catch (e:Eof) {
					break;
				}
			}
			stderrDone = true;
		});

		while (!stdoutDone || !stderrDone) {
			Sys.sleep(1);
		}
		var exitCode = process.exitCode(true);
		Sys.exit(exitCode);
	}

	private static function findTestQualifiedNames():Array<String> {
		var qualifiedNames:Array<String> = [];
		findTestQualifiedNamesInternal(_testOptions.source, "", qualifiedNames);
		return qualifiedNames;
	}

	private static function findTestQualifiedNamesInternal(path:String, currentPackage:String, result:Array<String>):Void {
		var files = FileSystem.readDirectory(path);
		for (file in files) {
			var filePath = Path.join([path, file]);
			if (FileSystem.isDirectory(filePath)) {
				var nextPackage = currentPackage;
				if (currentPackage.length == 0) {
					nextPackage = file;
				} else {
					nextPackage += "." + file;
				}
				findTestQualifiedNamesInternal(filePath, nextPackage, result);
				continue;
			}
			if (Path.extension(filePath) != "hx") {
				continue;
			}
			if (_testOptions.include == null || !_testOptions.include.match(filePath)) {
				continue;
			}
			if (_testOptions.exclude != null && _testOptions.exclude.match(filePath)) {
				continue;
			}
			var hxFileContent:String = null;
			try {
				hxFileContent = File.getContent(filePath);
			} catch (e:Dynamic) {
				// skip it
				continue;
			}

			var hasImport = IMPORT_PATTERN.match(hxFileContent);
			var hasExtends = false;
			if (hasImport) {
				hasExtends = EXTENDS_PATTERN_WITH_IMPORT.match(hxFileContent);
				if (!hasExtends) {
					hasExtends = EXTENDS_PATTERN_WITHOUT_IMPORT.match(hxFileContent);
				}
			} else {
				hasExtends = EXTENDS_PATTERN_WITHOUT_IMPORT.match(hxFileContent);
			}

			if (!hasExtends) {
				continue;
			}

			var qualifiedName = Path.withoutExtension(file);
			if (currentPackage.length > 0) {
				qualifiedName = currentPackage + "." + qualifiedName;
			}
			result.push(qualifiedName);
		}
	}
}

class TestOptions {
	public function new() {}

	public var project:String;
	public var source:String;
	public var verbose:Bool;
	public var include:EReg;
	public var exclude:EReg;
}
