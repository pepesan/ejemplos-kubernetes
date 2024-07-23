FROM node:22.5.1-bullseye

RUN apt update

RUN apt upgrade -y

#ponemos el directorio base de node
WORKDIR /app/

#copiamos los contenidos de la carpeta /app (donde he metido el app.js y el package.json)
COPY ./app/* ./

#creamos la carpeta de uploads para las subidas de archivos
RUN mkdir uploads

#hacemos el npm install para los node_modules
RUN npm install

#lanzamos node
CMD ["node", "app.js"]