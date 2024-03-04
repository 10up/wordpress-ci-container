# WordPress CI Container

> WordPress continuous integration Docker container with composer, NPM, and other common build tools for PHP projects

## Packages and Tools

**A selection of packages and tools installed:**

- composer
- curl
- gh (Github CLI)
- git
- glap (Gitlab CLI)
- mysql-client
- nodejs / npm, nvm for management
- php
- rsync
- shellcheck
- clamscan
- kubectl
- aws-cli
- azure-cli
- docker-cli
- wp-cli
- terminus
- yamllint

**npm packages installed:**
- grunt-cli
- gulp-cli
- bower
- yarn
- lighthouse
- serverless
- firebase-tools
- cypress

Node and npm are managed by the `build/install-node.sh` script.

## Customize Package and Tool Configurations

The tools and packages installed in this image can be customized using environment variables. See `entrypoint.sh` to see these in action.

### Git

`GIT_USER_NAME` and `GIT_USER_EMAIL` set the `user.name` and `user.email` git global configuration values, for use with git-based deploys.

### Composer

Custom composer configurations can be specified via the `COMPOSER_CONFIG` variable. The configuration will be applied inside the container by running the following command: `composer config -g "$COMPOSER_CONFIG"`. E.g. In order to authenticate with GitHub, set the `COMPOSER_CONFIG` variable as follow:

```bash
COMPOSER_CONFIG="github-oauth.github.com token"
```

The token can be securely passed using secrets or CI/CD variables, depending on platform.

### Build Cache

The `BUILD_CACHE_DIR` can be used to specify a cache directory for `composer` and `npm` in order to improve build times. Default directory paths are provided.

### Root SSH Key

The variables `PRIVATE_KEY` and `PUBLIC_KEY` can be used to create a custom public and private key for the root user.

### Terminus

The Terminus token can be set via the `TERMINUS_TOKEN` variable, for use with the Pantheon managed hosting platform.

## CI/CD scripts

The `scripts` directory contains useful tools that can help test applications and be used in CI/CD pipelines. All scripts are copied in the `/custom-scripts` directory inside the Docker image and added to the user `PATH` for easy access. The included scripts are:

- `all-scripts`: Runs all the included and additional custom scripts inside the `/custom-scripts` directory.
- `php-syntax`: Checks the syntax of all PHP files inside the `workdir`
- `virus-scan`: Runs `clamscan` against the `workdir`.
- `slack-message`: Sends Slack notifications via webhook.

### Using slack-message

The script allows customizable messages using the following flags: `[-u webhook_url -m text_message] -p pre_text_message -c message_color -a author_name -l author_link -i author_icon -t title -n title_link`. `-u` and `-m` are the only mandatory parameters.

### Adding custom scripts

Additional scripts can be added inside the `/custom-scripts` directory for pipeline use. All scripts with `.sh` extension inside the `/custom-scripts` directory can be executed by the `all-scripts` script.

### Custom-scripts | PHP Syntax - Debug flag for detailed logs

> In a recent patch for performance enhacnement, stdout and verbose logging withing the php-syntax checking processes was removed. For reference, kindly review [PR#23](https://github.com/10up/wordpress-ci-container/pull/23).

For php-syntax checks detailed logs could be enabled via:

1. Setting a `IS_DEBUG_ENABLED` environment variable within your container.
2. Putting a flag file, "_IS_DEBUG_ENABLED_" with a contents set to `true` within your container's root directory. **_(Not-recommended)_**

This will enable detailed logs in php-syntax checking for debugging, trading off time for logging with increased build time for your environment.

## Node Version

For convenience, `nvm` is installed to easily manage the node version in the CI container. To install a different node version from CI just add a step to execute the command: `nvm install <version>`; you can also execute the command from within a build script.

[![Support Level](https://img.shields.io/badge/support-stable-blue.svg)](#support-level)

## Support Level

**Stable:** 10up is not planning to develop any new features for this, but will still respond to bug reports and security concerns. We welcome PRs, but any that include new features should be small and easy to integrate and should not include breaking changes. We otherwise intend to keep this tested up to the most recent version of WordPress.

## Like what you see?

<p align="center">
<a href="http://10up.com/contact/"><img src="https://10up.com/uploads/2016/10/10up-Github-Banner.png" width="850"></a>
</p>
