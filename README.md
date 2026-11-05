# Autoclean plugin

**Autoclean** is a **Roundcube** plugin, that allows the user to configure automatic cleaning of old messages from folders.

## Screenshot

![Screenshot](scrn.jpg)

## Requirements

* [Roundcube](https://www.roundcube.net) (Recommended: 1.6.20 or greater)
* [dovecot](https://) - server IMAP (Recommended: 2.4.x or greater)
* permissions to run **doveadm**, or:
* access to the Dovecot doveadm HTTP API
* access to **cron**

* composer (recommended)
* PHP 8.1 or greater (recommended)

## Installation

Please follow these steps and adapt them to your distribution if necessary.

1. Place this plugin folder into `./plugins` directory of Roundcube
2. You can do so either using git clone or `composer`, for which there is `composer.json` (replace `/opt/roundcubemail` with your rouncdube install location):

    ```
    # cd /opt/roundcubemail
    # composer require black75/autoclean:dev-master
    ```
3. After that, make sure the newly installed plugin is enabled by adding it
to Roundcube's plugin list. (`./config/config.inc.php`)

    ```php
    $config['plugins'] = [
      // other plugins...
        'autoclean',
       ];
   ```
   Appending `, 'autoclean'` to the list of plugins will suffice.


### Debian

   * If using the Debian roundcube package, the related config file is `/etc/roundcube/config.inc.php`.
   * You can also manually install plugins to: `/var/lib/roundcube/plugins`.

### Cron

4. You can use crontab to autoclean folders users periodically.


   Just specify an entry like:

   ```bash
   0 1 * * * _user_ _ROUNDCUBE_FOLDER_/plugins/autoclean/autoclean.sh
   ```

   If not using the dovecot doveadm API, `_user_` must have permission to run `doveadm`


## Settings

In case you need to edit the default settings, you may copy `config.inc.php.dist` to `config.inc.php` and edit setings as desired in the latter file, which will override defaults.

   ```
   # cd /opt/roundcubemail/plugins/autoclean
   # cp config.inc.php.dist config.inc.php
   ```

### Using with dovecot doveadm API:




| Option | Description |
| --- | --- |
| `$config['autoclean_dovecot_api_url']` | Full doveadm HTTP API endpoint. Example: `https://dovecot.example.org:8443/doveadm/v1`. |
| `$config['autoclean_dovecot_api_key']` | API key matching Dovecot's `doveadm_api_key`. Both API settings are required. |

### Using with doveadm:

| Option | Description |
| --- | --- |
| `$config['autoclean_dovecot_server']` | Dovecot server IP address or hostname. The connection uses SSH. Set it to `null` for local Dovecot. This is ignored when the HTTP API is configured. |


### Other options

| Option | Description |
| --- | --- |
| `$config['autoclean_interval']` | Day interval array. |
| `$config['autoclean_trash_folder']` | System Trash folder. Default: `Trash`. |
| `$config['autoclean_extra_clean']` | Additional mandatory folders configured by the administrator and cleaned for all users. |


### Dovecot API configuration

Dovecot configuration files are usually located in `/etc/dovecot/conf.d`

Example file: `/etc/dovecot/conf.d/10-doveadm.conf` (Works with Dovecot 2.4.x):

```
doveadm_api_key  = <YOUR_API_KEY>

service doveadm {
  unix_listener doveadm-server {
    user = vmail
  }

  inet_listener doveadm {
    port = 2425
  }

  inet_listener http {
    port = 8443
    ssl = yes
    #listen = 127.0.0.1 ::1
  }

}

```

See also: https://doc.dovecot.org/latest/core/admin/doveadm.html#http-api

> IMPORTANT
> Make sure the doveadm ports are firewalled to allow only trusted access.

NOTE: PHP validates SSL certificates by default. If you enable ssl, the hostname in the SSL certificate 
must match the name given in the URL. (e.g. If will not work if you connect as "https://localhost" but the 
certificate contains the actual name.)


## License

This software distributed under the terms of the GNU General Public License as published by the Free Software Foundation

Further details on the GPL license can be found at http://www.gnu.org/licenses/gpl.html

By contributing to **Autoclean plugin**, authors release their contributed work under this license

### Author

Wojciech Bielec, Poland

### Currently maintained by
* [Black75](https://bitbucket.com/Black75/autoclean)
