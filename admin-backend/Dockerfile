FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files first (for better layer caching)
COPY package.json package-lock.json* ./

# Install dependencies
RUN npm ci --only=production

# Copy the rest of the application code
COPY . .

# Create logs directory and set permissions
RUN mkdir -p /app/logs && chmod -R 755 /app/logs

# Expose the port
EXPOSE 4010

# Set health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4010/health || exit 1

# Start the server
CMD ["npm", "run", "start:prod"]
