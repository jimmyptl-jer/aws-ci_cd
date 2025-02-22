# Stage 1: Build the application using the official Node.js image
FROM node:23 AS build

# Set the working directory inside the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to the container
COPY ./package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application source code to the working directory
COPY . .

# Build the React app using Vite
RUN npm run build

# Stage 2: Serve the built files using Nginx
FROM nginx:1.27.4

# Copy a custom Nginx configuration file, if needed, to configure how Nginx serves your app
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the built application files from the build stage to Nginx's default HTML directory
COPY --from=build /usr/src/app/build/ /usr/share/nginx/html

# Expose port 80 to allow traffic to the Nginx server
EXPOSE 80

# By default, Nginx will run as the container's CMD to serve the built app
# Start Nginx server
CMD ["nginx", "-g", "daemon off;"]