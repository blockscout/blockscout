FROM node:18-alpine AS deps

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json* ./

# Install all dependencies including dev dependencies
RUN npm ci

# Start building the app
FROM node:18-alpine AS builder
WORKDIR /app

# Copy node modules and source code
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Ensure chart.js is installed (in case npm ci in deps stage didn't handle it)
RUN npm install chart.js@4 --save

# Build the Next.js application
RUN npm run build

# Production image
FROM node:18-alpine AS runner
WORKDIR /app

# Environment should be production
ENV NODE_ENV production
ENV PORT 3010

# Copy necessary files from builder
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/next.config.js ./next.config.js

# Install production dependencies only
RUN npm ci --only=production

# Expose the port
EXPOSE 3010

# Set health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3010 || exit 1

# Start the server
CMD ["npm", "start"]
