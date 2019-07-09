<!-- manual-deployment.md -->

## Manual Deployment

Below is the procedure for manual deployment of BlockScout. For automated deployment, see [ansible deployment](ansible-deployment.md). 

1. `git clone https://github.com/poanetwork/blockscout`

2. `cd blockscout`

3. Setup default configurations:  
    `cp apps/explorer/config/dev.secret.exs.example apps/explorer/config/dev.secret.exs`

   `cp apps/block_scout_web/config/dev.secret.exs.example apps/block_scout_web/config/dev.secret.exs`

4. Update `apps/explorer/config/dev.secret.exs`
    
   **Linux:** Update the database username and password configuration
   
   **Mac:** Remove the  `username`  and  `password`  fields
   
   **Optional:** Set up a default configuration for testing.  `cp apps/explorer/config/test.secret.exs.example apps/explorer/config/test.secret.exs`  Example usage: Changing the default Postgres port from localhost:15432 if [Boxen](https://github.com/boxen/boxen) is installed.

5. If you have deployed previously, delete the `apps/block_scout_web/priv/static` folder. This removes static assets from the previous build.

6. Install dependencies. `mix do deps.get, local.rebar --force, deps.compile, compile`

7. If not already running, start postgres: `pg_ctl -D /usr/local/var/postgres start`

8. Create and migrate database `mix do ecto.create, ecto.migrate`

   *Note:*  If you have run previously, drop the previous database
   `mix do ecto.drop, ecto.create, ecto.migrate`

9. Install Node.js dependencies

   - `cd apps/block_scout_web/assets; npm install && node_modules/webpack/bin/webpack.js --mode production; cd -`

   - `cd apps/explorer && npm install; cd -`

10. Enable HTTPS in development. The Phoenix server only runs with HTTPS.

     * `cd apps/block_scout_web`

      * `mix phx.gen.cert blockscout blockscout.local; cd -`
      * Add blockscout and blockscout.local to your  `/etc/hosts`
```

   127.0.0.1       localhost blockscout blockscout.local

   255.255.255.255 broadcasthost

   ::1             localhost blockscout blockscout.local

```

* If using Chrome, Enable  `chrome://flags/#allow-insecure-localhost` .

11.  Set your [environment variables](env-variables.md) as needed.  For example:
```bash
export COIN=DAI
export NETWORK_ICON=_network_icon.html
export ... 
```

12. Return to the root directory and start the Phoenix Server.  `mix phx.server`

## Check your instance:

13. Check that there are no visual artifacts, all assets exist and there are no database errors.

14. If there are no errors, stop BlockScout (`ctrl+c`)

15. Build static assets for deployment `mix phx.digest`

16. Delete build artifacts:
    
    a.  Script: `./rel/commands/clear_build.sh`

    b. Manually:
       -  delete `_build` & `deps` directories
       - delete node modules located at
       - `apps/block_scout_web/assets/node_modules`
       - & `apps/explorer/node_modules`
       - delete `logs/dev` directory