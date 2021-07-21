import $ from 'jquery'

import { createGasUsageHistoryChart } from './lib/gas_tracker_chart'

(function () {
  const gasUsageChartElement = $('[data-chart="gasUsageChart"]')[0]
  if (gasUsageChartElement) {
    createGasUsageHistoryChart(gasUsageChartElement)
  }
})()
