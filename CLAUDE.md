# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby on Rails application that synchronizes financial transaction data from SimpleFIN to self-hosted Maybe instances. The app runs as a Docker container alongside Maybe and provides a web interface for linking SimpleFIN accounts to Maybe accounts, with automatic or manual transaction synchronization.

## Development Commands

### Setup and Dependencies
- `bin/setup` - Initial setup (installs dependencies, prepares database)
- `bundle install` - Install Ruby dependencies
- `bin/rails db:prepare` - Prepare database (create, migrate, seed)

### Development Server
- `bin/dev` - Start development server with Foreman (includes Rails server and Tailwind CSS watcher)
- `bin/rails server` - Start Rails server only
- `bin/rails tailwindcss:watch` - Watch and compile Tailwind CSS

### Testing
- `bin/rails test` - Run test suite
- `bin/rails test:system` - Run system tests

### Database
- `bin/rails db:migrate` - Run database migrations
- `bin/rails db:seed` - Seed database
- `bin/rails db:reset` - Reset database (drop, create, migrate, seed)
- `bin/rails console` - Open Rails console

### Assets
- `rake assets:precompile` - Precompile assets for production

## Architecture

### Core Components

**Models:**
- `Account` - SimpleFIN accounts stored locally
- `Linkage` - Links SimpleFIN accounts to Maybe accounts
- `Mortgage` - Mortgage/loan accounts with special transaction handling
- `Setting` - Application configuration

**Key Services:**
- `MaybeClient` (`app/lib/maybe_client.rb`) - Direct PostgreSQL client for Maybe database operations
- `SimplefinClient` (`app/lib/simplefin_client.rb`) - HTTP client for SimpleFIN API
- `MaybeClientService` - Service layer for Maybe operations

**Background Jobs:**
- Uses GoodJob for background processing
- `SyncLinkageJob` - Syncs individual account linkages
- `RunAllSyncsJob` - Runs all configured syncs
- `MortgageTransactionJob` - Handles mortgage interest/escrow transactions

### Database Integration

The app connects directly to Maybe's PostgreSQL database and handles two schema versions:
- New schema (migration >= 20250413141446): `entries`, `valuations`, `transactions` tables
- Legacy schema: `account_entries`, `account_valuations`, `account_transactions` tables

### Web Interface

Rails MVC structure with:
- Linkages management (main interface)
- Account management
- Mortgage/loan configuration
- Settings and API testing

## Key Configuration

- Environment variables configured via Docker Compose
- PostgreSQL connection to Maybe database required
- SimpleFIN API credentials needed
- GoodJob for background job processing
- Tailwind CSS for styling

## Development Notes

- The app is designed to run alongside Maybe in Docker
- Direct database access to Maybe's PostgreSQL instance
- Scheduled sync jobs configurable via cron syntax
- Mortgage transactions include interest and escrow offsetting