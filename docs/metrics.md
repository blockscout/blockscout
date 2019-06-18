<!--metrics.md -->

## Metrics

### Wobserver

[Wobserver](https://github.com/shinyscorpion/wobserver) is configured to display data from the `/metrics` endpoint in a web interface. To view, go to `/wobserver` for the chain you would like to view. 

For example `https://blockscout.com/eth/mainnet/wobserver`

### Prometheus

BlockScout is setup to export [Prometheus](https://prometheus.io/) metrics at `/metrics`.

1. Install prometheus: `brew install prometheus`
2. Start the web server `iex -S mix phx.server`
3. Start prometheus: `prometheus --config.file=prometheus.yml`

### Grafana

The Grafana dashboard may also be used for metrics display.

1. Install grafana: `brew install grafana`
2. Install Pie Chart panel plugin: `grafana-cli plugins install grafana-piechart-panel`
3. Start grafana: `brew services start grafana`
4. Add Prometheus as a Data Source
   1. `open http://localhost:3000/datasources`
   2. Click "+ Add data source"
   3. Put "Prometheus" for "Name"
   4. Change "Type" to "Prometheus"
   5. Set "URL" to "http://localhost:9090"
   6. Set "Scrape Interval" to "10s"
5. Add the dashboards from https://github.com/deadtrickster/beam-dashboards:
   For each `*.json` file in the repo.
   1. `open http://localhost:3000/dashboard/import`
   2. Copy the contents of the JSON file in the "Or paste JSON" entry
   3. Click "Load"
6. View the dashboards.  (You will need to click-around and use BlockScout for the web-related metrics to show up.)


