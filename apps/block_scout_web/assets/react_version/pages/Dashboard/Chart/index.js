import React from 'react'
import styled from 'styled-components'
import { Line } from 'react-chartjs-2'
import numeral from 'numeral'

import { formatUsdValue } from '../../../libs/currency'
import { useChartData } from '../hooks'

export default () => {
  const [priceData, marketCapData] = useChartData();
  return (
    <ChartContainer>
      <Line
        height={130}
        data={{
          datasets: [{
            label: 'Price',
            yAxisID: 'price',
            data: priceData,
            fill: false,
            pointRadius: 0,
            backgroundColor: '#bf9cff',
            borderColor: '#bf9cff',
            lineTension: 0
          }, {
            label: 'Market Cap',
            yAxisID: 'marketCap',
            data: marketCapData,
            fill: false,
            pointRadius: 0,
            backgroundColor: '#87e1a9',
            borderColor: '#87e1a9',
            lineTension: 0
          }]
        }}
        options={{
          legend: {
            display: false
          },
          scales: {
            xAxes: [{
              gridLines: {
                display: false,
                drawBorder: false
              },
              type: 'time',
              time: {
                unit: 'day',
                stepSize: 14
              },
              ticks: {
                fontColor: '#fff'
              }
            }],
            yAxes: [{
              id: 'price',
              gridLines: {
                display: false,
                drawBorder: false
              },
              ticks: {
                beginAtZero: true,
                callback: (value, index, values) => `$${numeral(value).format('0,0.00')}`,
                maxTicksLimit: 4,
                fontColor: '#fff'
              }
            }, {
              id: 'marketCap',
              position: 'right',
              gridLines: {
                display: false,
                drawBorder: false
              },
              ticks: {
                callback: (value, index, values) => '',
                maxTicksLimit: 6,
                drawOnChartArea: false
              }
            }]
          },
          tooltips: {
            mode: 'index',
            intersect: false,
            callbacks: {
              label: ({ datasetIndex, yLabel }, { datasets }) => {
                const label = datasets[datasetIndex].label
                if (datasets[datasetIndex].yAxisID === 'price') {
                  return `${label}: ${formatUsdValue(yLabel)}`
                } else if (datasets[datasetIndex].yAxisID === 'marketCap') {
                  return `${label}: ${formatUsdValue(yLabel)}`
                } else {
                  return yLabel
                }
              }
            }
          }
        }}
      />
      <Legend>
        {[
          { title: 'Price', value: '$0.014236 USD', color: '#bf9cff' },
          { title: 'Market Cap', value: '$3,134,205 USD', color: '#87e1a9' },
        ].map(item =>
          <LegendItem>
            <LegendMarker style={{ backgroundColor: item.color }} />
            <span>{item.title}</span>
            <span>{item.value}</span>
          </LegendItem>
        )}
      </Legend>
    </ChartContainer>
  )
}

const ChartContainer = styled.div`
  width: 330px;
  margin-top: 30px;
`

const Legend = styled.div`
  display: flex;
  flex-direction: row;
  margin-top: 20px;
`

const LegendItem = styled.div`
  flex: 1;
  display: flex;
  flex-direction: column;
  position: relative;
  padding: 3px 12px;
  color: #fff;
`

const LegendMarker = styled.div`
  border-radius: 2px;
  height: 100%;
  left: 0;
  position: absolute;
  top: 0;
  width: 4px;
`
