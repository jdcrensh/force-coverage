async = require 'async'
_ = require 'lodash'
fs = require 'fs-extra'
sf = require 'jsforce'
tooling = require 'jsforce-metadata-tools'
xml = require './xml'
logger = require './logger'
argv = require './argv'
path = require 'path'
Mustache = require 'mustache'
temp = require('temp').track()

require('./lodash')(_)

deployOpts =
  checkOnly: true
  rollbackOnError: true
  testLevel: 'RunLocalTests'
  ignoreWarnings: true
  username: argv.u
  password: argv.p
  loginUrl: argv.loginurl
  pollTimeout: argv.pollTimeout
  pollInterval: argv.pollInterval

conn = new sf.Connection loginUrl: argv.loginurl

Number::ceil = -> Math.ceil this
Number::max = (n) -> Math.max n, this

numInflationNeeded = (a, b, c) ->
  x = (a - b * c) / (c - 1)
  x.max(0).ceil()

numCoverageMissing = (a, b, c) ->
  x = b * c - a
  x.max(0).ceil()

percentLinesCovered = (a, b) ->
  parseFloat(a / b * 100).toFixed 2

coverageDetails = (deployResult) ->
  coverage = deployResult.details.runTestResult.codeCoverage

  totalLines = _.sum coverage, 'numLocations'
  linesNotCovered = _.sum coverage, 'numLocationsNotCovered'
  linesCovered = totalLines - linesNotCovered

  coveragePercent = percentLinesCovered linesCovered, totalLines
  coverageMissing = numCoverageMissing linesCovered, totalLines, argv.target
  inflationRequired = numInflationNeeded linesCovered, totalLines, argv.target

  targetPercentCoverage = parseFloat(argv.target * 100).toFixed 2

  return {
    totalLines
    linesNotCovered
    linesCovered
    coveragePercent
    coverageMissing
    inflationRequired
    targetPercentCoverage
  }

JSON.stringifyCircular = (obj, indent) ->
  cache = []
  JSON.stringify obj, (key, value) ->
    return if !!~cache.indexOf value
    cache.push value if _.isObject value
    value
  , indent

module.exports = ->
  async.auto
    login: (done) ->
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

      tooling.deployFromDirectory(res.pkgDir, deployOpts).then (res) ->
        if argv.logLevel is 'verbose'
          tooling.reportDeployResult res, logger, true

        resJson = JSON.stringifyCircular res, '  '

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
      cov = coverageDetails res.runTests
      logger.info 'Code coverage from tests: %d/%d (%d%%)', cov.linesCovered, cov.totalLines, cov.coveragePercent

      if not cov.inflationRequired
        logger.info 'Inflation is not needed! Keep it up!'
      else
        logger.warn 'Overall coverage is %d lines short of %d%%', cov.coverageMissing, cov.targetPercentCoverage
        logger.warn '%d lines of inflation is needed for the target to be met', cov.inflationRequired
        logger.verbose '(%d - %d * %d) / (%d - 1) = %d', cov.linesCovered, cov.totalLines, argv.target, argv.target, cov.inflationRequired

      async.setImmediate -> done null, cov
    ]

    removeInflation: ['parseCoverage', (done, res) ->
      {inflationRequired} = res.parseCoverage
      return async.setImmediate done if inflationRequired
      conn = res.login
      logger.warn 'Removing existing inflation...'
      conn.metadata.delete 'ApexClass', [argv.class], _.ary done, 0
    ]

    inflationClass: ['parseCoverage', (done, res) ->
      lines = res.parseCoverage.inflationRequired
      return async.setImmediate done unless lines

      blocks = Math.ceil lines / 100
      logger.info "Generating #{blocks * 100} lines of inflation..."

      pkg = res.pkgDir
      async.waterfall [
        (done) ->
          temp.cleanup _.ary done, 1

        (done) ->
          fp = path.join pkg, 'classes', "#{argv.class}.cls-meta.xml"
          xml.writeMetaXml 'ApexClass', fp, version: '27.0', _.ary done, 1

        (done) ->
          fp = path.join 'templates', 'CoverageInflation.cls.tmpl'
          fs.readFile fp, 'utf-8', done

        (res, done) ->
          fp = path.join pkg, 'classes', "#{argv.class}.cls"
          content = Mustache.render res, inflation: (i for i in [1..blocks])
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

      opts = _.extend deployOpts, checkOnly: false
      tooling.deployFromDirectory(pkg, opts).then (res) ->
        logger.info ''
        if argv.logLevel is 'verbose'
          tooling.reportDeployResult res, logger, true
        resJson = JSON.stringifyCircular res, '  '

        if res.numberComponentErrors or res.numberTestErrors
          done 'Inflation deployment failed'
        else
          cov = coverageDetails res
          logger.info 'Coverage with inflation is now %d/%d (%d%%)', cov.linesCovered, cov.totalLines, cov.coveragePercent
          done null, res
      .catch done
    ]
  , (err) ->
    if err?
      logger.error err
    else
      logger.info 'Happy coding!'
