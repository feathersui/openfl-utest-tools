# Command line tools for utest and OpenFL

Runs [utest](https://lib.haxe.org/p/utest) tests associated with an [OpenFL](https://openfl.org/) project. Detects classes that extend `utest.Test` and automatically generates a runner for them.

## Installation

This library is not yet available on Haxelib, so you'll need to install it and its dependencies from Github.

```sh
haxelib git openfl-utest-tools https://github.com/feathersui/openfl-utest-tools.git
```

## Usage

Create a directory named _tests_ in the same parent directory as your OpenFL _project.xml_ file. This will be the class path for your tests.

Run the following command in a terminal.

```sh
haxelib run openfl-utest-tools test neko
```

The command above runs the tests using the `neko` target. Other OpenFL targets are supported, including `html5`, `windows`, `mac`, `linux`, and `hl`.

When running tests on the `html5` target, [Node.js](https://nodejs.org/) is required. The [Playwright](https://www.npmjs.com/package/playwright) npm module is used to run tests in Chromium, Firefox, and WebKit.

### Commands

- `test` builds and runs tests. The `test` command has a few optional parameters.
	- `--source` sets a custom source path for the tests. Default: _tests_
	- `--project` sets a custom path to the OpenFL project file. Default: _project.xml_
	- `--include` sets a custom glob pattern for test files to include. Default: _**/*.hx_
	- `--exclude` sets an optional glob pattern for test files to exclude.
	- `--verbose` displays more detailed output.
- `help` displays help about the available commands.
