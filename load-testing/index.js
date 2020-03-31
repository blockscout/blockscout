const fs = require('fs')
const path = require('path')
const LoadTesting = require('easygraphql-load-tester')
const { fileLoader } = require('merge-graphql-schemas')

const schema = fs.readFileSync(path.join(__dirname, 'schema.gql'), 'utf8')
const queries = fileLoader(path.join(__dirname, './graphql', '**/*.graphql'))

const args = {
  SEARCH_BLOCK: [
  {number: 1},
  {number: 822563},
  ]
}

const easyGraphQLLoadTester = new LoadTesting(schema, args)

const testCases = easyGraphQLLoadTester.artillery({
  customQueries: queries,
  onlyCustomQueries: true,
  queryFile: true,
  selectedQueries: ['SEARCH_BLOCK', 'LATEST_BLOCK'],
  withMutations: true,
})

module.exports = { testCases }