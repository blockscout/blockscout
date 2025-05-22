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
}

export default function ChartComponent({ type, data = [], height = 300 }: ChartComponentProps) {
  const chartRef = useRef<HTMLCanvasElement>(null);
  const chartInstance = useRef<Chart | null>(null);

  useEffect(() => {
    if (!chartRef.current || !data || data.length === 0) return;

    // If a chart already exists, destroy it
    if (chartInstance.current) {
      chartInstance.current.destroy();
    }

    // Process data based on chart type
    const chartData = processData(data, type);
    
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
          },
          scales: type === 'pie' || type === 'doughnut' ? undefined : {
            x: {
              grid: {
                display: false,
              },
            },
            y: {
              beginAtZero: true,
              grid: {
                color: 'rgba(0, 0, 0, 0.05)',
              },
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
  function processData(data: any[], chartType: string): ChartData {
    // This is a simplified example - in a real app you'd adapt this to your actual data structure
    
    // For demo purposes, let's assume data is either:
    // 1. For line/bar: [{date: '2023-01-01', value: 123}, ...]
    // 2. For pie/doughnut: [{label: 'Category A', value: 123}, ...]
    
    if (chartType === 'pie' || chartType === 'doughnut') {
      return {
        labels: data.map(item => item.label || ''),
        datasets: [{
          label: 'Dataset 1', // Adding the required label property
          data: data.map(item => item.value || 0),
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
    
    // For line and bar charts
    return {
      labels: data.map(item => {
        // Format date if it exists
        if (item.date) {
          return new Date(item.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
        }
        return item.label || '';
      }),
      datasets: [{
        label: 'Value',
        data: data.map(item => item.value || 0),
        backgroundColor: 'rgba(54, 162, 235, 0.3)',
        borderColor: 'rgba(54, 162, 235, 1)',
        borderWidth: 2,
        tension: 0.4,
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
