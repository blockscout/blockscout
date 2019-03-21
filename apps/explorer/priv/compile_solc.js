#!/usr/bin/env node

const solc = require('solc');

var sourceCode = process.argv[2];
var version = process.argv[3];
var optimize = process.argv[4];
var newContractName = process.argv[5];
var externalLibraries = JSON.parse(process.argv[6])
var evmVersion = process.argv[7]

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
          runs: 200
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
