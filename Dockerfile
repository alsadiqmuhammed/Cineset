FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
# npm can exit 0 after a failed download, so confirm the packages actually load.
RUN npm ci --omit=dev && node -e "require('pg');require('nodemailer');require('@anthropic-ai/sdk')" && npm cache clean --force
COPY server.js ./
COPY lib ./lib
COPY public ./public
RUN mkdir -p data uploads
EXPOSE 3000
CMD ["node","server.js"]
