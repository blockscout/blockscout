const path = require('path')
const TerserJSPlugin = require('terser-webpack-plugin')
const MiniCssExtractPlugin = require('mini-css-extract-plugin')
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin')
const CopyWebpackPlugin = require('copy-webpack-plugin')
const { ContextReplacementPlugin } = require('webpack')
const glob = require('glob')
const webpack = require('webpack')

function transpileViewScript(file) {
  return {
    entry: file,
    output: {
      filename: file.replace('./js/view_specific/', ''),
      path: path.resolve(__dirname, '../priv/static/js')
    },
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        }
      ]
    }
  }
};

const jsOptimizationParams = {
  parallel: true
}

const dropzoneJs = {
  entry: {
    dropzone: './js/lib/dropzone.js',
  },
  output: {
    filename: '[name].min.js',
    path: path.resolve(__dirname, '../priv/static/js')
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [
          MiniCssExtractPlugin.loader,
          {
            loader: 'css-loader',
          }
        ]
      }
    ]
  },
  optimization: {
    minimizer: [
      new TerserJSPlugin(jsOptimizationParams),
    ]
  }
}

const appJs =
  {
    entry: {
      'app': './js/app.js',
      'stakes': './js/pages/stakes.js',
      'chart-loader': './js/chart-loader.js',
      'chain': './js/pages/chain.js',
      'blocks': './js/pages/blocks.js',
      'address': './js/pages/address.js',
      'address-transactions': './js/pages/address/transactions.js',
      'address-token-transfers': './js/pages/address/token_transfers.js',
      'address-coin-balances': './js/pages/address/coin_balances.js',
      'address-internal-transactions': './js/pages/address/internal_transactions.js',
      'address-logs': './js/pages/address/logs.js',
      'address-validations': './js/pages/address/validations.js',
      'validated-transactions': './js/pages/transactions.js',
      'pending-transactions': './js/pages/pending_transactions.js',
      'transaction': './js/pages/transaction.js',
      'verification-form': './js/pages/verification_form.js',
      'token-counters': './js/pages/token_counters.js',
      'token-transfers': './js/pages/token/token_transfers.js',
      'admin-tasks': './js/pages/admin/tasks.js',
      'token-contract': './js/pages/token_contract.js',
      'smart-contract-helpers': './js/lib/smart_contract/index.js',
      'token-transfers-toggle': './js/lib/token_transfers_toggle.js',
      'try-api': './js/lib/try_api.js',
      'try-eth-api': './js/lib/try_eth_api.js',
      'async-listing-load': './js/lib/async_listing_load',
      'non-critical': './css/non-critical.scss',
      'main-page': './css/main-page.scss',
      'staking': './css/stakes.scss',
      'tokens': './js/pages/token/search.js',
      'text-ad': './js/lib/text_ad.js',
      'banner': './js/lib/banner.js',
      'autocomplete': './js/lib/autocomplete.js',
      'search-results': './js/pages/search-results/search.js',
      'token-overview': './js/pages/token/overview.js',
      'export-csv': './css/export-csv.scss',
      'datepicker': './js/lib/datepicker.js'
    },
    output: {
      filename: '[name].js',
      path: path.resolve(__dirname, '../priv/static/js')
    },
    optimization: {
      minimizer: [new TerserJSPlugin(jsOptimizationParams), new CssMinimizerPlugin()],
    },
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
        {
          test: /\.scss$/,
          use: [
            MiniCssExtractPlugin.loader,
            {
              loader: 'css-loader'
            }, {
              loader: 'postcss-loader'
            }, {
              loader: 'sass-loader',
              options: {
                sassOptions: {
                  precision: 8,
                  includePaths: [
                    'node_modules/bootstrap/scss',
                    'node_modules/@fortawesome/fontawesome-free/scss'
                  ]
                }
              }
            }
          ]
        }, {
          test: /\.(svg|ttf|eot|woff|woff2)$/,
          use: {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: '../fonts/',
              publicPath: '../fonts/'
            }
          }
        }
      ]
    },
    resolve: {
      fallback: {
        "os": require.resolve("os-browserify/browser"),
        "https": require.resolve("https-browserify"),
        "http": require.resolve("stream-http"),
        "crypto": require.resolve("crypto-browserify"),
        "util": require.resolve("util/"),
        "stream": require.resolve("stream-browserify"),
        "assert": require.resolve("assert/"),
      }
    },
    plugins: [
      new MiniCssExtractPlugin({
        filename: '../css/[name].css'
      }),
      new CopyWebpackPlugin(
        {
          patterns: [
            { from: 'static/', to: '../' }
          ]
        }
      ),
      new ContextReplacementPlugin(/moment[\/\\]locale$/, /en/),
      new webpack.DefinePlugin({
        'process.env.SOCKET_ROOT': JSON.stringify(process.env.SOCKET_ROOT),
        'process.env.NETWORK_PATH': JSON.stringify(process.env.NETWORK_PATH),
        'process.env.CHAIN_ID': JSON.stringify(process.env.CHAIN_ID),
        'process.env.JSON_RPC': JSON.stringify(process.env.JSON_RPC),
        'process.env.SUBNETWORK': JSON.stringify(process.env.SUBNETWORK),
        'process.env.COIN_NAME': JSON.stringify(process.env.COIN_NAME)
      }),
      new webpack.ProvidePlugin({
        process: 'process/browser',
        Buffer: ['buffer', 'Buffer'],
      }),
    ]
  }

const viewScripts = glob.sync('./js/view_specific/**/*.js').map(transpileViewScript)

module.exports = viewScripts.concat(appJs, dropzoneJs)
