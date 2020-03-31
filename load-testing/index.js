const fs = require('fs')
const path = require('path')
const LoadTesting = require('easygraphql-load-tester')
const { fileLoader } = require('merge-graphql-schemas')

const schema = fs.readFileSync(path.join(__dirname, 'schema.gql'), 'utf8')
const queries = fileLoader(path.join(__dirname, '**/*.graphql'))

const args = {
  SEARCH_BLOCK: [
  {number: 1},
  {number: 822563},
  ]
}

//const queries = [
//  'query LATEST_BLOCK {latestBlock}',
//  'query SEARCH_BLOCK($number: Number!) {block(number: $number) { hash, gasUsed, number}}'
//]

const easyGraphQLLoadTester = new LoadTesting(schema, args)

console.log('Queries: ' + queries)

const testCases = easyGraphQLLoadTester.artillery({
  customQueries: queries,
  onlyCustomQueries: true,
  queryFile: true,
//  selectedQueries: ['SEARCH_BLOCK', 'LATEST_BLOCK'],
  withMutations: true,
})

module.exports = { testCases }