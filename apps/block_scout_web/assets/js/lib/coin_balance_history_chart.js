import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'

export function createCoinBalanceHistoryChart (el) {
  const $chartContainer = $('[data-chart-container]')
  const $chartLoading = $('[data-chart-loading-message]')
  const $chartError = $('[data-chart-error-message]')
  const dataPath = el.dataset.coin_balance_history_data_path

  $.getJSON(dataPath, { type: 'JSON' })
    .done(data => {
      $chartContainer.show()

      const coinBalanceHistoryData = humps.camelizeKeys(data)
        .map(balance => ({
          x: balance.date,
          y: balance.value
        }))

      var stepSize = 3

      if (data.length > 1) {
        var diff = Math.abs(new Date(data[data.length - 1].date) - new Date(data[data.length - 2].date))
        var periodInDays = diff / (1000 * 60 * 60 * 24)

        stepSize = periodInDays
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
                stepSize: stepSize
              }
            }],
            yAxes: [{
              ticks: {
                beginAtZero: true
              },
              scaleLabel: {
                display: true,
                labelString: window.localized.Ether
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
