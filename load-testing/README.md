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

Build the tool:

```bash
yarn build
```

Run the load test, environments are defined in [artillery.yml](./artillery.yml).

```bash
yarn load-testing -e mainnet -o reports/mainnet-test-2020-11-01.json
```

Currently, these environments are supported:

- alfajores
- baklava
- mainnet

When the test is over, use the report json file to generate the HTML version and open it:

```bash
yarn report reports/mainnet-test-2020-11-01.json
```
