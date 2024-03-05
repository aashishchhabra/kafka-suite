# Kafka Operations Script

This script is designed to simplify Kafka operations by setting up authentication and executing various operations against a Kafka cluster.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Operations](#operations)
- [Examples](#examples)

## Prerequisites

Before using this script, ensure you have the following prerequisites:

- Kafka installed on your system
- `kafka-topics.sh` and `kafka-acls.sh` commands available in your system PATH or provide the Kafka installation path when prompted.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/aashishchhabra/kafka-suite.git
   cd kafka-suite
2. Ensure execute permissions for the script:

   ```bash
   chmod +x kafka_operations.sh

## Operations
This script supports the following operations:

List Topics: Lists all topics on the Kafka cluster.
Describe Topics: Describes a specific topic on the Kafka cluster.
List ACLs: Lists ACLs (Access Control Lists) on the Kafka cluster.

## Examples
### Example 1: List Topics

   ```bash
   ./kafka_operations.sh
   ```
Follow the prompts and select the operation "list topics" to see a list of all topics on the Kafka cluster.

### Example 2: Describe Topic

   ```bash
   ./kafka_operations.sh
   ```
Follow the prompts, select the operation "describe topics," and provide the topic name when prompted to describe a specific topic.

### Example 3: List ACLs

   ```bash
   ./kafka_operations.sh
   ```
Follow the prompts and select the operation "list acls" to see a list of ACLs on the Kafka cluster.




