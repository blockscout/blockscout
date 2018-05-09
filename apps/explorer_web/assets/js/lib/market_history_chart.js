import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'
import moment from 'moment'
import numeral from 'numeral'
import sassVariables from '../../css/app.scss'

function formatPrice (price) {
  return '$' + price.toFixed(2)
}

function formatMarketCap (marketCap) {
  return numeral(marketCap).format('($0,0a)')
}

function createMarketHistoryChart (ctx) {
  const currentExchangeRate = ctx.dataset.current_exchange_rate
  const availableSupply = ctx.dataset.available_supply
  const marketHistoryData = humps.camelizeKeys(JSON.parse(ctx.dataset.market_history_data))
  const today = moment().format('YYYY-MM-DD')
  const currentMarketHistoryData = marketHistoryData.map(({date, closingPrice}) => ({
    date,
    closingPrice: date === today ? currentExchangeRate : closingPrice
  }))

  return new Chart(ctx, {
    type: 'line',
    responsive: true,
    data: {
      datasets: [{
        label: 'Price',
        yAxisID: 'price',
        data: currentMarketHistoryData.map(({ date, closingPrice }) => ({x: date, y: closingPrice})),
        fill: false,
        pointRadius: 0,
        backgroundColor: sassVariables.primary,
        borderColor: sassVariables.primary,
        lineTension: 0
      }, {
        label: 'Market Cap',
        yAxisID: 'marketCap',
        data: currentMarketHistoryData.map(({ date, closingPrice }) => ({x: date, y: closingPrice * availableSupply})),
        fill: false,
        pointRadius: 0.5,
        backgroundColor: sassVariables.secondary,
        borderColor: sassVariables.secondary,
        lineTension: 0
      }]
    },
    options: {
      legend: {
        display: false
      },
      scales: {
        xAxes: [{
          type: 'time',
          time: {
            unit: 'week',
            displayFormats: {
              week: 'MMM D'
            }
          }
        }],
        yAxes: [{
          id: 'price',
          ticks: {
            beginAtZero: true,
            callback: (value, index, values) => formatPrice(value),
            maxTicksLimit: 6
          }
        }, {
          id: 'marketCap',
          position: 'right',
          ticks: {
            callback: (value, index, values) => formatMarketCap(value),
            maxTicksLimit: 6
          }
        }]
      },
      tooltips: {
        mode: 'index',
        intersect: false,
        callbacks: {
          label: ({datasetIndex, yLabel}, {datasets}) => {
            const label = datasets[datasetIndex].label
            if (datasets[datasetIndex].label === 'Price') {
              return `${label}: ${formatPrice(yLabel)}`
            } else if (datasets[datasetIndex].label === 'Market Cap') {
              return `${label}: ${formatMarketCap(yLabel)}`
            } else {
              return yLabel
            }
          }
        }
      }
    }
  })
}

$('[data-chart="marketHistoryChart"]').each((i, ctx) => createMarketHistoryChart(ctx))
