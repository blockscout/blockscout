import { useEffect, useRef } from 'react';
import { Box } from '@chakra-ui/react';
import Chart from 'chart.js/auto';
// Register the components we need to avoid tree-shaking issues
import { 
  ArcElement,
  LineElement,
  BarElement,
  PointElement,
  BarController,
  BubbleController,
  DoughnutController,
  LineController,
  PieController,
  PolarAreaController,
  RadarController,
  ScatterController,
  CategoryScale,
  LinearScale,
  LogarithmicScale,
  RadialLinearScale,
  TimeScale,
  TimeSeriesScale,
  Decimation,
  Filler,
  Legend,
  Title,
  Tooltip
} from 'chart.js';

// Register the components to avoid tree-shaking issues
Chart.register(
  ArcElement,
  LineElement,
  BarElement,
  PointElement,
  BarController,
  BubbleController,
  DoughnutController,
  LineController,
  PieController,
  PolarAreaController,
  RadarController,
  ScatterController,
  CategoryScale,
  LinearScale,
  LogarithmicScale,
  RadialLinearScale,
  TimeScale,
  TimeSeriesScale,
  Decimation,
  Filler,
  Legend,
  Title,
  Tooltip
);

interface ChartData {
  labels: string[];
  datasets: {
    label: string;
    data: number[];
    backgroundColor?: string | string[];
    borderColor?: string;
    borderWidth?: number;
    tension?: number;
    fill?: boolean;
  }[];
}

interface ChartComponentProps {
  type: 'line' | 'bar' | 'pie' | 'doughnut';
  data: any[];
  height?: number;
  xKey?: string; // chiave per i valori dell'asse x
  yKey?: string; // chiave per i valori dell'asse y
  xLabel?: string; // etichetta per l'asse x
  yLabel?: string; // etichetta per l'asse y
  title?: string; // titolo del grafico
}

export default function ChartComponent({ 
  type, 
  data = [], 
  height = 300,
  xKey = 'date',
  yKey = 'value',
  xLabel = '',
  yLabel = '',
  title = ''
}: ChartComponentProps) {
  const chartRef = useRef<HTMLCanvasElement>(null);
  const chartInstance = useRef<Chart | null>(null);

  useEffect(() => {
    if (!chartRef.current || !data || data.length === 0) return;

    // If a chart already exists, destroy it
    if (chartInstance.current) {
      chartInstance.current.destroy();
    }

    // Process data based on chart type
    const chartData = processData(data, type, xKey, yKey);
    
    // Create new chart
    const ctx = chartRef.current.getContext('2d');
    if (ctx) {
      chartInstance.current = new Chart(ctx, {
        type,
        data: chartData,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              position: 'top',
            },
            tooltip: {
              mode: 'index',
              intersect: false,
            },
            title: title ? {
              display: true,
              text: title,
              font: {
                size: 16
              }
            } : undefined,
          },
          scales: type === 'pie' || type === 'doughnut' ? undefined : {
            x: {
              grid: {
                display: false,
              },
              title: xLabel ? {
                display: true,
                text: xLabel,
                font: {
                  size: 14
                }
              } : undefined,
            },
            y: {
              beginAtZero: true,
              grid: {
                color: 'rgba(0, 0, 0, 0.05)',
              },
              title: yLabel ? {
                display: true,
                text: yLabel,
                font: {
                  size: 14
                }
              } : undefined,
            },
          },
        },
      });
    }

    // Cleanup function
    return () => {
      if (chartInstance.current) {
        chartInstance.current.destroy();
      }
    };
  }, [data, type]);

  // Format data for Chart.js
  function processData(data: any[], chartType: string, xKey: string = 'date', yKey: string = 'value'): ChartData {
    // Gestisce diversi formati di dati in base al tipo di grafico
    
    if (chartType === 'pie' || chartType === 'doughnut') {
      return {
        labels: data.map(item => item.label || item[xKey] || ''),
        datasets: [{
          label: 'Dataset 1',
          data: data.map(item => item[yKey] || item.value || 0),
          backgroundColor: [
            'rgba(54, 162, 235, 0.7)',
            'rgba(255, 99, 132, 0.7)',
            'rgba(255, 206, 86, 0.7)',
            'rgba(75, 192, 192, 0.7)',
            'rgba(153, 102, 255, 0.7)',
            'rgba(255, 159, 64, 0.7)',
          ],
        }],
      };
    }
    
    // Per grafici a linee e barre
    return {
      labels: data.map(item => {
        // Gestisce date nei vari formati
        if (item[xKey] && (typeof item[xKey] === 'string' && item[xKey].includes('-'))) {
          try {
            return new Date(item[xKey]).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' });
          } catch (e) {
            return item[xKey];
          }
        }
        return item[xKey] || item.label || '';
      }),
      datasets: [{
        label: yLabel || 'Valore',
        data: data.map(item => item[yKey] || item.value || 0),
        backgroundColor: chartType === 'line' ? 'rgba(75, 192, 192, 0.3)' : 'rgba(54, 162, 235, 0.7)',
        borderColor: chartType === 'line' ? 'rgba(75, 192, 192, 1)' : 'rgba(54, 162, 235, 1)',
        borderWidth: 2,
        tension: chartType === 'line' ? 0.4 : 0,
        fill: chartType === 'line',
      }],
    };
  }

  return (
    <Box width="100%" height={`${height}px`}>
      <canvas ref={chartRef} />
    </Box>
  );
}
