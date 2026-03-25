# BUILD STAGE
FROM node:20-alpine AS build
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./
RUN npm install

# Copy source files
COPY . .
RUN npm run build

# PRODUCTION STAGE
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
