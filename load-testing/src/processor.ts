import fs = require('fs')
import path = require('path')
import LoadTesting = require('easygraphql-load-tester')
import { fileLoader } from 'merge-graphql-schemas'
import utils = require('./utils')

let cachedCases = {};

function loadTestCases(context, events, done) {
  const environment = context.vars.$environment

  if (!cachedCases[environment]) {
    console.log(`Loading test cases for environment: ${environment}`)

    const __rootpath = path.join(__dirname, '/../')
    const __inputpath = path.join(__rootpath, '/input/', environment)

    const schema = fs.readFileSync(path.join(__rootpath, 'schema.gql'), 'utf8')
    // console.log(path.join(__rootpath, '**/*.graphql'))
    const queries = fileLoader(path.join(__rootpath, 'queries/*.graphql'))


    // Configuration of ADDRESS test case
    const inputAddresses = utils.loadInputData(path.join(__inputpath, 'addresses.csv'))
    const celoAccounts = utils.loadInputData(path.join(__inputpath, 'celo_accounts.csv'))
    const celoValidators = utils.loadInputData(path.join(__inputpath, 'celo_validators.csv'))


    // Configuration of SEARCH_BLOCK test case
    const MAX_BLOCK_NUMBER = 3_350_192
    const NUM_BLOCK_ARGS = 10

    let searchBlocks = []
    for (let i=0; i<NUM_BLOCK_ARGS; i++)    {
        searchBlocks[i] = {number: Math.floor(Math.random() * MAX_BLOCK_NUMBER) + 1 }
    }



    /// GraphQL test loader setup

    const args = {
        SEARCH_BLOCK: searchBlocks,
        ADDRESS: inputAddresses,
        CELO_ACCOUNT: celoAccounts,
        CELO_VALIDATOR: celoValidators,
        TRANSFERS: inputAddresses
    }


    // console.log(schema, args)

    const easyGraphQLLoadTester = new LoadTesting(schema, args)

    //console.log('Queries: ' + queries)

    cachedCases[environment] = easyGraphQLLoadTester.artillery({
      customQueries: queries,
      onlyCustomQueries: true,
      queryFile: true,
      // selectedQueries: ['TRANSFERS'],
      withMutations: true,
    })
  }

  return cachedCases[environment](context, events, done)
}

module.exports = { loadTestCases }
