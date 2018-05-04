import $ from 'jquery'
import Chart from 'chart.js'

$('[data-chart="marketHistoryChart"]').each((i, ctx)=> {
  const marketHistoryData = JSON.parse(ctx.dataset.market_history_data)
  console.log("Market History Data: ", marketHistoryData)

  var myChart = new Chart(ctx, {
    type: 'line',
    responsive: true,
    data: {
      datasets: [{
        label: 'Price',
        data: marketHistoryData.map(({ date, closing_price }) => ({x: date, y: closing_price})),
        fill: false,
        pointRadius: 0,
        borderColor: 'darkgray'
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
          ticks: {
            beginAtZero:true,
            callback: (value, index, values) => {
              return '$' + value.toFixed(2);
            },
            maxTicksLimit: 6
          }
        }]
      },
      tooltips: {
        mode: 'index',
        intersect: false
      }
    }
  });
})
