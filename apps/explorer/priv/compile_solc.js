#!/usr/bin/env node
var sourceCodePath = process.argv[2];
var optimize = process.argv[3];
var optimizationRuns = parseInt(process.argv[4], 10);
var newContractName = process.argv[5];

const child_process = require("child_process");

// var externalLibraries = JSON.parse(process.argv[6])

var fs = require('fs');
var sourceCode = fs.readFileSync(sourceCodePath, 'utf8');

var settings = {
    optimizer: {
      enabled: optimize == '1',
      runs: optimizationRuns
    },
    outputSelection: {
      '*': {
          '*': ['*']
      }
    }
}

const input = {
  language: 'Solidity',
  sources: {
    [newContractName]: {
      content: sourceCode
    }
  },
  settings: settings
}

// TODO: investigate why stringifying the input inline in the command doesnt work
fs.writeFileSync("compile.tmp", JSON.stringify(input))

var execSync = require("child_process").execSync;
var execString = `zksolc --standard-json --optimize < compile.tmp`
var result = execSync(execString);

fs.unlinkSync("compile.tmp")

const output = JSON.parse(result.toString("utf8"))
console.log(JSON.stringify(output));
