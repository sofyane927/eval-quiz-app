FROM node:24-alpine3.24 AS deps

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM alpine:3.24

RUN apk upgrade --no-cache zlib libcrypto3 libssl3 \
    && apk add --no-cache libstdc++ ca-certificates \
    && addgroup -S -g 1000 node \
    && adduser -S -u 1000 -G node node

WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /usr/local/bin/node /usr/local/bin/node
COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./

USER node
EXPOSE 3007
CMD ["node", "server.js"]
