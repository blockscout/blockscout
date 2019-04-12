#!/usr/bin/env node

const solc = require('solc');

var sourceCode = process.argv[2];
var version = process.argv[3];
var optimize = process.argv[4];
var optimizationRuns = parseInt(process.argv[5], 10);
var newContractName = process.argv[6];
var externalLibraries = JSON.parse(process.argv[7])
var evmVersion = process.argv[8];

var compiled_code = solc.loadRemoteVersion(version, function (err, solcSnapshot) {
  if (err) {
    console.log(JSON.stringify(err));
  } else {
    const input = {
      language: 'Solidity',
      sources: {
        [newContractName]: {
          content: sourceCode
        }
      },
      settings: {
        evmVersion: evmVersion,
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
    }

    const output = JSON.parse(solcSnapshot.compile(JSON.stringify(input)))
    /** Older solc-bin versions don't use filename as contract key */
    const response = output.contracts[newContractName] || output.contracts['']
    console.log(JSON.stringify(response));
  }
});
