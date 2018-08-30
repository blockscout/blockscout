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
          maxTicksLimit: 4
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
        label: ({datasetIndex, yLabel}, {datasets}) => {
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
  return marketHistoryData.map(({ date, closingPrice }) => ({x: date, y: closingPrice}))
}

function getMarketCapData (marketHistoryData, availableSupply) {
  return marketHistoryData.map(({ date, closingPrice }) => ({x: date, y: closingPrice * availableSupply}))
}

class MarketHistoryChart {
  constructor (el, availableSupply, marketHistoryData) {
    this.price = {
      label: window.localized['Price'],
      yAxisID: 'price',
      data: getPriceData(marketHistoryData),
      fill: false,
      pointRadius: 0,
      backgroundColor: sassVariables.primary,
      borderColor: sassVariables.primary,
      lineTension: 0
    }
    this.marketCap = {
      label: window.localized['Market Cap'],
      yAxisID: 'marketCap',
      data: getMarketCapData(marketHistoryData, availableSupply),
      fill: false,
      pointRadius: 0,
      backgroundColor: sassVariables.secondary,
      borderColor: sassVariables.secondary,
      lineTension: 0
    }
    config.data.datasets = [this.price, this.marketCap]
    this.chart = new Chart(el, config)
  }
  update (availableSupply, marketHistoryData) {
    this.price.data = getPriceData(marketHistoryData)
    this.marketCap.data = getMarketCapData(marketHistoryData, availableSupply)
    this.chart.update()
  }
}

export function createMarketHistoryChart (ctx) {
  const availableSupply = ctx.dataset.available_supply
  const marketHistoryData = humps.camelizeKeys(JSON.parse(ctx.dataset.market_history_data))

  return new MarketHistoryChart(ctx, availableSupply, marketHistoryData)
}
