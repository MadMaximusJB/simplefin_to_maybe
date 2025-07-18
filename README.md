# SimpleFIN to Maybe

![home page](docs/assets/images/sftm-home.png)

A project to synchronize transaction data from [SimpleFIN](https://beta-bridge.simplefin.org/) to a self-hosted [Maybe](https://github.com/maybe-finance/maybe) instance, set up as a docker container.

## Premise

The project is intended to be deployed alongside a self-hosted Maybe instance.  It provides an interface to save an "Account Linkage" between your SimpleFIN accounts and your Maybe accounts.  

Once linked, you can define a cron schedule for automatic synchronization of transactions and account balances, or synchronize manually:

![schedule](docs/assets/images/schedule-settings.png)

## Installation Instructions

[Self-hosted with Docker](docs/docker.md)

## Configuration Instructions

[Web App Configuration](docs/config.md) - Get started in the GUI

[Mortgage & Loans Configuration](docs/mortgage-sync.md) - Insert Interest (and optionally Escrow) offsetting transactions

## Recommendations

~~In Maybe, manually sync your accounts frequently.~~

~~Also refresh (F5) your browser often.~~

Manually syncing has been removed from the web UI.

However, you can still execute syncs from the `rails console` - [details here](docs/manual_sync.md)

## To Do

- [x] Transactions
- [x] Balances
- [X] Docker Compose
- [X] Web UI
- [X] Loan Interest & Escrow Offsets
- [X] Securities/Trades/Holdings
- [ ] Property Valuations
- [ ] More...?
