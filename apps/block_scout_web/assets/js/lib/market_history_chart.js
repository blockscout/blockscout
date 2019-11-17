import $ from 'jquery'
import Chart from 'chart.js/dist/Chart.min.js'
import humps from 'humps'
import numeral from 'numeral'
import { formatUsdValue } from '../lib/currency'
import sassVariables from '../../css/app.scss'
import { showLoader } from '../lib/utils'

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
        id: 'price',
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
      }, {
        id: 'marketCap',
        position: 'right',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          callback: (value, index, values) => '',
          maxTicksLimit: 6,
          drawOnChartArea: false
        }
      }]
    },
    tooltips: {
      mode: 'index',
      intersect: false,
      callbacks: {
        label: ({ datasetIndex, yLabel }, { datasets }) => {
          const label = datasets[datasetIndex].label
          if (datasets[datasetIndex].yAxisID === 'price') {
            return `${label}: ${formatUsdValue(yLabel)}`
          } else if (datasets[datasetIndex].yAxisID === 'marketCap') {
            return `${label}: ${formatUsdValue(yLabel)}`
          } else {
            return yLabel
          }
        }
      }
    }
  }
}

function getPriceData (marketHistoryData) {
  return marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
}

function getMarketCapData (marketHistoryData, availableSupply) {
  if (availableSupply !== null && typeof availableSupply === 'object') {
    return marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice * availableSupply[date] }))
  } else {
    return marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice * availableSupply }))
  }
}

// colors for light and dark theme
var priceLineColor
var mcapLineColor
if (localStorage.getItem('current-color-mode') === 'dark') {
  priceLineColor = sassVariables.darkprimary
  mcapLineColor = sassVariables.darksecondary
} else {
  priceLineColor = sassVariables.dashboardLineColorPrice
  mcapLineColor = sassVariables.dashboardLineColorMarket
}

class MarketHistoryChart {
  constructor (el, availableSupply, marketHistoryData) {
    this.price = {
      label: window.localized.Price,
      yAxisID: 'price',
      data: getPriceData(marketHistoryData),
      fill: false,
      pointRadius: 0,
      backgroundColor: priceLineColor,
      borderColor: priceLineColor,
      lineTension: 0
    }
    this.marketCap = {
      label: window.localized['Market Cap'],
      yAxisID: 'marketCap',
      data: getMarketCapData(marketHistoryData, availableSupply),
      fill: false,
      pointRadius: 0,
      backgroundColor: mcapLineColor,
      borderColor: mcapLineColor,
      lineTension: 0
    }
    this.availableSupply = availableSupply
    config.data.datasets = [this.price, this.marketCap]
    this.chart = new Chart(el, config)
  }

  update (availableSupply, marketHistoryData) {
    this.price.data = getPriceData(marketHistoryData)
    if (this.availableSupply !== null && typeof this.availableSupply === 'object') {
      const today = new Date().toJSON().slice(0, 10)
      this.availableSupply[today] = availableSupply
      this.marketCap.data = getMarketCapData(marketHistoryData, this.availableSupply)
    } else {
      this.marketCap.data = getMarketCapData(marketHistoryData, availableSupply)
    }
    this.chart.update()
  }
}

export function createMarketHistoryChart (el) {
  const dataPath = el.dataset.market_history_chart_path
  const $chartLoading = $('[data-chart-loading-message]')

  const isTimeout = true
  const timeoutID = showLoader(isTimeout, $chartLoading)

  const $chartError = $('[data-chart-error-message]')
  const chart = new MarketHistoryChart(el, 0, [])
  $.getJSON(dataPath, { type: 'JSON' })
    .done(data => {
      const availableSupply = JSON.parse(data.supply_data)
      const marketHistoryData = humps.camelizeKeys(JSON.parse(data.history_data))
      $(el).show()
      chart.update(availableSupply, marketHistoryData)
    })
    .fail(() => {
      $chartError.show()
    })
    .always(() => {
      $chartLoading.hide()
      clearTimeout(timeoutID)
    })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-loading-message]').show()
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="marketHistoryChart"]')[0])
})
