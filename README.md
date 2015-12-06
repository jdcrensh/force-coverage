# Force.com test coverage tooling

[![npm version](https://img.shields.io/npm/v/force-coverage.svg?style=flat-square)](https://www.npmjs.com/package/force-coverage) [![Dependency Status](https://img.shields.io/david/jdcrensh/node-force-coverage.svg?style=flat-square)](https://david-dm.org/jdcrensh/node-force-coverage)

## Installation

    npm install -g force-coverage

## Auto-Inflation

Disclaimer: Coverage inflation goes against Salesforce development best practices and should be avoided 99% of the time.

    force-inflate -u <username> -p <password><security token>

Runs org tests then calculates the number of remaining lines that must be covered to reach 75% overall coverage. This number is multiplied by four to give the lines of inflation that would be required instead. A class is generated--CoverageInflation.cls--containing the amount of inflation required, then deployed.

### Target coverage

Defaults to 75%, configurable with `--targetCoverage`

    force-inflate ... --targetCoverage 0.8`
