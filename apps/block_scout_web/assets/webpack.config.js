const path = require('path');
const TerserJSPlugin = require('terser-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const { ContextReplacementPlugin } = require('webpack');
const glob = require("glob");

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
    optimization: {
      minimizer: [new TerserJSPlugin({}), new OptimizeCSSAssetsPlugin({})],
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
    plugins: [
      new MiniCssExtractPlugin({
        filename: '../css/app.css'
      }),
      new CopyWebpackPlugin([{ from: 'static/', to: '../' }]),
      new ContextReplacementPlugin(/moment[\/\\]locale$/, /en/)
    ]
  }

const viewScripts = glob.sync('./js/view_specific/**/*.js').map(transpileViewScript);

module.exports = viewScripts.concat(appJs);
