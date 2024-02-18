# Use an official Node.js 14 image
FROM node:14 as builder

WORKDIR /app

# Copy package.json and package-lock.json for chat-builder
COPY assets/chat-builder/package.json assets/chat-builder/package-lock.json ./assets/chat-builder/
WORKDIR /app/assets/chat-builder
RUN npm install

# Install microbundle-crl as a local dependency
RUN npm install microbundle-crl

# Build chat-builder
RUN npm run build

# Reset the working directory to /app
WORKDIR /app

# Copy package.json and package-lock.json for chat-widget
COPY assets/chat-widget/package.json assets/chat-widget/package-lock.json ./assets/chat-widget/
WORKDIR /app/assets/chat-widget
RUN npm install

# Install microbundle-crl as a local dependency
RUN npm install microbundle-crl

# Build chat-widget
RUN npm run build

ARG MIX_ENV=dev
# Switch to a new stage for Papercups development
FROM elixir:1.10 as dev

ENV MIX_HOME=/opt/mix

WORKDIR /usr/src/app
ENV LANG=C.UTF-8

# Install necessary dependencies for Papercups development
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
    apt-get install -y nodejs fswatch && \
    mix local.hex --force && \
    mix local.rebar --force

# declared here since they are required at build and run time.
ENV DATABASE_URL="ecto://postgres:postgres@localhost/chat_api" SECRET_KEY_BASE="" MIX_ENV=dev FROM_ADDRESS="" MAILGUN_API_KEY=""

# Copy Papercups project files
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

COPY assets/package.json assets/package-lock.json ./assets/
WORKDIR /usr/src/app
RUN npm install

# Temporary fix because of https://github.com/facebook/create-react-app/issues/8413
ENV GENERATE_SOURCEMAP=false

COPY priv priv
COPY assets assets
WORKDIR /usr/src/app/assets
RUN npm run build

COPY lib lib
RUN mix do compile
RUN mix phx.digest

COPY docker-entrypoint-dev.sh entrypoint.sh
CMD ["/usr/src/app/entrypoint.sh"]
