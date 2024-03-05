#!/bin/bash

ROOT_DIR=$(pwd)

# Function to display help documentation
function display_help() {
    echo "Usage: $0"
    echo "  - Prompts for bootstrap server, port, authentication type, and operation."
    echo ""
    echo "Description:"
    echo "  This script sets up Kafka authentication based on the provided parameters and executes"
    echo "  the requested operation against the specified Kafka bootstrap server."
    echo ""
    echo "Required Inputs:"
    echo "  - Bootstrap Server: The Kafka bootstrap server to connect to. It can be an IPv4 address"
    echo "                      or a valid fully qualified domain name (FQDN)."
    echo "  - Bootstrap Port:   The port number for the Kafka bootstrap server."
    echo "  - Authentication Type: 'kerberos' or 'scram' for Kerberos or SCRAM authentication."
    echo ""
    echo "Available Operations:"
    echo "  - list topics:     List all topics on the Kafka cluster."
    echo "  - describe topics: Describe a specific topic on the Kafka cluster."
    echo "  - list acls:       List ACLs (Access Control Lists) on the Kafka cluster."
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "    - Prompts for bootstrap server, port, authentication type, and operation."
    echo ""
    echo "  $0"
    echo "    - Bootstrap Server: kafka.example.com"
    echo "    - Bootstrap Port:   9092"
    echo "    - Authentication Type: kerberos"
    echo "    - Operation: list topics"
    echo "    - Sets up Kerberos authentication and lists all topics on the Kafka cluster."
    exit 1
}

# Function to validate IPv4 address or FQDN
function validate_bootstrap_server() {
    local input=$1

    # Check if the input is an IPv4 address
    if [[ $input =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi

    # Check if the input is a valid FQDN
    if [[ $input =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi

    return 1
}

# Function to check if a command is available
function is_command_available() {
    command -v "$1" > /dev/null 2>&1
}

# Function to setup authentication
function setup_authentication() {
    local auth_type=$1

    case "$auth_type" in
        "kerberos")
            echo "Setting up Kerberos authentication..."

            # Assuming these files are located in the same directory as the script
            export jaas_file="$ROOT_DIR/auth/kerberos/jaas.conf"
            export client_properties_file="$ROOT_DIR/auth/kerberos/client.properties"
            export keytab_file="$ROOT_DIR/auth/kerberos/kafka.keytab"
            export KAFKA_OPTS="-Djava.security.auth.login.config=$jaas_file"

            # Add your Kerberos setup commands here
            # For example:
            # kinit -kt "$keytab_file" "$kerberos_principal"

            ;;
        "scram")
            echo "Setting up SCRAM authentication..."

            # Assuming these files are located in the same directory as the script
            export jaas_file="$ROOT_DIR/auth/scram/jaas.conf"
            export client_properties_file="$ROOT_DIR/auth/scram/client.properties"
            export KAFKA_OPTS="-Djava.security.auth.login.config=$jaas_file"

            # Add your SCRAM setup commands here

            ;;
        *)
            echo "Invalid authentication type."
            exit 1
            ;;
    esac
}

# Check if the script is being run with arguments
if [ "$#" -ne 0 ]; then
    display_help
fi

# Check if kafka-topics.sh command is available
if is_command_available "kafka-topics"; then
    KAFKA_TOPICS_CMD="kafka-topics"
else
    # Prompt for the Kafka installation path
    read -p "Enter Kafka Installation Path (if not in system PATH): " kafka_installation_path
    if [ -z "$kafka_installation_path" ]; then
        echo "Error: Kafka installation path cannot be empty."
        exit 1
    elif [ ! -x "$kafka_installation_path/bin/kafka-topics.sh" ]; then
        echo "Error: Unable to find kafka-topics.sh in the specified Kafka installation path."
        exit 1
    fi
    KAFKA_TOPICS_CMD="$kafka_installation_path/bin/kafka-topics.sh"
fi

# Check if kafka-acls.sh command is available
if is_command_available "kafka-acls"; then
    KAFKA_ACLS_CMD="kafka-acls"
else
    # Prompt for the Kafka installation path
    read -p "Enter Kafka Installation Path (if not in system PATH): " kafka_installation_path
    if [ -z "$kafka_installation_path" ]; then
        echo "Error: Kafka installation path cannot be empty."
        exit 1
    elif [ ! -x "$kafka_installation_path/bin/kafka-acls.sh" ]; then
        echo "Error: Unable to find kafka-acls.sh in the specified Kafka installation path."
        exit 1
    fi
    KAFKA_ACLS_CMD="$kafka_installation_path/bin/kafka-acls.sh"
fi

# Prompt for bootstrap server and validate
read -p "Enter Bootstrap Server: " bootstrap_server
if [ -z "$bootstrap_server" ]; then
    echo "Error: Bootstrap server cannot be empty."
    exit 1
elif ! validate_bootstrap_server "$bootstrap_server"; then
    echo "Error: Invalid bootstrap server. Please provide either a valid IPv4 address or a valid fully qualified domain name (FQDN)."
    exit 1
fi

# Prompt for bootstrap port and validate
read -p "Enter Bootstrap Port: " bootstrap_port
if [ -z "$bootstrap_port" ] || ! [[ "$bootstrap_port" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid or empty bootstrap port. Please provide a valid numeric port."
    exit 1
fi

# Prompt for authentication type
read -p "Enter Authentication Type (kerberos/scram): " auth_type

# Validate authentication type
if [ "$auth_type" != "kerberos" ] && [ "$auth_type" != "scram" ]; then
    echo "Error: Invalid authentication type. Please use 'kerberos' or 'scram'."
    exit 1
fi

# Setup authentication
setup_authentication "$auth_type"

# Prompt for operation
read -p "Enter Operation (list topics/describe topics/list acls): " operation

# Execute the requested operation
case "$operation" in
    "list topics")
        "$KAFKA_TOPICS_CMD" --bootstrap-server "$bootstrap_server:$bootstrap_port" --list --command-config "$client_properties_file"
        ;;
    "describe topics")
        read -p "Enter Topic Name: " topic_name
        "$KAFKA_TOPICS_CMD" --bootstrap-server "$bootstrap_server:$bootstrap_port" --describe --topic "$topic_name" --command-config "$client_properties_file"
        ;;
    "list acls")
        "$KAFKA_ACLS_CMD" --bootstrap-server "$bootstrap_server:$bootstrap_port" --list --command-config "$client_properties_file"
        ;;
    *)
        echo "Error: Invalid operation. Please use 'list topics', 'describe topics', or 'list acls'."
        exit 1
        ;;
esac
