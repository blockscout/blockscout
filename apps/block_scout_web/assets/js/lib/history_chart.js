import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'
import numeral from 'numeral'
import moment from 'moment'
import { formatUsdValue } from '../lib/currency'
import sassVariables from '../../css/app.scss'

const config = {
  type: 'line',
  responsive: true,
  data: {
    datasets: []
  },
  options: {
    layout: {
      padding: {
        left: 20,
        right: 20
      }
    },
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
          callback: (value, _index, _values) => `$${numeral(value).format('0,0.00')}`,
          maxTicksLimit: 4,
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }, {
        id: 'marketCap',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          callback: (_value, _index, _values) => '',
          maxTicksLimit: 6,
          drawOnChartArea: false
        }
      }, {
        id: 'numTransactions',
        position: 'right',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => `${numeral(value).format('0,0')}`,
          maxTicksLimit: 4,
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
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
          } else if (datasets[datasetIndex].yAxisID === 'numTransactions') {
            return `${label}: ${yLabel}`
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
    return getDataFromLocalStorage('priceDataSokol')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
  setDataToLocalStorage('priceDataSokol', data)
  return data
}

function getTxHistoryData (transactionHistory) {
  if (transactionHistory.length === 0) {
    return getDataFromLocalStorage('txHistoryDataSokol')
  }
  const data = transactionHistory.map(dataPoint => ({ x: dataPoint.date, y: dataPoint.number_of_transactions }))

  // it should be empty value for tx history the current day
  const prevDayStr = data[0].x
  var prevDay = moment(prevDayStr)
  let curDay = prevDay.add(1, 'days')
  curDay = curDay.format('YYYY-MM-DD')
  data.unshift({ x: curDay, y: null })

  setDataToLocalStorage('txHistoryDataSokol', data)
  return data
}

function getMarketCapData (marketHistoryData, availableSupply) {
  if (marketHistoryData.length === 0) {
    return getDataFromLocalStorage('marketCapDataSokol')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => {
    const supply = (availableSupply !== null && typeof availableSupply === 'object')
      ? availableSupply[date]
      : availableSupply
    return { x: date, y: closingPrice * supply }
  })
  setDataToLocalStorage('marketCapDataSokol', data)
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
  constructor (el, availableSupply, _marketHistoryData, dataConfig) {
    var axes = config.options.scales.yAxes.reduce(function (solution, elem) {
      solution[elem.id] = elem
      return solution
    },
    {})

    var priceActivated = true
    var marketCapActivated = true

    this.price = {
      label: window.localized.Price,
      yAxisID: 'price',
      data: [],
      fill: false,
      pointRadius: 0,
      backgroundColor: priceLineColor,
      borderColor: priceLineColor
      // lineTension: 0
    }
    if (dataConfig.market === undefined || dataConfig.market.indexOf('price') === -1) {
      this.price.hidden = true
      axes.price.display = false
      priceActivated = false
    }

    this.marketCap = {
      label: window.localized['Market Cap'],
      yAxisID: 'marketCap',
      data: [],
      fill: false,
      pointRadius: 0,
      backgroundColor: mcapLineColor,
      borderColor: mcapLineColor
      // lineTension: 0
    }
    if (dataConfig.market === undefined || dataConfig.market.indexOf('market_cap') === -1) {
      this.marketCap.hidden = true
      axes.marketCap.display = false
      marketCapActivated = false
    }

    this.numTransactions = {
      label: window.localized['Tx/day'],
      yAxisID: 'numTransactions',
      data: [],
      fill: false,
      pointRadius: 0,
      backgroundColor: sassVariables.dashboardLineColorTransactions,
      borderColor: sassVariables.dashboardLineColorTransactions
      // lineTension: 0
    }

    if (dataConfig.transactions === undefined || dataConfig.transactions.indexOf('transactions_per_day') === -1) {
      this.numTransactions.hidden = true
      axes.numTransactions.display = false
    } else if (!priceActivated && !marketCapActivated) {
      axes.numTransactions.position = 'left'
      this.numTransactions.backgroundColor = sassVariables.dashboardLineColorPrice
      this.numTransactions.borderColor = sassVariables.dashboardLineColorPrice
    }

    this.availableSupply = availableSupply
    config.data.datasets = [this.price, this.marketCap, this.numTransactions]

    const isChartLoadedKey = 'isChartLoadedSokol'
    const isChartLoaded = window.sessionStorage.getItem(isChartLoadedKey) === 'true'
    if (isChartLoaded) {
      config.options.animation = false
    } else {
      window.sessionStorage.setItem(isChartLoadedKey, true)
    }

    this.chart = new Chart(el, config)
  }

  updateMarketHistory (availableSupply, marketHistoryData) {
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

  updateTransactionHistory (transactionHistory) {
    this.numTransactions.data = getTxHistoryData(transactionHistory)
    this.chart.update()
  }
}

export function createMarketHistoryChart (el) {
  const dataPaths = $(el).data('history_chart_paths')
  const dataConfig = $(el).data('history_chart_config')

  const $chartError = $('[data-chart-error-message]')
  const chart = new MarketHistoryChart(el, 0, [], dataConfig)
  Object.keys(dataPaths).forEach(function (historySource) {
    $.getJSON(dataPaths[historySource], { type: 'JSON' })
      .done(data => {
        switch (historySource) {
          case 'market': {
            const availableSupply = JSON.parse(data.supply_data)
            const marketHistoryData = humps.camelizeKeys(JSON.parse(data.history_data))

            $(el).show()
            chart.updateMarketHistory(availableSupply, marketHistoryData)
            break
          }
          case 'transaction': {
            const transactionHistory = JSON.parse(data.history_data)

            $(el).show()
            chart.updateTransactionHistory(transactionHistory)
            break
          }
        }
      })
      .fail(() => {
        $(el).hide()
        $chartError.show()
      })
  })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="historyChart"]')[0])
})
