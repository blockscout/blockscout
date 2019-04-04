import $ from 'jquery'
import Chart from 'chart.js'

$(function () {
  $('.js-become-candidate').on('click', function () {
    $('#becomeCandidateModal').modal()
  })

  $('.js-validator-info-modal').on('click', function () {
    $('#validatorInfoModal').modal()
  })

  $('.js-stake-stake').on('click', function () {
    const modal = '#stakeModal'
    const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
    const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

    $(modal).modal()

    setupStakesProgress(progress, total, modal)
  })

  $('.js-withdraw-stake').on('click', function () {
    const modal = '#withdrawModal'
    const progress = parseInt($(`${modal} .js-stakes-progress-data-progress`).text())
    const total = parseInt($(`${modal} .js-stakes-progress-data-total`).text())

    $(modal).modal()

    setupStakesProgress(progress, total, modal)
  })

  function setupStakesProgress (progress, total, modal) {
    const stakeProgress = $(`${modal} .js-stakes-progress`)
    const primaryColor = $('.btn-full-primary').css('background-color')
    const backgroundColors = [
      primaryColor,
      'rgba(202, 199, 226, 0.5)'
    ]
    const progressBackground = total - progress

    let myChart = new Chart(stakeProgress, {
      type: 'doughnut',
      data: {
        datasets: [{
          data: [progress, progressBackground],
          backgroundColor: backgroundColors,
          hoverBackgroundColor: backgroundColors,
          borderWidth: 0
        }]
      },
      options: {
        cutoutPercentage: 80,
        legend: {
          display: false
        },
        tooltips: {
          enabled: false
        }
      }
    })
  }
})
