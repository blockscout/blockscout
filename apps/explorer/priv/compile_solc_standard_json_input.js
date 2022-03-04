#!/usr/bin/env node

var inputJSONFilePath = process.argv[2];
// var compilerVersionPath = process.argv[3];
const child_process = require("child_process");


var fs = require('fs');
var input = fs.readFileSync(inputJSONFilePath, 'utf8');

var execSync = require("child_process").execSync;
var execString = `zksolc --standard-json --optimize < ${inputJSONFilePath}`
var result = execSync(execString);

const output = JSON.parse(result.toString("utf8"))
console.log(JSON.stringify(output));
