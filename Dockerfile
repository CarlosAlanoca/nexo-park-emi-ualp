FROM node:22-alpine
RUN apk add --no-cache tesseract-ocr tesseract-ocr-data-eng postgresql-client
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci --omit=dev
COPY backend ./
COPY frontend /app/frontend
ENV FRONTEND_DIR=/app/frontend
EXPOSE 4000
CMD ["npm", "start"]
