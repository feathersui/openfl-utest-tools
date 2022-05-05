// @ts-check
const { firefox, chromium, webkit } = require("playwright");
const serveHandler = require("serve-handler");
const http = require("http");

// set the current working directory to where index.html is output
process.chdir("html5/bin");

// always using a server is recommended because loading from the file system
// may result in different behavior, including CORS issues.
const server = http.createServer((request, response) => {
	return serveHandler(request, response);
});
server.listen(3000, async () => {
	const browserTypes = [chromium, webkit, firefox];
	for (var browserType of browserTypes) {
		const browser = await browserType.launch();
		const page = await browser.newPage();
		page.on("console", message => console.log(message.text()));
		page.on("pageerror", error => console.error(error));

		await page.goto("http://localhost:3000/");

		await page.evaluate(() => console.log(navigator.userAgent));
		const resultHandle = await page.waitForFunction(() => window["utestResult"]);
		const statsHandle = await resultHandle.getProperty("stats");
		const isOkHandle = await statsHandle.getProperty("isOk");
		const isOk = await isOkHandle.jsonValue();
		if (!isOk) {
			server.close();
			process.exit(1);
		}
	}
	server.close();
	process.exit(0);
});

