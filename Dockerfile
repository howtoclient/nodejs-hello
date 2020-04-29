FROM node:12.13-alpine
WORKDIR /usr/src/app
COPY . .
COPY package*.json ./
RUN npm ci
CMD ["npm","start"]