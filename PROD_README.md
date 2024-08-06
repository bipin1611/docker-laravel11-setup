# Docker Laravel Setup

This guide will help you configure a Laravel project in a `PRODUCTION ENVIRONMENT` using Docker. It includes steps for both new and existing projects.

Refer to the [README.md](/README.md) guide for local deployment.

## Prerequisites

- Before deploying to a production server, you must compile and run the project on your local system. Follow the steps for local environment setup.

## Docker Compose Setup for Production Environment

### 1. **Create a Dockerfile `prod.Dockerfile` inside the `.docker/php` folder.**

Here is a sample Dockerfile:

```Dockerfile
# Composer dependency
FROM composer AS composer-build

WORKDIR /var/www/html

COPY composer.json composer.lock /var/www/html/

RUN mkdir -p /var/www/html/database/{factories,seeds} \
    && composer install --no-dev --prefer-dist --no-scripts --no-autoloader --no-progress --ignore-platform-reqs

# NPM dependency
FROM node AS npm-build

WORKDIR /var/www/html

COPY package.json package-lock.json vite.config.js /var/www/html/
COPY resources /var/www/html/resources/
COPY public /var/www/html/public/

RUN npm i
RUN npm run build

# PHP setup
FROM php:8.2-fpm

WORKDIR /var/www/html

RUN apt-get update \
    && apt-get install --quiet --yes --no-install-recommends \
        libzip-dev \
        unzip \
    && docker-php-ext-install opcache zip pdo pdo_mysql \
    && pecl install -o -f redis \
    && docker-php-ext-enable redis

# Use default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Override with custom opcache settings
COPY .docker/php/opcache.ini $PHP_INI_DIR/conf.d/
COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --chown=www-data --from=composer-build /var/www/html/vendor/ /var/www/html/vendor/
COPY --chown=www-data --from=npm-build /var/www/html/public/ /var/www/html/public/
COPY --chown=www-data . /var/www/html

RUN composer dump -o \
    && composer check-platform-reqs \
    && rm -f /usr/bin/composer
```

### 2. **Generate the PHP production build image**

Run the following command:

```sh
docker build -t docker4laravel-php -f .docker/php/prod.Dockerfile .
```

> Note: If you change anything inside this file, you need to rebuild the image using the same command.

> Note: Replace `docker4laravel-php` with your project's naming convention.

Check the `opcache.ini` configuration as well.

### 3. **Generate the NGINX production build image**

Create an Nginx configuration file (`nginx_template_prod.conf`) inside the `.docker/nginx` folder (create the folder if it does not exist):

Here is a sample configuration file for production:

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name _;
    root /var/www/html/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

**Create a Dockerfile for the NGINX production build image:**

```Dockerfile
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
```

### 4. **Generate the NGINX build image**

Run the following command:

```sh
docker build -t docker4laravel-nginx -f .docker/nginx/prod.Dockerfile .
```

> Note: If you change anything inside this file, you need to rebuild the image using the same command.

### Additional Checks for Production Build

To verify the production build is working, you need to modify the `docker-compose.yml` file by replacing the PHP and web service images. Refer to the example `.yml` file below:

```yaml
version: '3'

services:
  php:
    image: docker4laravel-php:latest
    build: 
      context: .
    volumes:
      - ./.env:/var/www/html/.env
    networks:
      - laravel_network

  web:
    image: docker4laravel-nginx:latest
    working_dir: /var/www/html
    volumes:
      - ./:/var/www/html
    ports:
      - "80:80"
    networks:
      - laravel_network

  db:
    image: mysql
    environment:
      MYSQL_ALLOW_EMPTY_PASSWORD: "yes"
      MYSQL_ROOT_HOST: "%"
      MYSQL_ROOT_PASSWORD: "${DB_PASSWORD}"
      MYSQL_DATABASE: "${DB_DATABASE}"
      MYSQL_PASSWORD: "${DB_PASSWORD}"
    volumes:
      - mysqldata:/var/lib/mysql
    networks:
      - laravel_network

  node:
    image: node
    user: node
    working_dir: /assets
    volumes:
      - ./:/assets
    command: npm run dev
    networks:
      - laravel_network

  redis:
    image: redis
    volumes:
      - redisdata:/data
    networks:
      - laravel_network

volumes:
  mysqldata:
  redisdata:

networks:
  laravel_network:
```

> Note: Pay attention to the services' images for PHP and web, as well as the PHP service volumes.

### Finally, run the following command to apply the changes:

```sh
docker-compose down && docker-compose up -d
```

## Notes

- When you change any configuration, you need to rebuild the production image using the associated image command, and then restart your application with `docker-compose down && docker-compose up -d`.
- **Existing Projects**: If you are setting up an existing project, clone your repository into the working directory and skip the `composer create-project` command.
- **Environment Variables**: Ensure your `.env` file has the correct database and other environment settings.

## Publishing Images to Docker Hub

Generate the PHP build image:

```sh
docker build -t example/docker4laravel-php:0.0.1 -f .docker/php/prod.Dockerfile .
docker push example/docker4laravel-php:0.0.1
```

Similarly, for the NGINX image:

```sh
docker build -t example/docker4laravel-nginx:0.0.1 -f .docker/nginx/prod.Dockerfile .
docker push example/docker4laravel-nginx:0.0.1
```

## Additional Useful Commands for Optimization

- To check Docker's performance: `docker stats`
- To run performance tests on the Docker container with concurrent requests: `ab -n 500 -c 100 http://localhost/`
  - `-n` indicates the number of requests
  - `-c` represents the number of concurrent requests

## Contributing

Feel free to open issues or submit pull requests for improvements. Happy coding!
