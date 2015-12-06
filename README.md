# Force.com test coverage tooling

[![npm version](https://img.shields.io/npm/v/force-coverage.svg?style=flat-square)](https://www.npmjs.com/package/force-coverage) [![Dependency Status](https://img.shields.io/david/jdcrensh/node-force-coverage.svg?style=flat-square)](https://david-dm.org/jdcrensh/node-force-coverage)

## Installation

    npm install -g force-coverage

## Coverage Auto-Inflation

*Disclaimer: Inflated coverage goes against Salesforce development best practices and should be avoided 99% of the time.*

    force-inflate -u <username> -p <password><security token>

Run org tests and calculates the remaining lines that must otherwise be covered to reach 75% overall coverage. This number is multiplied by four, giving us the lines of inflation required. `CoverageInflation.cls` is generated to contain the inflation, which is then deployed.

If overall coverage exceeds 75% without generated inflation, `CoverageInflation.cls` is removed from the org.

Re-run as needed (i.e. when **actual** coverage increases) to regenerate, or eliminate, the inflation code.

### Target coverage

Defaults to 75%; configurable with `--targetCoverage`

    force-inflate ... --targetCoverage 0.8`
