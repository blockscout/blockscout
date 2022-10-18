#!/usr/bin/env node

var sourceCodePath = process.argv[2];
var compilerVersionPath = process.argv[3];
var optimize = process.argv[4];
var optimizationRuns = parseInt(process.argv[5], 10);
var newContractName = process.argv[6];
var externalLibraries = JSON.parse(process.argv[7])
var evmVersion = process.argv[8];
var bytecodeHash = process.argv[9];

var solc = require('solc')
var compilerSnapshot = require(compilerVersionPath);
var solc = solc.setupMethods(compilerSnapshot);

var fs = require('fs');
var sourceCode = fs.readFileSync(sourceCodePath, 'utf8');

var settings = {
    optimizer: {
      enabled: optimize == '1',
      runs: optimizationRuns
    },
    libraries: {
      [newContractName]: externalLibraries
    },
    outputSelection: {
      '*': {
        '*': ['*']
      }
    }
}

if (evmVersion !== 'default') {
    settings = Object.assign(settings, {evmVersion: evmVersion})
}

if (bytecodeHash !== 'default') {
  settings = Object.assign(settings, {metadata: {bytecodeHash: bytecodeHash}})
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


const output = JSON.parse(solc.compile(JSON.stringify(input)))
console.log(JSON.stringify(output));
