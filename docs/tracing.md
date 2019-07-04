<!--tracing.md -->

## Tracing

Blockscout supports tracing via [Spandex](http://git@github.com:spandex-project/spandex.git). Each application has its own internally configured tracer. 

To enable tracing, visit each application's `config/<env>.ex` and change `disabled?: true` to `disabled?: false`. Do this for
each application you'd like included in your trace data.

Currently, only [Datadog](https://www.datadoghq.com/) is supported as a
tracing backend, but more will be added soon.

### DataDog

If you would like to use DataDog, after enabling `Spandex`, set
`"DATADOG_HOST"` and `"DATADOG_PORT"` environment variables to the
host/port that your Datadog agent is running on. For more information on
Datadog and the Datadog agent, see the [documentation](https://docs.datadoghq.com/).

### Other

If you want to use a different backend, remove the
`SpandexDatadog.ApiServer` `Supervisor.child_spec` from
`Explorer.Application` and follow any instructions provided in `Spandex`
for setting up that backend.