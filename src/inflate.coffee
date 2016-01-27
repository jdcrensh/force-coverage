_ = require 'lodash'
async = require 'async'
fs = require 'fs-extra'
sf = require 'jsforce'
tooling = require 'jsforce-metadata-tools'
xml = require './xml'
logger = require './logger'
argv = require './argv'
Coverage = require './coverage'
path = require 'path'
Mustache = require 'mustache'
temp = require('temp').track()

# keep jsforce connection reference
conn = null

getDeployOpts = (extend={}) ->
  _.extend
    checkOnly: true
    rollbackOnError: true
    testLevel: 'RunLocalTests'
    ignoreWarnings: true
    username: argv.u
    password: argv.p
    loginUrl: argv.loginurl
    pollTimeout: argv.pollTimeout
    pollInterval: argv.pollInterval
  , extend

run = ->
  async.auto
    login: (done) ->
      conn = new sf.Connection loginUrl: argv.loginurl
      conn.login argv.u, argv.p, (err) ->
        done err, conn

    pkgDir: (done) ->
      temp.mkdir 'pkg', (err, res) ->
        logger.verbose "Created temporary directory: #{res}" unless err?
        done err, res

    pkgTests: ['pkgDir', (done, res) ->
      dest = path.join res.pkgDir, 'package.xml'
      xml.writePackage {}, dest, done
    ]

    pkgTestsDestruct: ['pkgDir', (done, res) ->
      dest = path.join res.pkgDir, 'destructiveChanges.xml'
      xml.writePackage ApexClass: [argv.class], dest, done
    ]

    runTests: ['pkgTests', 'pkgTestsDestruct', (done, res) ->
      logger.info 'Running tests asynchronously...'

      tooling.deployFromDirectory(res.pkgDir, getDeployOpts()).then (res) ->
        if argv.logLevel is 'verbose'
          tooling.reportDeployResult res, logger, true

        resJson = JSON.stringifyCircular res, '  '

        if res.numberComponentErrors or res.numberTestErrors
          done "Test phase failed"
        else
          done null, res
      .catch done
    ]

    parseCoverage: ['runTests', (done, res) ->
      coverage = new Coverage(res.runTests, logger, argv)
      coverage.log()
      async.setImmediate -> done null, coverage
    ]

    removeInflation: ['parseCoverage', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done if inflationRequired
      conn = res.login
      logger.warn 'Removing existing inflation...'
      conn.metadata.delete 'ApexClass', [argv.class], _.ary done, 0
    ]

    inflationClass: ['parseCoverage', (done, res) ->
      coverage = res.parseCoverage
      return async.setImmediate done unless coverage.blocksNeeded

      logger.info "Generating #{coverage.blocksNeeded * 100} lines of inflation..."

      pkg = res.pkgDir
      async.waterfall [
        (done) ->
          temp.cleanup _.ary done, 1

        (done) ->
          fp = path.join pkg, 'classes', "#{argv.class}.cls-meta.xml"
          xml.writeMetaXml 'ApexClass', fp, version: '27.0', _.ary done, 1

        (done) ->
          fp = path.join __dirname, '..', 'templates', 'CoverageInflation.cls.tmpl'
          fs.readFile fp, 'utf-8', done

        (res, done) ->
          fp = path.join pkg, 'classes', "#{argv.class}.cls"
          data =
            date: new Date()
            stats: coverage
            inflation: (i for i in [1..coverage.blocksNeeded])
          data.stats.inflationGenerated = coverage.blocksNeeded * 100
          content = Mustache.render res, data
          fs.writeFile fp, content, _.ary done, 1

        (done) ->
          fp = path.join pkg, 'package.xml'
          components = ApexClass: [argv.class]
          xml.writePackage components, fp, _.ary done, 1
      ], done
    ]

    deployInflation: ['inflationClass', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done unless inflationRequired
      pkg = res.pkgDir

      logger.info 'Deploying inflation...'

      opts = getDeployOpts checkOnly: false
      tooling.deployFromDirectory(pkg, opts).then (res) ->
        logger.info ''
        if argv.logLevel is 'verbose'
          tooling.reportDeployResult res, logger, true
        resJson = JSON.stringifyCircular res, '  '

        if res.numberComponentErrors or res.numberTestErrors
          done 'Inflation deployment failed'
        else
          cov = new Coverage(res, logger, argv)
          logger.info 'Coverage with inflation is now %d/%d (%d%%)', cov.linesCovered, cov.totalLines, cov.coveragePercent
          done null, res
      .catch done
    ]
  , (err) ->
    if err?
      logger.error err
    else
      logger.info 'Happy coding!'

module.exports = {run}
