# Blockscout GraphQL Load Testing

## Generating the Schema

```bash
npm install -g get-graphql-schema
get-graphql-schema https://blockscout.net/graphiql > schema.graphql
``` 

## Queries

You can add new query files in the graphql folder. 

## Running the tests

```bash
npm run load-testing
```

