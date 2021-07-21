import $ from 'jquery'
import { Chart, Filler, LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip } from 'chart.js'
import 'chartjs-adapter-moment'
import humps from 'humps'

Chart.defaults.font.family = 'Nunito, "Helvetica Neue", Arial, sans-serif,"Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol"'
Chart.register(Filler, LineController, LineElement, PointElement, LinearScale, TimeScale, Title, Tooltip)

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

      let stepSize = 3

      if (data.length > 1) {
        const diff = Math.abs(new Date(data[data.length - 1].date) - new Date(data[data.length - 2].date))
        const periodInDays = diff / (1000 * 60 * 60 * 24)

        stepSize = periodInDays
      }
      return new Chart(el, {
        type: 'line',
        data: {
          datasets: [{
            label: 'coin balance',
            data: coinBalanceHistoryData,
            lineTension: 0,
            cubicInterpolationMode: 'monotone',
            fill: true
          }]
        },
        plugins: {
          legend: {
            display: false
          }
        },
        interaction: {
          intersect: false,
          mode: 'index'
        },
        options: {
          scales: {
            x: {
              type: 'time',
              time: {
                unit: 'day',
                tooltipFormat: 'YYYY-MM-DD',
                stepSize: stepSize
              }
            },
            y: {
              type: 'linear',
              ticks: {
                beginAtZero: true
              },
              title: {
                display: true,
                labelString: 'xDAI'
              }
            }
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
