import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'
import numeral from 'numeral'
import { formatUsdValue } from '../lib/currency'
import sassVariables from '../../css/app.scss'

const config = {
  type: 'line',
  responsive: true,
  data: {
    datasets: []
  },
  options: {
    legend: {
      display: false
    },
    scales: {
      xAxes: [{
        gridLines: {
          display: false,
          drawBorder: false
        },
        type: 'time',
        time: {
          unit: 'day',
          stepSize: 14
        },
        ticks: {
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }],
      yAxes: [{
        id: 'num_transactions',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          beginAtZero: true,
          callback: (value, index, values) => `$${numeral(value).format('0,0.00')}`,
          maxTicksLimit: 4,
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }]
    },
    tooltips: {
      mode: 'index',
      intersect: false,
      callbacks: {
        label: ({datasetIndex, yLabel}, {datasets}) => {
          const label = datasets[datasetIndex].label
          if (datasets[datasetIndex].yAxisID === 'num_transactions') {
            return `${label}: ${formatUsdValue(yLabel)}`
          } else {
            return yLabel
          }
        }
      }
    }
  }
}

function transformData (marketHistoryData) {
    return marketHistoryData.map(
        ({ date, num_transactions }) => ({x: date, y: num_transactions}))
}

class TransactionHistoryChart {
    constructor (el, transactionHistoryData) {
    this.num_transactions = {
      label: window.localized['Price'],
      yAxisID: 'num_transactions',
      data: transformData(transactionHistoryData),
      fill: false,
      pointRadius: 0,
      backgroundColor: sassVariables.dashboardLineColorPrice,
      borderColor: sassVariables.dashboardLineColorPrice,
      lineTension: 0
    }
    config.data.datasets = [this.num_transactions]
    this.chart = new Chart(el, config)
  }
  update (transactionHistoryData) {
    this.num_transactions.data = transformData(TransactionHistoryData)
    this.chart.update()
  }
}

export function createTransactionHistoryChart (el) {
  const dataPath = el.dataset.transaction_history_chart_path
  const $chartLoading = $('[data-chart-loading-message]')
  const $chartError = $('[data-chart-error-message]')
  const chart = new TransactionHistoryChart(el, 0, [])
  $.getJSON(dataPath, {type: 'JSON'})
    .done(data => {
      const transactionStats = JSON.parse(data.history_data)
      $(el).show()
      chart.update(transactionStats)
    })
    .fail(() => {
      $chartError.show()
    })
    .always(() => {
      $chartLoading.hide()
    })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-loading-message]').show()
  $('[data-chart-error-message]').hide()
  createTransactionHistoryChart($('[data-chart="marketHistoryChart"]')[0])
})
