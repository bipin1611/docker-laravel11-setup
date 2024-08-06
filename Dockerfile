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
  