import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'
import numeral from 'numeral'
import moment from 'moment'
import { formatUsdValue } from '../lib/currency'
import sassVariables from '../../css/app.scss'

function xAxes (fontColor) {
  return [{
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
      fontColor: fontColor
    }
  }]
}

const gridLines = {
  display: false,
  drawBorder: false
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
      padding: padding
    },
    legend: legend,
    scales: {
      xAxes: xAxes(sassVariables.dashboardBannerChartAxisFontColor),
      yAxes: [{
        id: 'price',
        gridLines: gridLines,
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => `$${numeral(value).format('0,0.00')}`,
          maxTicksLimit: 4,
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }, {
        id: 'marketCap',
        gridLines: gridLines,
        ticks: {
          callback: (_value, _index, _values) => '',
          maxTicksLimit: 6,
          drawOnChartArea: false
        }
      }, {
        id: 'numTransactions',
        position: 'right',
        gridLines: gridLines,
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => formatValue(value),
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

var gasUsageFontColor
if (localStorage.getItem('current-color-mode') === 'dark') {
  gasUsageFontColor = sassVariables.dashboardBannerChartAxisFontColor
} else {
  gasUsageFontColor = sassVariables.dashboardBannerChartAxisFontAltColor
}

const gasUsageConfig = {
  type: 'line',
  responsive: true,
  data: {
    datasets: []
  },
  options: {
    layout: {
      padding: padding
    },
    legend: legend,
    scales: {
      xAxes: xAxes(gasUsageFontColor),
      yAxes: [{
        id: 'gasUsage',
        position: 'right',
        gridLines: gridLines,
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => formatValue(value),
          maxTicksLimit: 4,
          fontColor: gasUsageFontColor
        }
      }]
    },
    tooltips: {
      mode: 'index',
      intersect: false,
      callbacks: {
        label: ({ datasetIndex, yLabel }, { datasets }) => {
          const label = datasets[datasetIndex].label
          if (datasets[datasetIndex].yAxisID === 'gasUsage') {
            return `${label}: ${formatValue(yLabel)}`
          } else {
            return yLabel
          }
        }
      }
    }
  }
}

const blockGasPieConfig = {
  type: 'doughnut',
  responsive: true,
  data: {
    datasets: [{
      label: 'Population (millions)',
      backgroundColor: ['linear-gradient(90deg, rgba(2,0,36,1) 0%, rgba(26,236,124,1) 0%, rgba(230,58,90,1) 100%)', '#fff'],
      data: [2478, 5267]
    }]
  },
  options: {
    layout: {
      padding: padding
    },
    legend: legend
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
    return getDataFromLocalStorage('priceDataXDAI')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
  setDataToLocalStorage('priceDataXDAI', data)
  return data
}

function getTxHistoryData (transactionHistory) {
  if (transactionHistory.length === 0) {
    return getDataFromLocalStorage('txHistoryDataXDAI')
  }
  const data = transactionHistory.map(dataPoint => ({ x: dataPoint.date, y: dataPoint.number_of_transactions }))

  // it should be empty value for tx history the current day
  const prevDayStr = data[0].x
  const prevDay = moment(prevDayStr)
  let curDay = prevDay.add(1, 'days')
  curDay = curDay.format('YYYY-MM-DD')
  data.unshift({ x: curDay, y: null })

  setDataToLocalStorage('txHistoryDataXDAI', data)
  return data
}

function getGasUsageHistoryData (gasUsageHistory) {
  if (gasUsageHistory.length === 0) {
    return getDataFromLocalStorage('gasUsageHistoryData')
  }
  const data = gasUsageHistory.map(dataPoint => ({ x: dataPoint.date, y: dataPoint.gas_used }))

  // it should be empty value for tx history the current day
  const prevDayStr = data[0].x
  const prevDay = moment(prevDayStr)
  let curDay = prevDay.add(1, 'days')
  curDay = curDay.format('YYYY-MM-DD')
  data.unshift({ x: curDay, y: null })

  setDataToLocalStorage('gasUsageHistoryData', data)
  return data
}

function getMarketCapData (marketHistoryData, availableSupply) {
  if (marketHistoryData.length === 0) {
    return getDataFromLocalStorage('marketCapDataXDAI')
  }
  const data = marketHistoryData.map(({ date, closingPrice }) => {
    const supply = (availableSupply !== null && typeof availableSupply === 'object')
      ? availableSupply[date]
      : availableSupply
    return { x: date, y: closingPrice * supply }
  })
  setDataToLocalStorage('marketCapDataXDAI', data)
  return data
}

// colors for light and dark theme
const priceLineColor = sassVariables.dashboardLineColorPrice
const mcapLineColor = sassVariables.dashboardLineColorMarket

class MarketHistoryChart {
  constructor (el, availableSupply, _marketHistoryData, dataConfig) {
    const axes = config.options.scales.yAxes.reduce(function (solution, elem) {
      solution[elem.id] = elem
      return solution
    },
    {})

    let priceActivated = true
    let marketCapActivated = true

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

    const isChartLoadedKey = 'isChartLoadedXDAI'
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

class GasUsageHistoryChart {
  constructor (el, dataConfig) {
    const axes = gasUsageConfig.options.scales.yAxes.reduce(function (solution, elem) {
      solution[elem.id] = elem
      return solution
    },
    {})

    this.gasUsage = {
      label: 'Gas/day',
      yAxisID: 'gasUsage',
      data: [],
      fill: false,
      pointRadius: 0,
      backgroundColor: sassVariables.dashboardLineColorTransactions,
      borderColor: sassVariables.dashboardLineColorTransactions
    }

    if (dataConfig.gas_usage === undefined || dataConfig.gas_usage.indexOf('gas_usage_per_day') === -1) {
      this.gasUsage.hidden = true
      axes.gasUsage.display = false
    }

    gasUsageConfig.data.datasets = [this.gasUsage]

    const isChartLoadedKey = 'isChartLoaded'
    const isChartLoaded = window.sessionStorage.getItem(isChartLoadedKey) === 'true'
    if (isChartLoaded) {
      gasUsageConfig.options.animation = false
    } else {
      window.sessionStorage.setItem(isChartLoadedKey, true)
    }

    this.chart = new Chart(el, gasUsageConfig)
  }

  updateGasUsageHistory (gasUsageHistory) {
    this.gasUsage.data = getGasUsageHistoryData(gasUsageHistory)
    this.chart.update()
  }
}

class BlockGasChart {
  constructor (el) {
    this.chart = new Chart(el, blockGasPieConfig)
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

export function createGasUsageHistoryChart (el) {
  const dataPaths = $(el).data('history_chart_paths')
  const dataConfig = $(el).data('history_chart_config')

  const $chartError = $('[data-chart-error-message]')
  const chart = new GasUsageHistoryChart(el, dataConfig)
  Object.keys(dataPaths).forEach(function (historySource) {
    $.getJSON(dataPaths[historySource], { type: 'JSON' })
      .done(data => {
        switch (historySource) {
          case 'gas_usage': {
            const gasUsageHistory = JSON.parse(data.history_data)

            $(el).show()
            chart.updateGasUsageHistory(gasUsageHistory)
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

export function createBlockGasHistoryChart (el) {
  $(el).easyPieChart({
    size: 160,
    barColor: "#17d3e6",
    scaleLength: 0,
    lineWidth: 15,
    trackColor: "#373737",
    lineCap: "circle",
    animate: 2000,
  })
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="historyChart"]')[0])
  createGasUsageHistoryChart($('[data-chart="gasUsageChart"]')[0])
  createBlockGasHistoryChart($('.blockGasChart')[0])
})
