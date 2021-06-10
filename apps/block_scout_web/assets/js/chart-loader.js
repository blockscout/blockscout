import $ from 'jquery'

import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createMarketHistoryChart, createGasUsageHistoryChart } from './lib/history_chart'
import { createCoinBalanceHistoryChart } from './lib/coin_balance_history_chart'

(function () {
  const dashboardChartElement = $('[data-chart="historyChart"]')[0]
  const gasUsageChartElement = $('[data-chart="gasUsageChart"]')[0]
  const coinBalanceHistoryChartElement = $('[data-chart="coinBalanceHistoryChart"]')[0]
  if (dashboardChartElement) {
    window.dashboardChart = createMarketHistoryChart(dashboardChartElement)
  }
  if (gasUsageChartElement) {
    createGasUsageHistoryChart(gasUsageChartElement)
  }
  if (coinBalanceHistoryChartElement) {
    window.coinBalanceHistoryChart = createCoinBalanceHistoryChart(coinBalanceHistoryChartElement)
  }
  formatAllUsdValues()
  updateAllCalculatedUsdValues()
})()
