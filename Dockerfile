# Use an updated and stable version of Node.js (e.g., Node 18)
FROM node:18-alpine

# Set working directory to /usr/src/goof
WORKDIR /usr/src/goof

# Copy the current directory contents into the container
COPY . .

# Install dependencies
RUN npm install

# Optional: Update npm to the latest version
RUN npm install -g npm@latest

# Expose ports (application port and debugging port)
EXPOSE 3001
EXPOSE 9229

# Start the application
ENTRYPOINT ["npm", "start"]
