# Wordpress deployment with Docker Compose

Easy WordPress deploy with Docker and Docker Compose.

With this project you can quickly run the following:

- [WordPress and WP CLI](https://hub.docker.com/_/wordpress/)
- [phpMyAdmin](https://hub.docker.com/r/phpmyadmin/phpmyadmin/)
- [MySQL](https://hub.docker.com/_/mysql/)

Contents:

- [Requirements](#requirements)
- [Configuration](#configuration)
- [Installation](#installation)
- [Usage](#usage)

## Requirements

Make sure you have the latest versions of **Docker** and **Docker Compose** installed on your machine.

Clone this repository or copy the files from this repository into a new folder. In the **docker-compose.yml** file you may change the database from MySQL to MariaDB or the php version.

At the time of this writting wordpress version was 5.2.1. Actual version requirements are described in https://wordpress.org/about/requirements/.



Make sure to [add your user to the `docker` group](https://docs.docker.com/install/linux/linux-postinstall/#manage-docker-as-a-non-root-user) when using Linux.

## Configuration

Copy env.sample file to .env and change sensible data with your custom configuration: MySQL root password, and WordPress database name, user and password.

## Installation

Open a terminal and `cd` to the folder in which `docker-compose.yml` is saved and run:

```
docker-compose up
```

This creates two new folders next to your `docker-compose.yml` file.

* `db` – used for database related stuff:
  * `backup` - database backups
  * `data` - database actual data
  * `dump` - database init sql file for restoring purposes
* `wp-app` – the location of your WordPress application

The containers are now built and running. You should be able to access the WordPress installation with the url set in your VIRTUAL_HOST setting.

For convenience you may add a new entry into your hosts file.

## Usage

### Starting containers

You can start the containers with the `up` command in daemon mode (by adding `-d` as an argument) or by using the `start` command:

```
docker-compose start
```

### Stopping containers

```
docker-compose stop
```


### Project from existing source

Copy the `docker-compose.yml` file into a new directory. In the directory you create two folders:

* `db/dump` – here you add the database dump
* `wp-app` – here you copy your existing WordPress code


You can now use the `up` command:

```
docker-compose up -d
```

This will create the containers and populate the database with the given dump. Don't forget to remove any previous data from `db/data` and `wp-app`

### Creating database dumps

It's run everyday at 3 am. Database backups are saved at `db/dump` and rotated periodically.

It can be configured changed labels in mysqlbackup service (inside docker-compose.yml)


### WP CLI

The docker compose configuration also provides a service for using the [WordPress CLI](https://developer.wordpress.org/cli/commands/).

Sample command to install WordPress:

```
docker-compose run --rm wpcli core install --url=http://localhost --title=test --admin_user=admin --admin_email=test@example.com
```

Or to list installed plugins:

```
docker-compose run --rm wpcli plugin list
```

For an easier usage you may consider adding an alias for the CLI:

```
alias wp="docker-compose run --rm wp-cli"
```

This way you can use the CLI command above as follows:

```
wp plugin list
```

### phpMyAdmin

You should define a subdomain as `phpmyadmin.mydomain.com` to access phpMyAdmin after starting the containers.

The default username is `root`, and the password is the same as supplied in the `.env` file.