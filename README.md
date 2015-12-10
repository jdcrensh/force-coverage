# Force.com test coverage tooling

[![npm version](https://img.shields.io/npm/v/force-coverage.svg?style=flat-square)](https://www.npmjs.com/package/force-coverage) [![Dependency Status](https://img.shields.io/david/jdcrensh/node-force-coverage.svg?style=flat-square)](https://david-dm.org/jdcrensh/node-force-coverage)

## Installation

    npm install -g force-coverage

## Coverage Auto-Inflation

*Disclaimer: Inflated coverage goes against Salesforce development best practices and should be avoided 99% of the time.*

    force-inflate -u <username> -p <password><security token>

Run org tests and calculates the remaining lines that must otherwise be covered to reach target % overall coverage. `CoverageInflation` is generated to contain the calculated amount of inflation, which is then deployed. The class is compiled against API v27.0 so that it may contain its own test method.

Inflation formula:

    (linesCovered - totalLines * targetPercentage) / (targetPercentage - 1) = inflatedLines

Re-run as needed (i.e. when **actual** coverage increases) to decrease/eliminate the inflation.

When overall coverage exceeds the target % without inflation, `CoverageInflation` is removed from the org.

### Target coverage %

    force-inflate ... --target 0.8

Default: 0.76

### Inflation class name

Inflation can be divided among multiple classes. This can be useful in cases where the target % is unattainable due to the Apex class size limit of 100,000 characters.

Example for a target of 90% coverage:

    force-inflate ... --target 0.3 --class CoverageInflation1
    force-inflate ... --target 0.3 --class CoverageInflation2
    force-inflate ... --target 0.3 --class CoverageInflation3

Default: `CoverageInflation`
