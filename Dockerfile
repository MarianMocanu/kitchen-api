FROM node:24.16.0-alpine

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY src ./src

EXPOSE 3000

CMD ["npm", "run", "start"]