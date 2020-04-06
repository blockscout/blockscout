# Blockscout GraphQL Load Testing

## Generating the Schema

```bash
npm install -g get-graphql-schema
get-graphql-schema https://blockscout.net/graphiql > schema.graphql
``` 

## Queries & Input data

You can add new query files in the `graphql` folder. 
Also you can add new input parameters for those queries in the `input` folder.

## Running the tests

```bash
yarn build
yarn load-testing
```

