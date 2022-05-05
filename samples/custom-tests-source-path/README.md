# openfl-utest-tools Custom Tests Source Path Sample

This sample project using [openfl-utest-tools](https://github.com/feathersui/openfl-utest-tools) demonstrates how the `--source` option can specify a custom directory for test source files.

In this project, tests are located in _tests/src_ instead of the default _tests_.

## Run tests

Open a terminal in this directory, and run the following command:

```sh
haxelib run openfl-utest-tools test neko --source tests/src
```