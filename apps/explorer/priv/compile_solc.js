#!/usr/bin/env node

const solc = require('solc-js');

var sourceCode = process.argv[2];
var version = process.argv[3];
var optimize = process.argv[4];

var compiled_code = solc.loadRemoteVersion(version, function (err, solcSnapshot) {
  if (err) {
    console.log(JSON.stringify(err));
  } else {
    console.log(JSON.stringify(solcSnapshot.compile(sourceCode, optimize)));
  }
});
