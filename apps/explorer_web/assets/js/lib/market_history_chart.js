import $ from 'jquery'
import Chart from 'chart.js'
import numeral from 'numeral'

function formatPrice(price) {
  return '$' + price.toFixed(2)
}

function formatMarketCap(marketCap) {
  return numeral(marketCap).format('($0,0a)')
}

$('[data-chart="marketHistoryChart"]').each((i, ctx)=> {
  const marketHistoryData = JSON.parse(ctx.dataset.market_history_data)
  const availableSupply = JSON.parse(ctx.dataset.available_supply)

  var myChart = new Chart(ctx, {
    type: 'line',
    responsive: true,
    data: {
      datasets: [{
        label: 'Price',
        yAxisID: 'price',
        data: marketHistoryData.map(({ date, closing_price }) => ({x: date, y: closing_price})),
        fill: false,
        pointRadius: 0,
        borderColor: 'darkgray'
      },{
        label: 'Market Cap',
        yAxisID: 'marketCap',
        data: marketHistoryData.map(({ date, closing_price }) => ({x: date, y: closing_price * availableSupply})),
        fill: false,
        pointRadius: 0.5,
        borderColor: 'lightgray'
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
            beginAtZero:true,
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
            if(datasets[datasetIndex].label === 'Price') {
              return `${label}: ${formatPrice(yLabel)}`
            } else if(datasets[datasetIndex].label === 'Market Cap') {
              return `${label}: ${formatMarketCap(yLabel)}`
            } else {
              return yLabel
            }
          }
        }
      }
    }
  })
})
