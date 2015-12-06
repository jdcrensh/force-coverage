# Force.com test coverage tooling

Salesforce code coverage auto-inflation.

## Installation

    npm install -g force-coverage

## Usage

### Inflation
    force-coverage -u <username> -p <password><security token>

#### Target coverage

Defaults to 75%, can be configured using the command line option `--targetCoverage`, e.g. for 80%: `--targetCoverage 0.8`
