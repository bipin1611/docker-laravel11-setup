# NPM production
FROM node AS npm-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js /var/www/html/
COPY resources /var/www/html/resources/
COPY public /var/www/html/public/

RUN npm i 
RUN npm run build

# Nginx production
FROM nginx:1.27

COPY .docker/nginx/nginx_template_prod.conf /etc/nginx/conf.d/default.conf
COPY --chown=www-data --from=npm-build /var/www/html/public/ /var/www/html/public/ 
COPY --chown=www-data . /var/www/html