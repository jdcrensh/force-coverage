# Force.com test coverage tooling

[![npm version](https://img.shields.io/npm/v/force-coverage.svg)](https://www.npmjs.com/package/force-coverage)
[![Dependency Status](https://img.shields.io/david/jdcrensh/node-force-coverage.svg)](https://david-dm.org/jdcrensh/node-force-coverage)
[![Coverage Status](https://coveralls.io/repos/jdcrensh/node-force-coverage/badge.svg?branch=master&service=github)](https://coveralls.io/github/jdcrensh/node-force-coverage?branch=master)
[![Build Status](https://travis-ci.org/jdcrensh/node-force-coverage.svg?branch=master)](https://travis-ci.org/jdcrensh/node-force-coverage)

## Installation

    npm install -g force-coverage

## Coverage Auto-Inflation

*Disclaimer: Inflated coverage goes against Salesforce development best practices and should be avoided 99% of the time.*

    force-inflate -u <username> -p <password><security token> -l <login url>

Run org tests and calculates the remaining lines that must otherwise be covered to reach target % overall coverage. `CoverageInflation` is generated to contain the calculated amount of inflation, which is then deployed. The class is compiled against API v27.0 so that it may contain its own test method.

Inflation formula:

    (linesCovered - totalLines * targetPercentage) / (targetPercentage - 1) = inflatedLines

Re-run as needed (i.e. when **actual** coverage increases) to decrease/eliminate the inflation.

When overall coverage exceeds the target % without inflation, `CoverageInflation` is removed from the org.

### Target coverage %

    force-inflate ... --target 0.8

Default: `0.76`
