FROM node:24-alpine AS build

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY index.html gestion-quiz.html main.js style.css vite.config.js questions_*.js ./
COPY public/ ./public/
RUN npm run build

FROM nginx:stable-alpine

RUN apk upgrade --no-cache libexpat zlib

COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist/ /usr/share/nginx/html/
