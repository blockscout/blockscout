import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'

export function createCoinBalanceHistoryChart (el) {
  const $chartContainer = $('[data-chart-container]')
  const $chartLoading = $('[data-chart-loading-message]')
  const $chartError = $('[data-chart-error-message]')
  const dataPath = el.dataset.coin_balance_history_data_path

  $.getJSON(dataPath, {type: 'JSON'})
    .done(data => {
      $chartContainer.show()

      const coinBalanceHistoryData = humps.camelizeKeys(data)
        .map(balance => ({
          x: balance.date,
          y: balance.value
        }))

      var step_size = 3

      if (data.length > 2) {
        console.log(data[0].date)
        var diff = Math.abs(new Date(data[0].date) - new Date(data[1].date));
        var period_in_days = diff / (1000 * 60 * 60 * 24)
        step_size = period_in_days
      }
      return new Chart(el, {
        type: 'line',
        data: {
          datasets: [{
            label: 'coin balance',
            data: coinBalanceHistoryData,
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
                unit: 'day',
                stepSize: step_size
              }
            }],
            yAxes: [{
              ticks: {
                beginAtZero: true
              },
              scaleLabel: {
                display: true,
                labelString: window.localized['Ether']
              }
            }]
          }
        }
      })
    })
    .fail(() => {
      $chartError.show()
    })
    .always(() => {
      $chartLoading.hide()
    })
}
