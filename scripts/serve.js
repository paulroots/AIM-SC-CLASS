#!/usr/bin/env node
// Serves the web/ folder on http://localhost:3000 with no dependencies.
// MetaMask only injects into pages served over http(s), never file://, so this is required.

const http = require("http");
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..", "web");
const port = Number(process.env.PORT || 3000);

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

http
  .createServer((req, res) => {
    let urlPath = decodeURIComponent(req.url.split("?")[0]);
    if (urlPath.endsWith("/")) urlPath += "index.html";
    const file = path.normalize(path.join(root, urlPath));
    if (!file.startsWith(root)) {
      res.writeHead(403).end("Forbidden");
      return;
    }
    fs.readFile(file, (err, data) => {
      if (err) {
        res.writeHead(404, { "Content-Type": "text/plain" }).end("Not found: " + urlPath);
        return;
      }
      res.writeHead(200, {
        "Content-Type": types[path.extname(file)] || "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
      });
      res.end(data);
    });
  })
  .listen(port, () => {
    console.log(`Smart Contracts Lab dApps: http://localhost:${port}/`);
    console.log("Press Ctrl+C to stop.");
  });
