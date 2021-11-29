import $ from 'jquery'
import { Chart, LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip } from 'chart.js'
import 'chartjs-adapter-luxon'
import numeral from 'numeral'
import { DateTime } from 'luxon'
import sassVariables from '../../css/app.scss'

Chart.defaults.font.family = 'Nunito, "Helvetica Neue", Arial, sans-serif,"Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"'
Chart.register(LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip)

const grid = {
  display: false,
  drawBorder: false,
  drawOnChartArea: false
}

function xAxe (fontColor) {
  return {
    grid: grid,
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

let gasUsageFontColor
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
    interaction: {
      intersect: false,
      mode: 'index'
    },
    scales: {
      x: xAxe(gasUsageFontColor),
      gasUsage: {
        position: 'right',
        grid: grid,
        ticks: {
          beginAtZero: true,
          callback: (value, _index, _values) => formatValue(value),
          maxTicksLimit: 4,
          color: gasUsageFontColor
        }
      }
    },
    plugins: {
      legend: legend,
      tooltip: {
        mode: 'index',
        intersect: false,
        callbacks: {
          label: (context) => {
            const { label } = context.dataset
            const { formattedValue } = context
            if (context.dataset.yAxisID === 'gasUsage') {
              return `${label}: ${formatValue(formattedValue)}`
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

function getGasUsageHistoryData (gasUsageHistory) {
  if (gasUsageHistory.length === 0) {
    return getDataFromLocalStorage('gasUsageHistoryData')
  }
  const data = gasUsageHistory.map(dataPoint => ({ x: dataPoint.date, y: dataPoint.gas_used }))

  // it should be empty value for tx history the current day
  const prevDayStr = data[0].x
  const prevDay = DateTime.fromISO(prevDayStr)
  let curDay = prevDay.plus({ days: 1 })
  curDay = curDay.toISODate()
  data.unshift({ x: curDay, y: null })

  setDataToLocalStorage('gasUsageHistoryData', data)
  return data
}

class GasUsageHistoryChart {
  constructor (el, dataConfig) {
    const axes = gasUsageConfig.options.scales

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
        $chartError.show()
      })
  })
  return chart
}

export function createBlockGasHistoryChart (el) {
  $(el).easyPieChart({
    size: 160,
    barColor: '#17d3e6',
    scaleLength: 0,
    lineWidth: 15,
    trackColor: '#373737',
    lineCap: 'circle',
    animate: 2000
  })
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-error-message]').hide()
  createGasUsageHistoryChart($('[data-chart="gasUsageChart"]')[0])
  createBlockGasHistoryChart($('.blockGasChart')[0])
})
