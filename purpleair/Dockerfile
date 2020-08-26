FROM node:alpine

COPY package.json /app/package.json

WORKDIR /app

RUN npm install /app

COPY purpleair.js /app/purpleair.js

CMD ["node", "purpleair.js"]