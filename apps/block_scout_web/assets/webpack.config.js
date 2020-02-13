const path = require('path');
const ExtractTextPlugin = require('extract-text-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const glob = require("glob");
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
        },
      ]
    }
  }
};

const appJs =
  {
    entry: './js/app.js',
    output: {
      filename: 'app.js',
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
        },
        {
          test: /\.scss$/,
          use: ExtractTextPlugin.extract({
            use: [{
              loader: "css-loader"
            }, {
              loader: "postcss-loader"
            }, {
              loader: "sass-loader",
              options: {
                precision: 8,
                includePaths: [
                  'node_modules/bootstrap/scss',
                  'node_modules/@fortawesome/fontawesome-free/scss'
                ]
              }
            }],
            fallback: 'style-loader'
          })
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
    plugins: [
      new ExtractTextPlugin('../css/app.css'),
      new CopyWebpackPlugin([{ from: 'static/', to: '../' }]),
      new webpack.DefinePlugin({
        'process.env.PROVIDER_URL': JSON.stringify(process.env.PROVIDER_URL),
        'process.env.CONSENSUS_ADDRESS': JSON.stringify(process.env.CONSENSUS_ADDRESS)
      })
    ]
  }

const viewScripts = glob.sync('./js/view_specific/**/*.js').map(transpileViewScript);

module.exports = viewScripts.concat(appJs);
