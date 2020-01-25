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

function getDataFromLocalStorage (key) {
  const data = window.localStorage.getItem(key)
  return data ? JSON.parse(data) : []
}

function setDataToLocalStorage (key, data) {
  window.localStorage.setItem(key, JSON.stringify(data))
}

function getPriceData (marketHistoryData) {
  if (marketHistoryData.length === 0) {
    return getDataFromLocalStorage('priceData')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
  setDataToLocalStorage('priceData', data)
  return data
}

function getMarketCapData (marketHistoryData, availableSupply) {
  if (marketHistoryData.length === 0) {
    return getDataFromLocalStorage('marketCapData')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => {
    const supply = (availableSupply !== null && typeof availableSupply === 'object')
      ? availableSupply[date]
      : availableSupply
    return { x: date, y: closingPrice * supply }
  })
  setDataToLocalStorage('marketCapData', data)
  return data
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

    const isChartLoadedKey = 'isChartLoaded'
    const isChartLoaded = window.sessionStorage.getItem(isChartLoadedKey) === 'true'
    if (isChartLoaded) {
      config.options.animation = false
    } else {
      window.sessionStorage.setItem(isChartLoadedKey, true)
    }

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
  const $chartError = $('[data-chart-error-message]')
  const chart = new MarketHistoryChart(el, 0, [])
  $(el).show()

  $.getJSON(dataPath, { type: 'JSON' })
    .done(data => {
      const availableSupply = JSON.parse(data.supply_data)
      const marketHistoryData = humps.camelizeKeys(JSON.parse(data.history_data))
      chart.update(availableSupply, marketHistoryData)
    })
    .fail(() => {
      $(el).hide()
      $chartError.show()
    })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="marketHistoryChart"]')[0])
})
