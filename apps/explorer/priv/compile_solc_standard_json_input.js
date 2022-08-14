#!/usr/bin/env node

var inputJSONFilePath = process.argv[2];
var compilerVersionPath = process.argv[3];

var solc = require('solc')
var compilerSnapshot = require(compilerVersionPath);
var solc = solc.setupMethods(compilerSnapshot);

var fs = require('fs');
var input = fs.readFileSync(inputJSONFilePath, 'utf8');


const output = JSON.parse(solc.compile(input))
console.log(JSON.stringify(output));
