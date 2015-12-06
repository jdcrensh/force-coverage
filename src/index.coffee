async = require 'async'
_ = require 'lodash'
fs = require 'fs-extra'
events = require 'events'
colors = require 'colors'
sf = require 'jsforce'
tooling = require 'jsforce-metadata-tools'
xml = require './xml'
logger = require './logger'
argv = require './argv'
path = require 'path'
Mustache = require 'mustache'

require('./lodash')(_)

coverageClassName = 'CoverageInflation'

deployOpts =
  checkOnly: true
  rollbackOnError: true
  testLevel: 'RunLocalTests'
  ignoreWarnings: true
  username: argv.u
  password: argv.p
  loginUrl: argv.loginurl
  pollTimeout: 600 * 1000
  pollInterval: 5 * 1000

conn = new sf.Connection loginUrl: argv.loginurl

getCoverage = (deployResult) ->
  coverage = deployResult.details.runTestResult.codeCoverage
  totalLines = _.sum coverage, 'numLocations'
  linesNotCovered = _.sum coverage, 'numLocationsNotCovered'

  linesCovered = totalLines - linesNotCovered
  coveragePercent = parseFloat(linesCovered / totalLines * 100).toFixed 2

  targetLineCoverage = Math.ceil totalLines * argv.targetCoverage
  coverageRequired = Math.max 0, targetLineCoverage - linesCovered

  inflationRequired = coverageRequired * 4

  return {
    totalLines
    linesCovered
    linesNotCovered
    coveragePercent
    targetLineCoverage
    coverageRequired
    inflationRequired
  }

JSON.stringifyCircular = (obj, indent) ->
  cache = []
  JSON.stringify obj, (key, value) ->
    return if !!~cache.indexOf value
    cache.push value if _.isObject value
    value
  , indent

inflate = ->
  async.auto
    login: (done) ->
      conn.login argv.u, argv.p, (err) ->
        done err, conn

    pkgDelete: (done) ->
      fs.remove 'pkg', done

    pkgTests: ['pkgDelete', (done) ->
      dest = path.join 'pkg', 'package.xml'
      xml.writePackage {}, dest, done
    ]

    pkgTestsDestruct: ['pkgDelete', (done) ->
      dest = path.join 'pkg', 'destructiveChanges.xml'
      xml.writePackage ApexClass: [coverageClassName], dest, done
    ]

    runTests: ['pkgTests', 'pkgTestsDestruct', (done) ->
      logger.info 'Running tests asynchronously...'
      # res = fs.readJsonSync 'results.json'
      # return async.setImmediate -> done null, res
      tooling.deployFromDirectory('pkg', deployOpts).then (res) ->
        logger.info ''
        if argv.loglevel is 'verbose'
          tooling.reportDeployResult res, logger, true
        resJson = JSON.stringifyCircular res, '  '

        fs.writeFileSync 'results.json', resJson
        if res.numberComponentErrors or res.numberTestErrors
          done "Test phase failed"
        else
          done null, res
      .catch done
    ]

    checkRequireCoverage: ['runTests', (done, res) ->
      warning = res.runTests.details.runTestResult.codeCoverageWarnings?.message
      async.setImmediate -> done null, {warning}
    ]

    isCoverageRequired: ['checkRequireCoverage', (done, res) ->
      async.setImmediate -> done null, res.checkRequireCoverage.warning?
    ]

    parseCoverage: ['isCoverageRequired', (done, res) ->
      if res.isCoverageRequired # received coverage warning?
        logger.warn res.checkRequireCoverage.warning

      logger.info 'Calculating additional coverage required...'
      cov = getCoverage res.runTests
      logger.info 'Code coverage from tests: %d/%d (%d%%)', cov.linesCovered, cov.totalLines, cov.coveragePercent

      if not cov.coverageRequired
        logger.info 'Inflation is not needed! Keep it up!'
      else
        logger.warn 'Org is %s lines short of %d%% coverage', cov.coverageRequired, parseInt argv.targetCoverage * 100

      async.setImmediate -> done null, cov
    ]

    removeInflation: ['parseCoverage', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done if inflationRequired
      conn = res.login
      logger.warn 'Removing existing inflation...'
      conn.metadata.delete 'ApexClass', ['CoverageInflation'], _.ary done, 0
    ]

    inflationClass: ['parseCoverage', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done unless inflationRequired

      n = Math.ceil inflationRequired / 100
      logger.info "Generating #{n * 100} lines of inflation..."

      async.waterfall [
        (done) ->
          fp = path.join 'pkg', 'classes', "#{coverageClassName}.cls-meta.xml"
          xml.writeMetaXml 'ApexClass', fp, version: '27.0', _.ary done, 1

        (done) ->
          fp = path.join 'templates', 'CoverageInflation.cls.tmpl'
          fs.readFile fp, 'utf-8', done

        (res, done) ->
          fp = path.join 'pkg', 'classes', "#{coverageClassName}.cls"
          content = Mustache.render res, inflation: (i for i in [1..n])
          fs.writeFile fp, content, _.ary done, 1

        (done) ->
          fp = path.join 'pkg', 'package.xml'
          {version} = argv
          components = ApexClass: [coverageClassName]
          xml.writePackage components, fp, _.ary done, 1

        (done) ->
          fp = path.join 'pkg', 'destructiveChanges.xml'
          fs.remove fp, done

      ], done
    ]

    deployInflation: ['inflationClass', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done unless inflationRequired

      logger.info 'Deploying inflation...'

      opts = _.extend deployOpts, checkOnly: false
      tooling.deployFromDirectory('pkg', opts).then (res) ->
        logger.info ''
        if argv.loglevel is 'verbose'
          tooling.reportDeployResult res, logger, argv.loglevel is 'verbose'
        resJson = JSON.stringifyCircular res, '  '

        fs.writeFileSync 'results.json', resJson
        if res.numberComponentErrors or res.numberTestErrors
          done 'Inflation deployment failed'
        else
          done null, res

        cov = getCoverage res
        logger.info 'Coverage with inflation is now %d/%d (%d%%)', cov.linesCovered, cov.totalLines, cov.coveragePercent
      .catch done
    ]

    clean: ['deployInflation', 'removeInflation', (done) ->
      fs.remove 'pkg', done
    ]
  , (err) ->
    logger.error err if err?
    logger.info 'done'

module.exports = {inflate}
