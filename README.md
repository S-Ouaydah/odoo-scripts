# Odoo Scripts Repository

A collection of useful scripts for managing Odoo environments.

## Description

This repository contains a variety of utility scripts for Odoo developers and administrators. The main focus is on simplifying common tasks and automating repetitive tasks.

## Installation
Simply Run the initialization script:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/S-Ouaydah/odoo-scripts/refs/heads/expansion/server_init.sh)"
```

## Usage

After installation, you'll have several commands available starting with `odoo-`. Here are some core functionalities:

- `odoo-install`: Install Odoo Instance (Supports 15.0 - 19.0)
- `odoo-list`: List all installed Odoo instances
- `odoo-upgrade`: Upgrade a specific Odoo module
- `odoo-restart`: Restart a specific Odoo instance
- `odoo-server-details`: Display server details for a specific Odoo instance
- `odoo-logs`: View live logs for a specific Odoo instance
- `odoo-ssl`: Setup SSL for a specific Odoo instance
- `odoo-config`: Edit global configuration

## Configuration

The scripts use a global configuration file located at `/etc/odoo-scripts.conf`. You can edit this file using `odoo-config` to change settings like the default installation directory.

## Ideas for Future Enhancements

- Add backup functionality

## Contribution Guidelines

If you'd like to contribute to this project, feel free to fork this repository and submit pull requests for any improvements or new features you'd like to see.