FROM elixir:1.14-alpine

# Install build dependencies
RUN apk add --no-cache build-base git postgresql-client npm

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy the mix files
COPY mix.exs mix.lock ./

# Set build ENV
ARG MIX_ENV=prod
ENV MIX_ENV=${MIX_ENV}

# Install dependencies
RUN mix deps.get

# Copy the rest of the application code
COPY . .


# Make init script executable
RUN chmod +x ./init.sh

# Expose port
EXPOSE 4000

# Set runtime ENV
ENV LANG=C.UTF-8
ENV PHX_SERVER=true

# Start the application
CMD ["./init.sh"]