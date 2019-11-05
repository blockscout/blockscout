# Database useful information

Here you can find some commands and SQL sentences that could help to deal with the Blockscout database.

## Ecto database creation and migration

```bash
# Drop the database
mix ecto.drop

# Create the database
mix ecto.create

# Rolling back a migration
mix ecto.rollback

# Execute Migration
mix do ecto.migrate
```

If you need to create a new table or define a migration you can find the migration scripts in the `apps/explorer/priv/repo/migrations` directory.

## Registering Smart Contracts source code

To visualize the Smart Contracts source code and ABI is necessary to register and verify with the information existing on-chain.
If after doing that, the contract is a proxy in front of a implementation address, it's possible to register that mapping
in the database, allowing to retrieve the original source code in the web interface and the RPC api.

### Adding Mapping between Proxy Contract and Implementation Address

```sql
INSERT INTO proxy_contract (proxy_address, implementation_address)
  VALUES (decode('ccd85464e7c5748df2fab15ee580626f93841e3b', 'hex'), decode('d244bd4d25180e5966807b4c8b1aa551985e1a2d', 'hex'))

select * FROM proxy_contract WHERE proxy_address = decode('ccd85464e7c5748df2fab15ee580626f93841e3b', 'hex');
```
