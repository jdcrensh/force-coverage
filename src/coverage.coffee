_ = require 'lodash'

class Coverage

  constructor: (deployResult, @logger, @argv={}) ->
    coverageWarning = @coverageWarning deployResult
    if coverageWarning # received coverage warning?
      @logger.warn coverageWarning

    @logger.info 'Calculating additional coverage required...'
    {codeCoverage} = deployResult.details.runTestResult

    @totalLines = _.sum codeCoverage, 'numLocations'
    @linesNotCovered = _.sum codeCoverage, 'numLocationsNotCovered'
    @linesCovered = @totalLines - @linesNotCovered

    @coveragePercent = @percentCovered()
    @coverageMissing = @coverageDeficit().max(0).ceil()
    @inflationRequired = @inflationNeeded().max(0).ceil()

    @targetPercentCoverage = parseFloat(@argv.target * 100).toFixed 2

  coverageWarning: (deployResult) ->
    deployResult.details.runTestResult.codeCoverageWarnings?.message

  inflationNeeded: ->
    (@linesCovered - @totalLines * @argv.target) / (@argv.target - 1)

  coverageDeficit: ->
    @totalLines * @argv.target - @linesCovered

  percentCovered: ->
    parseFloat @linesCovered / @totalLines * 100

  log: ->
    @logger.info 'Code coverage from tests: %d/%d (%d%%)', @linesCovered, @totalLines, @coveragePercent.toFixed 2

    if not @inflationRequired
      @logger.info 'Inflation is not needed! Keep it up!'
    else
      @logger.warn 'Overall coverage is %d lines short of %d%%', @coverageMissing, @targetPercentCoverage
      @logger.warn '%d lines of inflation is needed for the target to be met', @inflationRequired
      @logger.verbose '(%d - %d * %d) / (%d - 1) = %d', @linesCovered, @totalLines, @argv.target, @argv.target, @inflationRequired

module.exports = Coverage
