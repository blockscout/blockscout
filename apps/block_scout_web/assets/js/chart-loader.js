import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createMarketHistoryChart } from './lib/history_chart'
import $ from 'jquery'  

(function () {
  const dashboardChartElement = document.querySelectorAll('[data-chart="historyChart"]')[0]
  if (dashboardChartElement) {
    window.dashboardChart = createMarketHistoryChart(dashboardChartElement)
    initializeTabs()
  }
  formatAllUsdValues()
  updateAllCalculatedUsdValues()
})()


$('[chart-tab]').on('click', event => {
  var $clicked = $(event.currentTarget)

  if (!$clicked[0].classList.contains('selected')) {
    var tabs = $('[chart-tab]')
    var index = tabs.length
    while (index--) {
      removeClass(tabs[index], 'selected')
    }

    addClass($clicked[0], 'selected')
    chartToggle($clicked.find('[data-selector]').data('selector'))
  }
});

function chartToggle (selector) {
  switch (selector) {
    case 'tx_per_day': {
      window.dashboardChart.toogleNumTransactions(true)
      window.dashboardChart.toogleMarketCap(false)
      window.dashboardChart.tooglePrice(false)
      window.dashboardChart.update()
      break
    }
    case 'market-cap': {
      window.dashboardChart.toogleNumTransactions(false)
      window.dashboardChart.toogleMarketCap(true)
      window.dashboardChart.tooglePrice(false)
      window.dashboardChart.update()
      break
    }
    case 'exchange-rate': {
      window.dashboardChart.toogleNumTransactions(false)
      window.dashboardChart.toogleMarketCap(false)
      window.dashboardChart.tooglePrice(true)
      window.dashboardChart.update()
      break
    }
  }
}

function addClass($tab, className) {
  $tab.classList.add(className)
  $tab.children[0].classList.add(className)
}

function removeClass($tab, className) {
  $tab.classList.remove(className)
  $tab.children[0].classList.remove(className)
}

function initializeTabs () {
  var $tabs = $('[chart-tab]')
  var $firstTab = $tabs[0]
  addClass($firstTab, 'selected')
  chartToggle($tabs.find('[data-selector]').data('selector'))
}