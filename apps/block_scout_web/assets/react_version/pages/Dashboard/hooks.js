import { useState, useEffect } from 'react'
import axios from 'axios'
import humps from 'humps'

function getPriceData(marketHistoryData) {
  const data = marketHistoryData.map(({ date, closingPrice }) => ({ x: date, y: closingPrice }))
  return data
}

function getMarketCapData(marketHistoryData, availableSupply) {
  const data = marketHistoryData.map(({ date, closingPrice }) => {
    const supply = (availableSupply !== null && typeof availableSupply === 'object')
      ? availableSupply[date]
      : availableSupply
    return { x: date, y: closingPrice * supply }
  })
  return data
}

export const useChartData = () => {
  const [priceData, setPriceData] = useState([])
  const [marketCapData, setMarketCapData] = useState([])
  useEffect(() => {
    async function getChartData() {
      const { data } = await axios.get('/market_history_chart?type=JSON', {
        responseType: 'json',
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      const availableSupply = JSON.parse(data.supply_data)
      const marketHistoryData = humps.camelizeKeys(JSON.parse(data.history_data))
      setPriceData(getPriceData(marketHistoryData))
      setMarketCapData(getMarketCapData(marketHistoryData, availableSupply))
    }
    getChartData()
  }, [])
  return [priceData, marketCapData]
}
