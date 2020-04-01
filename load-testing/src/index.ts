const fs = require('fs')
const path = require('path')
const LoadTesting = require('easygraphql-load-tester')
const { fileLoader } = require('merge-graphql-schemas')
const parse = require('csv-parse/lib/sync')
const loadInputData = require('./utils')

const __rootpath = path.join(__dirname, '/../')
const schema = fs.readFileSync(path.join(__rootpath, 'schema.gql'), 'utf8')
console.log(path.join(__rootpath, '**/*.graphql'))
const queries = fileLoader(path.join(__rootpath, 'queries/*.graphql'))

// Configuration of ADDRESS test case

const addressesSample = fs.readFileSync(path.join(__rootpath, '/input/addresses.csv'),'utf8')
const csvAddresses = parse(addressesSample, {delimiter: ',', columns: false, skip_empty_lines: true})
let inputAddresses = []
csvAddresses.map( (record) => {
    inputAddresses.push({hash: record[0]})
})



// Configuration of SEARCH_BLOCK test case
const MAX_BLOCK_NUMBER = 800000
const NUM_BLOCK_ARGS = 10

let searchBlocks = []
for (let i=0; i<NUM_BLOCK_ARGS; i++)    {
    searchBlocks[i] = {number: Math.floor(Math.random() * MAX_BLOCK_NUMBER) + 1 }
}



/// GraphQL test loader setup

const args = {
    SEARCH_BLOCK: searchBlocks,
    ADDRESS: inputAddresses
}


const easyGraphQLLoadTester = new LoadTesting(schema, args)

//console.log('Queries: ' + queries)

const testCases = easyGraphQLLoadTester.artillery({
  customQueries: queries,
  onlyCustomQueries: true,
  queryFile: true,
//  selectedQueries: ['SEARCH_BLOCK', 'LATEST_BLOCK'],
  withMutations: true,
})

module.exports = { testCases }