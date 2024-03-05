# Kafka Cluster Setup Repository

This repository provides scripts and configurations to set up a Kafka cluster with Zookeeper, supporting both Kerberos and SCRAM authentication methods. It includes systemd files for managing Kafka services and Ansible commands for automated installation.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Usage](#usage)
- [Configuration](#configuration)
- [Systemd Files](#systemd-files)
- [Ansible Commands](#ansible-commands)


## Prerequisites

Ensure the following prerequisites are met before setting up the Kafka cluster:

- Java installed on all nodes.
- Kerberos server (for Kerberos authentication).
- Access to necessary Kafka and Zookeeper binaries.

## Repository Structure

The repository is organized as follows:

- `scripts/`: Contains scripts for setting up Kafka and Zookeeper with Kerberos and SCRAM authentication.
- `config/`: Configuration files for Kafka and Zookeeper.
- `systemd/`: Systemd service files for managing Kafka services.
- `ansible/`: Ansible playbook and roles for automated installation.

## Usage

Follow the instructions in the respective sections to set up Kafka with the desired authentication method.


