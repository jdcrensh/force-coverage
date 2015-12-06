# Force.com test coverage tooling

[![npm version](https://img.shields.io/npm/v/force-coverage.svg?style=flat-square)](https://www.npmjs.com/package/force-coverage) [![Dependency Status](https://img.shields.io/david/jdcrensh/node-force-coverage.svg?style=flat-square)](https://david-dm.org/jdcrensh/node-force-coverage)

Salesforce code coverage auto-inflation.

## Installation

    npm install -g force-coverage

## Usage

### Inflation
    force-coverage -u <username> -p <password><security token>

#### Target coverage

Defaults to 75%, can be configured using the command line option `--targetCoverage`, e.g. for 80%: `--targetCoverage 0.8`
