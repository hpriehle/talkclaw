FROM node:20-alpine

# System tools for agent capabilities
RUN apk add --no-cache openssh-client git curl jq bash

# Install Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# App
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npx tsc

# Session data
RUN mkdir -p /data/sessions

EXPOSE 3000

CMD ["node", "dist/index.js"]
