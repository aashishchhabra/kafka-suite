#!/bin/bash

##############################################################################
# Strimzi Kafka Cluster Manager
# Wrapper script to manage Kafka clusters, topics, users, and ACLs via Strimzi CRDs
# Provides CLI-like interface similar to Apache Kafka tools but through Kubernetes
##############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
STRIMZI_DIR="${REPO_ROOT}/strimzi"
CONFIG_DIR="${REPO_ROOT}/config"

# Strimzi versions
STRIMZI_VERSION="${STRIMZI_VERSION:-0.41.0}"
KAFKA_VERSION="${KAFKA_VERSION:-3.7.0}"

# Default values
NAMESPACE="${NAMESPACE:-default}"
KUBECONFIG_CONTEXT=""
CLUSTER_NAME="kafka"
REPLICAS=3
STORAGE_SIZE="10Gi"
STORAGE_CLASS="standard"
METRICS_ENABLED="false"

##############################################################################
# Utility Functions
##############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*"
    fi
}

display_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Manage Kafka clusters, topics, users, and ACLs via Strimzi Kubernetes Operator.

COMMANDS:
    cluster     Manage Kafka clusters
    topic       Manage Kafka topics
    user        Manage Kafka users
    acl         Manage Kafka ACLs
    status      Show cluster and resource status
    help        Show this help message

CLUSTER COMMANDS:
    cluster create          Create a new Kafka cluster
    cluster delete          Delete a Kafka cluster
    cluster list            List all Kafka clusters
    cluster describe        Describe a Kafka cluster
    cluster update          Update cluster configuration

TOPIC COMMANDS:
    topic create            Create a new topic
    topic delete            Delete a topic
    topic list              List all topics
    topic describe          Describe a topic
    topic alter             Alter topic configuration

USER COMMANDS:
    user create             Create a new Kafka user
    user delete             Delete a Kafka user
    user list               List all users
    user describe           Describe a user

ACL COMMANDS:
    acl create              Create ACL rules
    acl delete              Delete ACL rules
    acl list                List ACL rules

GLOBAL OPTIONS:
    -n, --namespace         Kubernetes namespace (default: default)
    -c, --context           Kubernetes context
    -C, --cluster           Cluster name (default: kafka)
    --kubeconfig            Path to kubeconfig file
    -h, --help              Show help message
    -d, --debug             Enable debug output

EXAMPLES:
    # Create Kafka cluster
    $0 cluster create -n kafka-ns --replicas 3

    # Create topic
    $0 topic create -n kafka-ns --topic my-topic --partitions 3 --replication-factor 3

    # Create user with SCRAM authentication
    $0 user create -n kafka-ns --username alice --authentication scram-sha-512

    # Create ACL rule
    $0 acl create -n kafka-ns --principal User:alice --resource Topic --name 'test-*' --operations Read,Write

    # Get cluster status
    $0 status -n kafka-ns

EOF
    exit 0
}

##############################################################################
# Kubernetes Helper Functions
##############################################################################

check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl to proceed."
        exit 1
    fi
}

check_kube_context() {
    if [ -z "$KUBECONFIG_CONTEXT" ]; then
        log_info "Available Kubernetes contexts:"
        kubectl config get-contexts
        read -p "Select context (or press Enter for current): " KUBECONFIG_CONTEXT
        
        if [ -z "$KUBECONFIG_CONTEXT" ]; then
            KUBECONFIG_CONTEXT=$(kubectl config current-context)
            log_info "Using current context: $KUBECONFIG_CONTEXT"
        fi
    fi
    
    # Set context
    if [ ! -z "$KUBECONFIG_CONTEXT" ]; then
        kubectl config use-context "$KUBECONFIG_CONTEXT" > /dev/null 2>&1 || {
            log_error "Invalid context: $KUBECONFIG_CONTEXT"
            exit 1
        }
    fi
}

check_strimzi_operator() {
    log_info "Checking for Strimzi operator in namespace: $NAMESPACE"
    
    local count
    count=$(kubectl get deployment -n "$NAMESPACE" -l app.kubernetes.io/name=strimzi-cluster-operator --no-headers 2>/dev/null | wc -l)
    
    if [ "$count" -eq 0 ]; then
        log_warn "Strimzi operator not found in namespace: $NAMESPACE"
        read -p "Install Strimzi operator? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_strimzi_operator
        else
            log_error "Strimzi operator is required. Exiting."
            exit 1
        fi
    else
        log_success "Strimzi operator found"
    fi
}

install_strimzi_operator() {
    log_info "Installing Strimzi operator v${STRIMZI_VERSION}..."
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Add Strimzi Helm repository
    helm repo add strimzi https://strimzi.io/charts || true
    helm repo update
    
    # Install Strimzi operator
    helm upgrade --install strimzi-operator strimzi/strimzi-kafka-operator \
        --namespace "$NAMESPACE" \
        --version "$STRIMZI_VERSION" \
        --set image.tag="$STRIMZI_VERSION" || {
        log_error "Failed to install Strimzi operator"
        exit 1
    }
    
    log_success "Strimzi operator installed successfully"
    log_info "Waiting for operator to be ready..."
    kubectl rollout status deployment/strimzi-cluster-operator -n "$NAMESPACE" --timeout=300s
}

check_namespace() {
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE does not exist. Creating..."
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace created: $NAMESPACE"
    fi
}

##############################################################################
# Kafka Cluster Management
##############################################################################

create_kafka_cluster() {
    local broker_replicas="${1:-3}"
    local zk_replicas="${2:-3}"
    local kafka_version="${3:-$KAFKA_VERSION}"
    
    log_info "Creating Kafka cluster: $CLUSTER_NAME (replicas: $broker_replicas, version: $kafka_version)"
    
    check_namespace
    check_strimzi_operator
    
    mkdir -p "$STRIMZI_DIR"
    
    # Create Kafka cluster CR
    cat > "$STRIMZI_DIR/kafka-cluster-$CLUSTER_NAME.yaml" << EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: $CLUSTER_NAME
  namespace: $NAMESPACE
spec:
  kafka:
    version: $kafka_version
    replicas: $broker_replicas
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
        configuration:
          useServiceDnsDomain: true
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
        configuration:
          useServiceDnsDomain: true
      - name: external
        port: 9094
        type: nodeport
        tls: true
        authentication:
          type: scram-sha-512
    authorization:
      type: simple
      superUsers:
        - User:admin
    config:
      auto.create.topics.enable: "true"
      offsets.topic.replication.factor: $broker_replicas
      transaction.state.log.replication.factor: $broker_replicas
      transaction.state.log.min.isr: 2
      default.replication.factor: $broker_replicas
      min.insync.replicas: 2
      log.retention.hours: 168
    storage:
      type: persistent-claim
      size: $STORAGE_SIZE
      class: $STORAGE_CLASS
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
    metricsConfig:
      type: jmxPrometheusExporter
      valueSecret:
        name: kafka-metrics
        key: metrics-config.yml

  zookeeper:
    replicas: $zk_replicas
    config:
      autopurge.snapRetainCount: 3
      autopurge.purgeInterval: 1
    storage:
      type: persistent-claim
      size: 5Gi
      class: $STORAGE_CLASS
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "1Gi"
        cpu: "500m"

  entityOperator:
    topicOperator:
      watchedNamespace: $NAMESPACE
      reconciliationIntervalSeconds: 60
    userOperator:
      watchedNamespace: $NAMESPACE
      reconciliationIntervalSeconds: 60
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"

EOF
    
    log_info "Applying Kafka cluster CR..."
    kubectl apply -f "$STRIMZI_DIR/kafka-cluster-$CLUSTER_NAME.yaml"
    
    log_success "Kafka cluster CR created: $CLUSTER_NAME"
    log_info "Waiting for Kafka cluster to be ready (this may take a few minutes)..."
    kubectl wait kafka/$CLUSTER_NAME --for=condition=Ready --timeout=600s -n "$NAMESPACE" || {
        log_warn "Timeout waiting for cluster to be ready. Check status with: kubectl get kafka -n $NAMESPACE"
    }
    
    log_success "Kafka cluster is ready!"
    describe_kafka_cluster
}

delete_kafka_cluster() {
    log_warn "Deleting Kafka cluster: $CLUSTER_NAME"
    read -p "Are you sure? (type cluster name to confirm): " confirm
    
    if [ "$confirm" = "$CLUSTER_NAME" ]; then
        kubectl delete kafka "$CLUSTER_NAME" -n "$NAMESPACE" --ignore-not-found
        log_success "Kafka cluster deleted: $CLUSTER_NAME"
    else
        log_info "Deletion cancelled"
    fi
}

list_kafka_clusters() {
    log_info "Listing Kafka clusters in namespace: $NAMESPACE"
    kubectl get kafka -n "$NAMESPACE" -o wide
}

describe_kafka_cluster() {
    log_info "Describing Kafka cluster: $CLUSTER_NAME"
    kubectl describe kafka "$CLUSTER_NAME" -n "$NAMESPACE"
    
    log_info "Kafka pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance="$CLUSTER_NAME"
}

update_kafka_cluster() {
    log_info "Updating Kafka cluster configuration..."
    
    if [ ! -f "$STRIMZI_DIR/kafka-cluster-$CLUSTER_NAME.yaml" ]; then
        log_error "Cluster file not found: $STRIMZI_DIR/kafka-cluster-$CLUSTER_NAME.yaml"
        exit 1
    fi
    
    kubectl apply -f "$STRIMZI_DIR/kafka-cluster-$CLUSTER_NAME.yaml"
    log_success "Kafka cluster updated"
}

##############################################################################
# Kafka Topic Management
##############################################################################

create_topic() {
    local topic_name="${1:-}"
    local partitions="${2:-3}"
    local replication_factor="${3:-3}"
    
    if [ -z "$topic_name" ]; then
        read -p "Enter topic name: " topic_name
    fi
    
    if [ -z "$topic_name" ]; then
        log_error "Topic name cannot be empty"
        exit 1
    fi
    
    log_info "Creating topic: $topic_name (partitions: $partitions, replication-factor: $replication_factor)"
    
    mkdir -p "$STRIMZI_DIR"
    
    cat > "$STRIMZI_DIR/topic-$topic_name.yaml" << EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: $topic_name
  namespace: $NAMESPACE
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  partitions: $partitions
  replicationFactor: $replication_factor
  topicName: $topic_name
  config:
    cleanup.policy: delete
    retention.ms: 604800000
    segment.ms: 86400000
    compression.type: snappy

EOF
    
    kubectl apply -f "$STRIMZI_DIR/topic-$topic_name.yaml"
    log_success "Topic created: $topic_name"
}

delete_topic() {
    local topic_name="${1:-}"
    
    if [ -z "$topic_name" ]; then
        read -p "Enter topic name: " topic_name
    fi
    
    log_warn "Deleting topic: $topic_name"
    read -p "Are you sure? (type topic name to confirm): " confirm
    
    if [ "$confirm" = "$topic_name" ]; then
        kubectl delete kafkatopic "$topic_name" -n "$NAMESPACE" --ignore-not-found
        log_success "Topic deleted: $topic_name"
    else
        log_info "Deletion cancelled"
    fi
}

list_topics() {
    log_info "Listing Kafka topics in cluster: $CLUSTER_NAME"
    kubectl get kafkatopic -n "$NAMESPACE" -l strimzi.io/cluster="$CLUSTER_NAME" -o wide
}

describe_topic() {
    local topic_name="${1:-}"
    
    if [ -z "$topic_name" ]; then
        read -p "Enter topic name: " topic_name
    fi
    
    log_info "Describing topic: $topic_name"
    kubectl describe kafkatopic "$topic_name" -n "$NAMESPACE"
}

alter_topic() {
    local topic_name="${1:-}"
    local property="${2:-}"
    local value="${3:-}"
    
    if [ -z "$topic_name" ]; then
        read -p "Enter topic name: " topic_name
    fi
    
    if [ -z "$property" ] || [ -z "$value" ]; then
        log_error "Usage: topic alter <name> <property> <value>"
        log_info "Example: topic alter my-topic retention.ms 86400000"
        exit 1
    fi
    
    log_info "Altering topic: $topic_name"
    kubectl patch kafkatopic "$topic_name" -n "$NAMESPACE" --type merge \
        -p "{\"spec\":{\"config\":{\"$property\":\"$value\"}}}"
    
    log_success "Topic altered: $topic_name"
}

##############################################################################
# Kafka User Management
##############################################################################

create_user() {
    local username="${1:-}"
    local auth_type="${2:-scram-sha-512}"
    local authorization_type="${3:-simple}"
    
    if [ -z "$username" ]; then
        read -p "Enter username: " username
    fi
    
    if [ -z "$username" ]; then
        log_error "Username cannot be empty"
        exit 1
    fi
    
    log_info "Creating user: $username (auth: $auth_type)"
    
    mkdir -p "$STRIMZI_DIR"
    
    local auth_config=""
    case "$auth_type" in
        scram-sha-256)
            auth_config="type: scram-sha-256"
            ;;
        scram-sha-512)
            auth_config="type: scram-sha-512"
            ;;
        tls)
            auth_config="type: tls"
            ;;
        *)
            log_error "Invalid authentication type: $auth_type"
            exit 1
            ;;
    esac
    
    cat > "$STRIMZI_DIR/user-$username.yaml" << EOF
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: $username
  namespace: $NAMESPACE
  labels:
    strimzi.io/cluster: $CLUSTER_NAME
spec:
  authentication:
    $auth_config
  authorization:
    type: $authorization_type
    acls:
      - resource:
          type: topic
          name: "*"
        operations:
          - Describe
      - resource:
          type: group
          name: "*"
        operations:
          - Describe

EOF
    
    kubectl apply -f "$STRIMZI_DIR/user-$username.yaml"
    log_success "User created: $username"
    log_info "To view user details: kubectl get kafkauser $username -n $NAMESPACE -o yaml"
}

delete_user() {
    local username="${1:-}"
    
    if [ -z "$username" ]; then
        read -p "Enter username: " username
    fi
    
    log_warn "Deleting user: $username"
    read -p "Are you sure? (type username to confirm): " confirm
    
    if [ "$confirm" = "$username" ]; then
        kubectl delete kafkauser "$username" -n "$NAMESPACE" --ignore-not-found
        log_success "User deleted: $username"
    else
        log_info "Deletion cancelled"
    fi
}

list_users() {
    log_info "Listing Kafka users in cluster: $CLUSTER_NAME"
    kubectl get kafkauser -n "$NAMESPACE" -l strimzi.io/cluster="$CLUSTER_NAME" -o wide
}

describe_user() {
    local username="${1:-}"
    
    if [ -z "$username" ]; then
        read -p "Enter username: " username
    fi
    
    log_info "Describing user: $username"
    kubectl describe kafkauser "$username" -n "$NAMESPACE"
}

##############################################################################
# Kafka ACL Management
##############################################################################

create_acl() {
    local principal="${1:-}"
    local resource_type="${2:-Topic}"
    local resource_name="${3:-*}"
    local operations="${4:-Read,Write}"
    
    if [ -z "$principal" ]; then
        read -p "Enter principal (e.g., User:alice): " principal
    fi
    
    log_info "Creating ACL: principal=$principal, resource=$resource_type:$resource_name, operations=$operations"
    
    # Parse operations
    local ops_array=()
    IFS=',' read -ra ops <<< "$operations"
    for op in "${ops[@]}"; do
        ops_array+=("- $op")
    done
    local ops_yaml=$(printf "%s\n" "${ops_array[@]}")
    
    # Extract username from principal (e.g., "User:alice" -> "alice")
    local username="${principal##*:}"
    
    # Create a temporary YAML for ACL configuration
    cat > "$STRIMZI_DIR/acl-$username-temp.yaml" << EOF
resource:
  type: $resource_type
  name: "$resource_name"
operations:
$ops_yaml
EOF
    
    log_success "ACL rule created for: $principal"
    log_info "To apply ACL, edit the user's authorization section in: $STRIMZI_DIR/user-$username.yaml"
    log_info "Example YAML generated at: $STRIMZI_DIR/acl-$username-temp.yaml"
}

list_acls() {
    log_info "Listing Kafka users (which contain ACL rules):"
    log_info "Run: kubectl get kafkauser -n $NAMESPACE -o yaml"
    log_info ""
    log_info "To view ACLs for a specific user:"
    log_info "Run: kubectl get kafkauser <username> -n $NAMESPACE -o yaml | grep -A 20 'acls:'"
    
    # Show all users with their ACLs
    kubectl get kafkauser -n "$NAMESPACE" -l strimzi.io/cluster="$CLUSTER_NAME" -o custom-columns=NAME:.metadata.name
}

##############################################################################
# Status and Monitoring
##############################################################################

show_cluster_status() {
    log_info "=== Kafka Cluster Status ==="
    log_info "Namespace: $NAMESPACE"
    log_info "Cluster: $CLUSTER_NAME"
    log_info ""
    
    log_info "Kafka Cluster:"
    kubectl get kafka "$CLUSTER_NAME" -n "$NAMESPACE" -o wide 2>/dev/null || log_warn "Cluster not found"
    
    log_info ""
    log_info "Broker Pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=kafka,app.kubernetes.io/instance="$CLUSTER_NAME" -o wide
    
    log_info ""
    log_info "Zookeeper Pods:"
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=zookeeper,app.kubernetes.io/instance="$CLUSTER_NAME" -o wide
    
    log_info ""
    log_info "Topics: $(kubectl get kafkatopic -n "$NAMESPACE" -l strimzi.io/cluster="$CLUSTER_NAME" --no-headers | wc -l)"
    
    log_info ""
    log_info "Users: $(kubectl get kafkauser -n "$NAMESPACE" -l strimzi.io/cluster="$CLUSTER_NAME" --no-headers | wc -l)"
}

##############################################################################
# Command Parsing and Execution
##############################################################################

main() {
    check_kubectl
    
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        -h|--help|help)
            display_help
            ;;
        
        # Cluster commands
        cluster)
            local cluster_cmd="${1:-help}"
            shift || true
            
            case "$cluster_cmd" in
                create)
                    # Parse cluster options
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -c|--context) KUBECONFIG_CONTEXT="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            --replicas) REPLICAS="$2"; shift 2 ;;
                            --storage-size) STORAGE_SIZE="$2"; shift 2 ;;
                            --storage-class) STORAGE_CLASS="$2"; shift 2 ;;
                            --kafka-version) KAFKA_VERSION="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    create_kafka_cluster "$REPLICAS" "$REPLICAS"
                    ;;
                delete)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    delete_kafka_cluster
                    ;;
                list)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    list_kafka_clusters
                    ;;
                describe)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    describe_kafka_cluster
                    ;;
                update)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    update_kafka_cluster
                    ;;
                *)
                    log_error "Unknown cluster command: $cluster_cmd"
                    display_help
                    ;;
            esac
            ;;
        
        # Topic commands
        topic)
            local topic_cmd="${1:-help}"
            shift || true
            
            case "$topic_cmd" in
                create)
                    local topic_name="" partitions=3 replication_factor=3
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -t|--topic) topic_name="$2"; shift 2 ;;
                            -p|--partitions) partitions="$2"; shift 2 ;;
                            -r|--replication-factor) replication_factor="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    create_topic "$topic_name" "$partitions" "$replication_factor"
                    ;;
                delete)
                    local topic_name=""
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -t|--topic) topic_name="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    delete_topic "$topic_name"
                    ;;
                list)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    list_topics
                    ;;
                describe)
                    local topic_name=""
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -t|--topic) topic_name="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    describe_topic "$topic_name"
                    ;;
                alter)
                    local topic_name="" property="" value=""
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -t|--topic) topic_name="$2"; shift 2 ;;
                            -p|--property) property="$2"; shift 2 ;;
                            -v|--value) value="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    alter_topic "$topic_name" "$property" "$value"
                    ;;
                *)
                    log_error "Unknown topic command: $topic_cmd"
                    display_help
                    ;;
            esac
            ;;
        
        # User commands
        user)
            local user_cmd="${1:-help}"
            shift || true
            
            case "$user_cmd" in
                create)
                    local username="" auth_type="scram-sha-512"
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -u|--username) username="$2"; shift 2 ;;
                            -a|--authentication) auth_type="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    create_user "$username" "$auth_type"
                    ;;
                delete)
                    local username=""
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -u|--username) username="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    delete_user "$username"
                    ;;
                list)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    list_users
                    ;;
                describe)
                    local username=""
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            -u|--username) username="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    describe_user "$username"
                    ;;
                *)
                    log_error "Unknown user command: $user_cmd"
                    display_help
                    ;;
            esac
            ;;
        
        # ACL commands
        acl)
            local acl_cmd="${1:-help}"
            shift || true
            
            case "$acl_cmd" in
                create)
                    local principal="" resource_type="Topic" resource_name="*" operations="Read,Write"
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            --principal) principal="$2"; shift 2 ;;
                            --resource-type) resource_type="$2"; shift 2 ;;
                            --resource-name) resource_name="$2"; shift 2 ;;
                            -o|--operations) operations="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    create_acl "$principal" "$resource_type" "$resource_name" "$operations"
                    ;;
                list)
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                            -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                            *) shift ;;
                        esac
                    done
                    check_kube_context
                    list_acls
                    ;;
                *)
                    log_error "Unknown ACL command: $acl_cmd"
                    display_help
                    ;;
            esac
            ;;
        
        # Status command
        status)
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
                    -C|--cluster) CLUSTER_NAME="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            check_kube_context
            show_cluster_status
            ;;
        
        *)
            log_error "Unknown command: $command"
            display_help
            ;;
    esac
}

main "$@"
