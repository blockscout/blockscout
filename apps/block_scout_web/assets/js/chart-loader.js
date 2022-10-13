import $ from 'jquery'

import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createMarketHistoryChart } from './lib/history_chart'

(function () {
  const dashboardChartElement = $('[data-chart="historyChart"]')[0]
  if (dashboardChartElement) {
    window.dashboardChart = createMarketHistoryChart(dashboardChartElement)
  }
  formatAllUsdValues()
  updateAllCalculatedUsdValues()
})()
