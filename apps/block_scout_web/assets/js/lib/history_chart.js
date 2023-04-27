import $ from 'jquery'
import { Chart, LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip } from 'chart.js'
import 'chartjs-adapter-luxon'
import humps from 'humps'
import numeral from 'numeral'
import { DateTime } from 'luxon'
import { formatUsdValue } from '../lib/currency'
import { isDarkMode } from '../lib/dark_mode'
// @ts-ignore
import sassVariables from '../../css/export-vars-to-js.module.scss'

Chart.defaults.font.family = 'Nunito, "Helvetica Neue", Arial, sans-serif,"Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"'
Chart.register(LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip)

// @ts-ignore
const coinName = document.getElementById('js-coin-name').value
const chainId = document.getElementById('js-chain-id').value
const priceDataKey = `priceData${coinName}`
const txHistoryDataKey = `txHistoryData${coinName}${chainId}`
const marketCapDataKey = `marketCapData${coinName}${chainId}`
const isChartLoadedKey = `isChartLoaded${coinName}${chainId}`

const grid = {
  display: false,
  drawBorder: false,
  drawOnChartArea: false
}

function getTxChartColor () {
  if ((isDarkMode())) {
    return sassVariables.dashboardLineColorTransactionsDarkTheme
  } else {
    return sassVariables.dashboardLineColorTransactions
  }
}

function getPriceChartColor () {
  if ((isDarkMode())) {
    return sassVariables.dashboardLineColorPriceDarkTheme
  } else {
    return sassVariables.dashboardLineColorPrice
  }
}

function getMarketCapChartColor () {
  if ((isDarkMode())) {
    return sassVariables.dashboardLineColorMarketDarkTheme
  } else {
    return sassVariables.dashboardLineColorMarket
  }
}

function xAxe (fontColor) {
  return {
    grid,
    type: 'time',
    time: {
      unit: 'day',
      tooltipFormat: 'DD',
      stepSize: 14
    },
    ticks: {
      color: fontColor
    }
  }
}

const padding = {
  left: 20,
  right: 20
}

const legend = {
  display: false
}

function formatValue (val) {
  return `${numeral(val).format('0,0')}`
}

const config = {
  type: 'line',
  responsive: true,
  data: {
    datasets: []
  },
  options: {
    layout: {
      padding
    },
    interaction: {
      intersect: false,
      mode: 'index'
    },
    scales: {
      x: xAxe(sassVariables.dashboardBannerChartAxisFontColor),
      numTransactions: {
        position: 'left',
        grid,
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => formatValue(value),
          maxTicksLimit: 4,
          color: sassVariables.dashboardBannerChartAxisFontColor
        }
      }
    },
    plugins: {
      legend,
      title: {
        display: true,
        color: sassVariables.dashboardBannerChartAxisFontColor
      },
      tooltip: {
        mode: 'index',
        intersect: false,
        callbacks: {
          label: (context) => {
            const { label } = context.dataset
            const { formattedValue, parsed } = context
            if (context.dataset.yAxisID === 'price') {
              return `${label}: ${formatUsdValue(parsed.y)}`
            } else if (context.dataset.yAxisID === 'marketCap') {
              return `${label}: ${formatUsdValue(parsed.y)}`
            } else if (context.dataset.yAxisID === 'numTransactions') {
              return `${label}: ${formattedValue}`
            } else {
              return formattedValue
            }
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
    return getDataFromLocalStorage(priceDataKey)
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
  setDataToLocalStorage(priceDataKey, data)
  return data
}

function getTxHistoryData (transactionHistory) {
  if (transactionHistory.length === 0) {
    return getDataFromLocalStorage(txHistoryDataKey)
  }
  const data = transactionHistory.map(dataPoint => ({ x: dataPoint.date, y: dataPoint.number_of_transactions }))

  // it should be empty value for tx history the current day
  const prevDayStr = data[0].x
  const prevDay = DateTime.fromISO(prevDayStr)
  const curDay = prevDay.plus({ days: 1 }).toISODate()
  data.unshift({ x: curDay, y: null })

  setDataToLocalStorage(txHistoryDataKey, data)
  return data
}

function getMarketCapData (marketHistoryData, availableSupply) {
  if (marketHistoryData.length === 0) {
    return getDataFromLocalStorage(marketCapDataKey)
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => {
    const supply = (availableSupply !== null && typeof availableSupply === 'object')
      ? availableSupply[date]
      : availableSupply
    return { x: date, y: closingPrice * supply }
  })
  setDataToLocalStorage(marketCapDataKey, data)
  return data
}

// colors for light and dark theme
const priceLineColor = getPriceChartColor()
const mcapLineColor = getMarketCapChartColor()

class MarketHistoryChart {
  constructor (el, availableSupply, _marketHistoryData, dataConfig) {
    const axes = config.options.scales

    let priceActivated = true
    let marketCapActivated = true

    this.price = {
      label: 'Gnosis Chain Price',
      yAxisID: 'price',
      data: [],
      fill: false,
      cubicInterpolationMode: 'monotone',
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
      label: 'Total Value Locked',
      yAxisID: 'marketCap',
      data: [],
      fill: false,
      cubicInterpolationMode: 'monotone',
      pointRadius: 0,
      backgroundColor: mcapLineColor,
      borderColor: mcapLineColor
      // lineTension: 0
    }
    if (dataConfig.market === undefined || dataConfig.market.indexOf('market_cap') === -1) {
      this.marketCap.hidden = true
      axes.marketCap.display = false
      this.price.hidden = true
      axes.price.display = false
      marketCapActivated = false
    }

    this.numTransactions = {
      label: 'Tx/day',
      yAxisID: 'numTransactions',
      data: [],
      cubicInterpolationMode: 'monotone',
      fill: false,
      pointRadius: 0,
      backgroundColor: getTxChartColor(),
      borderColor: getTxChartColor()
      // lineTension: 0
    }

    if (dataConfig.transactions === undefined || dataConfig.transactions.indexOf('transactions_per_day') === -1) {
      this.numTransactions.hidden = true
      axes.numTransactions.display = false
    } else if (!priceActivated && !marketCapActivated) {
      axes.numTransactions.position = 'left'
    }

    this.availableSupply = availableSupply

    const txChartTitle = 'Daily transactions (30 days)'
    const marketChartTitle = 'Daily price and market cap'
    let chartTitle = ''
    if (Object.keys(dataConfig).join() === 'transactions') {
      chartTitle = txChartTitle
    } else if (Object.keys(dataConfig).join() === 'market') {
      chartTitle = marketChartTitle
    }
    config.options.plugins.title.text = chartTitle

    config.data.datasets = [this.numTransactions]

    const isChartLoaded = window.sessionStorage.getItem(isChartLoadedKey) === 'true'
    if (isChartLoaded) {
      config.options.animation = false
    } else {
      window.sessionStorage.setItem(isChartLoadedKey, 'true')
    }

    // @ts-ignore
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
            const txsHistoryData = JSON.parse(data.history_data)

            $(el).show()
            chart.updateTransactionHistory(txsHistoryData)
            break
          }
        }
      })
      .fail(() => {
        $chartError.show()
      })
  })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="historyChart"]')[0])
})
