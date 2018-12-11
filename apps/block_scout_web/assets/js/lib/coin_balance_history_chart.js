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

      return new Chart(el, {
        type: 'line',
        data: {
          datasets: [{
            label: 'coin balance',
            data: coinBalanceHistoryData
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
                stepSize: 3
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
