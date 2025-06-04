# Changed node version, ensure it's compatible
FROM node:16.17.0-alpine as builder
WORKDIR /app
COPY ./package.json .
COPY ./package-lock.json .
RUN npm install
COPY . .

# Declare the build argument that will be passed in via `docker build --build-arg TMDB_V3_API_KEY=your_key`
ARG TMDB_V3_API_KEY

# Set the environment variable for Vite using the build argument
# Use the ARG here
ENV VITE_APP_TMDB_V3_API_KEY=${TMDB_V3_API_KEY}
# This is fine as it's not a secret
ENV VITE_APP_API_ENDPOINT_URL="https://api.themoviedb.org/3"

RUN npm run build

# --- Production Stage ---
FROM nginx:stable-alpine
WORKDIR /usr/share/nginx/html
# Ensures the directory is clean before copying
RUN rm -rf ./*
COPY --from=builder /app/dist .
EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]
