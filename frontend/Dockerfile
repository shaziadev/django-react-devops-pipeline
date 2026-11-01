# Build context is the REPOSITORY ROOT (so this image can include nginx/):
#   docker build -f frontend/Dockerfile .

# ---- Stage 1: build the React app ----------------------------------------
FROM node:20-alpine AS build

WORKDIR /app
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ .
RUN npm run build

# ---- Stage 2: Nginx serves the static build and proxies /api to Django ---
FROM nginx:1.27-alpine AS runtime

# The official image runs envsubst on /etc/nginx/templates/*.template at
# startup, so ${DOMAIN} in the config is filled in from the container env.
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80 443
