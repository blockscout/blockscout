import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createMarketHistoryChart } from './lib/history_chart'

(function () {
  const dashboardChartElement = document.querySelectorAll('[data-chart="historyChart"]')[0]
  if (dashboardChartElement) {
    // @ts-ignore
    window.dashboardChart = createMarketHistoryChart(dashboardChartElement)
  }
  formatAllUsdValues()
  updateAllCalculatedUsdValues()
})()
