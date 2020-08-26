FROM node:alpine

COPY purpleair.js /app/purpleair.js

WORKDIR /app

RUN npm install /app

CMD ["node", "purpleair.js"]