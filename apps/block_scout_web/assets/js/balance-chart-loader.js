import $ from 'jquery'

import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createCoinBalanceHistoryChart } from './lib/coin_balance_history_chart'

(function () {
  const coinBalanceHistoryChartElement = $('[data-chart="coinBalanceHistoryChart"]')[0]
  if (coinBalanceHistoryChartElement) {
    window.coinBalanceHistoryChart = createCoinBalanceHistoryChart(coinBalanceHistoryChartElement)
  }
  formatAllUsdValues()
  updateAllCalculatedUsdValues()
})()
