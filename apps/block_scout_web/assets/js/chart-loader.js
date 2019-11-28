import $ from 'jquery'

import { formatAllUsdValues, updateAllCalculatedUsdValues } from './lib/currency'
import { createMarketHistoryChart } from './lib/market_history_chart'

const checkExist = setInterval(() => {
    const el = $('[data-chart="marketHistoryChart"]')[0]
    if (el) {
        clearInterval(checkExist)
        createMarketHistoryChart(el, true)
        formatAllUsdValues()
        updateAllCalculatedUsdValues()
    }
}, 100);
