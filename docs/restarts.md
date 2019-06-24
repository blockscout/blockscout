<!--restarts.md -->

## Automating Restarts

By default `BlockScout` does not restart if it crashes. To enable automated restarts, set the [environment variable](env-variables.md) `HEART_COMMAND` to whatever command you run to start `BlockScout`. Configure the heart beat timeout to change how long it waits before considering the application unresponsive. 

At that point, it will kill the current blockscout instance and execute the `HEART_COMMAND`. By default a crash dump is not written unless you set `ERL_CRASH_DUMP_SECONDS` to a positive or negative integer. See the [heart](http://erlang.org/doc/man/heart.html) documentation for more information.
