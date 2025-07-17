# syntax = docker/dockerfile:1

FROM registry.docker.com/library/ruby:3.3.7-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    curl libvips libyaml-dev postgresql-client tzdata

# Set production environment
ARG APP_VERSION
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    APP_VERSION=${APP_VERSION}
    
# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update && \
    apt-get install --no-install-recommends -y build-essential libpq-dev git pkg-config

# Install application gems
COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle lock --add-platform aarch64-linux x86_64-linux && bundle install

RUN rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

RUN bundle exec bootsnap precompile --gemfile -j 0

# Copy application code
COPY . .

# Update Gemfile.lock again after copying application code
RUN bundle lock --add-platform aarch64-linux x86_64-linux

# Ensure start.sh is executable
RUN chmod +x /rails/start.sh

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 0 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Clean up installation packages to reduce image size
RUN rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

EXPOSE 3000

# Start the Rails server
CMD ["bash", "/rails/start.sh"]