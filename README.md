# Docker Laravel Setup

This guide will help you set up a Laravel project in a **local environment** using Docker. It includes steps for both new and existing projects.

Check the [PROD_README.md](./PROD_README.md) guide for production deployment.

## Prerequisites

- **Windows Users**: Install WSL2 and Docker Desktop.
  - Install WSL2: Run the following command in your command prompt:
    ```sh
    wsl --install
    ```
  - Install Docker Desktop: [Download Docker Desktop](https://www.docker.com/products/docker-desktop) and follow the installation instructions.

## Setting Up a New Laravel Project

To set up a new Laravel project, follow these steps:

1. **Open your Linux terminal** (e.g., Ubuntu via WSL if you are using Windows).
2. **Navigate to your working directory**:
   ```sh
   cd /var/www
   ```
3. **Install Laravel using the Composer Docker image**:
   ```sh
   docker run --rm -v $(pwd):/app -w /app composer composer create-project laravel/laravel docker-demo
   ```
   > Note: Replace `docker-demo` with your desired project name.

### Explanation of the Docker Run Command

- `--rm`: Removes the container after the command is executed to prevent cache from being generated.
- `composer`: The `composer` Docker image.
- `-v $(pwd):/app`: Mounts the current directory to `/app` in the Docker container.
- `-w /app`: Sets the working directory inside the container to `/app`.

## Docker Compose Setup

1. **Create a docker-compose.yml file in the root folder of your Laravel project.**
2. **Identify the services needed for your Laravel project.** Typically, you will use services such as PHP, MySQL, Nginx (for the web server), Redis (for caching), and Node.js.

Here's a sample `docker-compose.yml` configuration to set up Laravel with Docker:

```yaml
version: '3'

services:
  php:
    image: php
    environment:
      APP_DEBUG: "true"
      APP_KEY: "base64:7m52bDzgCHH+WZ/djiXfX0tfw7Lq4SkO46TuJJUW68I=" # replace your APP_KEY
    build: 
      context: .
    volumes:
      - ./:/var/www/html
    networks:
          - laravel_network

  web:
    image: nginx:1.27
    working_dir: /var/www/html
    volumes:
      - ./:/var/www/html
      - .docker/nginx/nginx_template_local.conf:/etc/nginx/conf.d/default.conf
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

### Dockerfile for PHP Service

Create a `Dockerfile` in the project root folder. You can also mention additional dependencies such as PHP extensions.

```Dockerfile
FROM php:8.2-fpm

# Install dependencies
RUN apt-get update && apt-get install -y \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd \
    && docker-php-ext-install pdo pdo_mysql zip exif pcntl \
    && docker-php-source delete \
    && pecl install -o -f redis \
    && docker-php-ext-enable redis
    
# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy existing application directory contents
COPY . /var/www/html

# Install dependencies
RUN composer install

# Copy existing application directory permissions
COPY --chown=www-data:www-data . /var/www/html

EXPOSE 9000
CMD ["php-fpm"]
```

### Nginx Configuration

Create an Nginx configuration file (`nginx_template_local.conf`) inside the `.docker/nginx` folder (create the folder if it does not exist):

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
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

### Running Docker Containers

1. **Build and Run Containers**:
   ```sh
   docker-compose up -d --build
   ```

2. **Generate Laravel Application Key**:
   ```sh
   docker exec -it <php_container_name> bash
   php artisan key:generate
   ```

3. **Install Node Dependencies**:
   ```sh
   docker-compose run --rm node npm install
   ```

### Access Your Application

Open your web browser and go to `http://localhost`. Your Laravel application should now be running.

## Tips

- **Check the status of services**: Use the `docker-compose ps` command.
- If you change any configuration inside the `Dockerfile` or `.conf` file, you need to rebuild the Docker image by running:
  ```sh
  docker-compose up -d --build
  ```

## Notes

- **Existing Projects**: If you are setting up an existing project, clone your repository into the working directory and skip the `composer create-project` command.
- **Environment Variables**: Make sure to set your `.env` file with the correct database and other environment settings.

## Contributing

Feel free to open issues or submit pull requests for improvements. Happy coding!