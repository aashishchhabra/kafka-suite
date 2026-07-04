# Kafka Suite - Complete Kafka Setup & Management Repository

A comprehensive repository providing scripts, configurations, and tools to set up and manage Kafka clusters with multiple authentication mechanisms, listener types, and deployment options (bare metal, Docker, Kubernetes/Strimzi).

## 🎯 Overview

This repository offers:

- **Multiple Authentication Mechanisms**: PLAINTEXT, SSL/TLS, SCRAM-SHA-256, SCRAM-SHA-512, Kerberos (GSSAPI), SASL/PLAIN, OAuth2
- **Multiple Listener Types**: PLAINTEXT, SSL/TLS, SASL_PLAINTEXT, SASL_SSL
- **Pre-generated Configurations**: 11 listener/auth combination configurations
- **Kubernetes/Strimzi Support**: Complete CLI-like wrapper for Strimzi CRD management
- **Flexible Deployment**: Support for bare metal, Docker, and Kubernetes deployments

## 📋 Table of Contents

- [Features](#features)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scripts Overview](#scripts-overview)
- [Configuration Management](#configuration-management)
- [Kubernetes/Strimzi Deployment](#kubernetsstrimzi-deployment)
- [Examples](#examples)
- [Contributing](#contributing)

## ✨ Features

### 🔐 Authentication Support

| Auth Mechanism | Listener Type | Use Case |
|---|---|---|
| PLAINTEXT | PLAINTEXT | Development only, no security |
| SCRAM-SHA-256/512 | SASL_PLAINTEXT | Internal networks, credential-based |
| SCRAM-SHA-256/512 | SASL_SSL | Encrypted + credential authentication |
| Kerberos (GSSAPI) | SASL_PLAINTEXT | Enterprise directory integration |
| Kerberos (GSSAPI) | SASL_SSL | Enterprise with encryption |
| SASL/PLAIN | SASL_PLAINTEXT | Simple username/password |
| SASL/PLAIN | SASL_SSL | Encrypted username/password |
| OAuth2 | SASL_PLAINTEXT | External identity providers |
| OAuth2 | SASL_SSL | Encrypted OAuth2 tokens |
| SSL/TLS | SSL | Encryption only, no auth |

### 🎚️ Listener Management

- **Internal Listeners**: Pod-to-pod communication
- **External Listeners**: NodePort, LoadBalancer for outside access
- **Multi-Listener Setup**: Support multiple listeners simultaneously

### ☸️ Kubernetes Native

- Strimzi operator integration
- Automated CRD generation
- Easy cluster lifecycle management
- Topic, User, and ACL management via CRDs

## 📁 Repository Structure

```
kafka-suite/
├── README.md                           # This file
├── scripts/                            # Main scripts directory
│   ├── README.md                       # Scripts documentation
│   ├── auth_setup.sh                   # Authentication setup for all mechanisms
│   ├── generate_listener_configs.sh    # Generate listener configurations
│   ├── kafka_operations.sh             # Direct Kafka operations (legacy)
│   └── strimzi_kafka_manager.sh        # Strimzi CRD management (Kubernetes)
├── config/                             # Configuration templates
│   ├── server.properties               # Base Kafka broker config
│   ├── zookeeper.properties            # Zookeeper config
│   └── generated/                      # Auto-generated listener configs
│       ├── server-plaintext.properties
│       ├── server-ssl.properties
│       ├── server-sasl-plaintext-scram.properties
│       ├── server-sasl-plaintext-plain.properties
│       ├── server-sasl-plaintext-kerberos.properties
│       ├── server-sasl-plaintext-oauth2.properties
│       ├── server-sasl-ssl-scram.properties
│       ├── server-sasl-ssl-plain.properties
│       ├── server-sasl-ssl-kerberos.properties
│       ├── server-sasl-ssl-oauth2.properties
│       ├── server-multi-listener-all-auth.properties
│       └── README.md                   # Configuration guide
├── auth/                               # Authentication files
│   ├── plaintext/
│   ├── ssl/
│   ├── scram/
│   ├── sasl-plain/
│   ├── kerberos/
│   └── oauth2/
├── strimzi/                            # Strimzi CRD manifests
│   └── (auto-generated)
└── systemd/                            # Systemd service files

```

## 📦 Prerequisites

### General Requirements

- **Bash 4.0+**: For script execution
- **kubectl**: For Kubernetes operations
- **Helm 3+**: For Strimzi operator installation (Kubernetes only)
- **Java 11+**: For Kafka runtime (bare metal deployments)

### For Bare Metal Deployments

- Kafka binaries
- Zookeeper binaries
- OpenSSL (for certificate generation)
- Apache Kafka tools in PATH

### For Kubernetes Deployments

- Kubernetes cluster (1.19+)
- Strimzi operator (auto-installed by scripts)
- Persistent storage configured

### For Specific Authentication

- **Kerberos**: KDC server, kinit tool
- **OAuth2**: OAuth2 provider endpoint
- **SSL/TLS**: OpenSSL, keytool (included with Java)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/aashishchhabra/kafka-suite.git
cd kafka-suite
chmod +x scripts/*.sh
```

### 2. Generate Configurations (Bare Metal)

```bash
# Generate all listener/auth combination configurations
scripts/generate_listener_configs.sh

# Output in config/generated/
ls -la config/generated/
```

### 3. Setup Authentication

```bash
# For SCRAM authentication
scripts/auth_setup.sh --auth-type scram

# For SSL/TLS
scripts/auth_setup.sh --auth-type mtls --broker-server kafka.example.com

# For Kerberos
scripts/auth_setup.sh --auth-type kerberos --kerberos-realm EXAMPLE.COM
```

### 4. Kubernetes/Strimzi Deployment

```bash
# Create Kafka cluster
scripts/strimzi_kafka_manager.sh cluster create -n kafka-ns --replicas 3

# Create topic
scripts/strimzi_kafka_manager.sh topic create -n kafka-ns --topic my-topic --partitions 3

# Create user
scripts/strimzi_kafka_manager.sh user create -n kafka-ns --username alice --authentication scram-sha-512

# Check status
scripts/strimzi_kafka_manager.sh status -n kafka-ns
```

## 📜 Scripts Overview

### 1. `auth_setup.sh` - Authentication Setup

Configures authentication mechanisms for Kafka brokers.

**Supported Auth Types:**
- `plaintext` - No authentication
- `scram` - SCRAM-SHA-256/512
- `sasl-plain` - SASL PLAIN
- `kerberos` - Kerberos/GSSAPI
- `mtls` / `ssl` - Mutual TLS with certificates
- `oauth2` - OAuth2 Bearer tokens

**Usage:**

```bash
# Setup SCRAM
scripts/auth_setup.sh --auth-type scram

# Setup mTLS
scripts/auth_setup.sh --auth-type mtls --broker-server kafka.example.com --domain example.com

# Setup Kerberos
scripts/auth_setup.sh --auth-type kerberos --kerberos-realm EXAMPLE.COM --kerberos-kdc kdc.example.com

# Setup OAuth2
scripts/auth_setup.sh --auth-type oauth2
```

**Output:**
- JAAS configuration files
- Client property files
- Certificate/key files (for SSL/mTLS)

### 2. `generate_listener_configs.sh` - Configuration Generator

Generates Kafka server.properties configurations for all auth/listener combinations.

**Generates 11 Configurations:**
1. PLAINTEXT only
2. SSL/TLS only
3. SASL_PLAINTEXT + SCRAM
4. SASL_PLAINTEXT + PLAIN
5. SASL_PLAINTEXT + Kerberos
6. SASL_PLAINTEXT + OAuth2
7. SASL_SSL + SCRAM
8. SASL_SSL + PLAIN
9. SASL_SSL + Kerberos
10. SASL_SSL + OAuth2
11. Multi-listener (all auth methods)

**Usage:**

```bash
scripts/generate_listener_configs.sh
```

**Output:**
- `config/generated/server-*.properties` - 11 configuration files
- `config/generated/README.md` - Detailed configuration guide

### 3. `strimzi_kafka_manager.sh` - Kubernetes Strimzi Manager

CLI-like wrapper for managing Kafka via Strimzi CRDs in Kubernetes.

**Commands:**

```bash
# Cluster Management
scripts/strimzi_kafka_manager.sh cluster create -n kafka-ns --replicas 3
scripts/strimzi_kafka_manager.sh cluster list -n kafka-ns
scripts/strimzi_kafka_manager.sh cluster describe -n kafka-ns
scripts/strimzi_kafka_manager.sh cluster update -n kafka-ns
scripts/strimzi_kafka_manager.sh cluster delete -n kafka-ns

# Topic Management
scripts/strimzi_kafka_manager.sh topic create -n kafka-ns --topic my-topic --partitions 3 --replication-factor 3
scripts/strimzi_kafka_manager.sh topic list -n kafka-ns
scripts/strimzi_kafka_manager.sh topic describe -n kafka-ns --topic my-topic
scripts/strimzi_kafka_manager.sh topic alter -n kafka-ns --topic my-topic --property retention.ms --value 86400000
scripts/strimzi_kafka_manager.sh topic delete -n kafka-ns --topic my-topic

# User Management
scripts/strimzi_kafka_manager.sh user create -n kafka-ns --username alice --authentication scram-sha-512
scripts/strimzi_kafka_manager.sh user list -n kafka-ns
scripts/strimzi_kafka_manager.sh user describe -n kafka-ns --username alice
scripts/strimzi_kafka_manager.sh user delete -n kafka-ns --username alice

# ACL Management
scripts/strimzi_kafka_manager.sh acl create -n kafka-ns --principal User:alice --resource-type Topic --resource-name 'test-*' --operations Read,Write
scripts/strimzi_kafka_manager.sh acl list -n kafka-ns

# Status
scripts/strimzi_kafka_manager.sh status -n kafka-ns
```

### 4. `kafka_operations.sh` - Direct Kafka Operations (Legacy)

Direct interaction with Kafka brokers without Kubernetes.

**Operations:**
- List topics
- Describe topics
- List ACLs

**Usage:**

```bash
scripts/kafka_operations.sh
# Interactive prompts for:
# - Bootstrap server
# - Port
# - Authentication type (kerberos/scram)
# - Operation (list topics/describe topics/list acls)
```

## 🔧 Configuration Management

### Configuration Files

**Base Configuration**: `config/server.properties`
- Broker ID settings
- Network configuration
- Storage settings
- Zookeeper connection

**Zookeeper Configuration**: `config/zookeeper.properties`
- Client port
- Replication settings
- Data directory

**Generated Configurations**: `config/generated/`
- 11 pre-generated server.properties files
- Each with specific listener/auth combination

### Customizing Configurations

1. **Edit base config**:
   ```bash
   vi config/server.properties
   ```

2. **Regenerate all configs**:
   ```bash
   scripts/generate_listener_configs.sh
   ```

3. **Use specific config**:
   ```bash
   kafka-server-start.sh config/generated/server-sasl-ssl-scram.properties
   ```

## ☸️ Kubernetes/Strimzi Deployment

### Prerequisites

- Kubernetes cluster running
- kubectl configured
- Helm installed (optional, script can install Strimzi)

### Deployment Workflow

#### 1. Create Cluster

```bash
scripts/strimzi_kafka_manager.sh cluster create \
  -n kafka-ns \
  --replicas 3 \
  --storage-size 20Gi \
  --kafka-version 3.7.0
```

**Features:**
- Automatic operator installation
- SCRAM + TLS authentication enabled
- Persistence storage
- Multi-listener setup (internal + external)
- Automatic ACL setup

#### 2. Create Topics

```bash
scripts/strimzi_kafka_manager.sh topic create \
  -n kafka-ns \
  --topic events \
  --partitions 3 \
  --replication-factor 3
```

#### 3. Create Users

```bash
# SCRAM user
scripts/strimzi_kafka_manager.sh user create \
  -n kafka-ns \
  --username alice \
  --authentication scram-sha-512

# TLS user
scripts/strimzi_kafka_manager.sh user create \
  -n kafka-ns \
  --username bob \
  --authentication tls
```

#### 4. Setup ACLs

Create/edit user YAML files in `strimzi/` directory with ACL rules:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: alice
  namespace: kafka-ns
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: "events"
        operations:
          - Read
          - Write
      - resource:
          type: group
          name: "event-consumers"
        operations:
          - Read
```

#### 5. Monitor Status

```bash
scripts/strimzi_kafka_manager.sh status -n kafka-ns
```

## 📝 Examples

### Example 1: Development Setup (No Security)

```bash
# Generate PLAINTEXT config
scripts/generate_listener_configs.sh
# Use: config/generated/server-plaintext.properties

# Start broker
kafka-server-start.sh config/generated/server-plaintext.properties

# Connect without auth
kafka-topics.sh --bootstrap-server localhost:9092 --list
```

### Example 2: Internal Network (SCRAM + Encryption)

```bash
# Setup SCRAM authentication
scripts/auth_setup.sh --auth-type scram

# Setup mTLS
scripts/auth_setup.sh --auth-type mtls --broker-server kafka.internal

# Use: config/generated/server-sasl-ssl-scram.properties

# Start broker
kafka-server-start.sh \
  config/generated/server-sasl-ssl-scram.properties \
  -Djava.security.auth.login.config=auth/scram/jaas.conf

# Connect with SCRAM credentials
kafka-topics.sh \
  --bootstrap-server localhost:9098 \
  --command-config auth/scram/client.properties \
  --list
```

### Example 3: Enterprise Setup (Kerberos + Encryption)

```bash
# Setup Kerberos
scripts/auth_setup.sh \
  --auth-type kerberos \
  --kerberos-realm EXAMPLE.COM \
  --kerberos-kdc kdc.example.com

# Setup mTLS
scripts/auth_setup.sh --auth-type mtls --broker-server kafka.example.com

# Use: config/generated/server-sasl-ssl-kerberos.properties

# Start broker
kafka-server-start.sh config/generated/server-sasl-ssl-kerberos.properties

# Connect with Kerberos
kinit user@EXAMPLE.COM
kafka-topics.sh \
  --bootstrap-server kafka.example.com:9100 \
  --command-config auth/kerberos/client.properties \
  --list
```

### Example 4: Kubernetes Deployment

```bash
# Create Kafka cluster in kubernetes
scripts/strimzi_kafka_manager.sh cluster create \
  -n production \
  -c prod-k8s-cluster \
  --replicas 5 \
  --storage-size 50Gi

# Create production topic
scripts/strimzi_kafka_manager.sh topic create \
  -n production \
  --topic prod-events \
  --partitions 10 \
  --replication-factor 3

# Create service users
scripts/strimzi_kafka_manager.sh user create \
  -n production \
  --username producer-app \
  --authentication scram-sha-512

scripts/strimzi_kafka_manager.sh user create \
  -n production \
  --username consumer-app \
  --authentication scram-sha-512

# Check status
scripts/strimzi_kafka_manager.sh status -n production
```

### Example 5: Multi-Listener Setup (All Auth Methods)

```bash
# Use: config/generated/server-multi-listener-all-auth.properties

# Supports:
# - PLAINTEXT: localhost:9092
# - SSL: localhost:9093
# - SASL_PLAINTEXT (SCRAM): localhost:9094
# - SASL_SSL (SCRAM): localhost:9095

# Connect with different auth methods
kafka-topics.sh --bootstrap-server localhost:9092 --list  # PLAINTEXT

kafka-topics.sh \
  --bootstrap-server localhost:9094 \
  --command-config auth/scram/client.properties \
  --list  # SASL_PLAINTEXT with SCRAM
```

## 🔐 Security Considerations

### Passwords & Credentials

- Store credentials securely (use Kubernetes Secrets, vaults)
- Rotate credentials regularly
- Use strong, random passwords
- Never commit credentials to git

### Certificates

- Use proper CA certificates
- Validate certificate chains
- Implement certificate rotation
- Use short expiration times for client certs

### Network Security

- Restrict listener ports with firewall rules
- Use VPCs/network namespaces
- Enable mTLS for inter-broker communication
- Use private endpoints where possible

### Authorization

- Use simple ACLs for initial setup
- Migrate to more robust authz systems (Ranger, etc.)
- Regularly audit ACL rules
- Follow principle of least privilege

## 🆘 Troubleshooting

### Common Issues

**1. Kubectl command not found**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

**2. Strimzi operator not installing**
```bash
# Check if Helm is installed
helm version

# Check Strimzi Helm repo
helm repo list | grep strimzi

# Manually install Strimzi
helm repo add strimzi https://strimzi.io/charts
helm repo update
helm install strimzi-operator strimzi/strimzi-kafka-operator -n kafka-ns
```

**3. Certificate validation errors**
```bash
# Regenerate certificates
scripts/auth_setup.sh --auth-type mtls --broker-server kafka.example.com

# Verify certificate
openssl x509 -in auth/certs/broker-cert.pem -text -noout
```

**4. SCRAM authentication failures**
```bash
# Check SCRAM configuration
cat auth/scram/jaas.conf
cat auth/scram/client.properties

# Verify credentials exist
kubectl get kafkauser -n kafka-ns -o yaml
```

## 📚 Documentation

- [Kafka Official Documentation](https://kafka.apache.org/documentation/)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [Kerberos Configuration](https://web.mit.edu/kerberos/krb5-latest/doc/admin/)
- [OAuth2 with Kafka](https://kafka.apache.org/documentation/#security_sasl_oauthbearer)
- [SSL/TLS Configuration](https://kafka.apache.org/documentation/#security_ssl)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is provided as-is for educational and development purposes.

## 📞 Support

For issues, questions, or suggestions:

1. Check existing [GitHub Issues](https://github.com/aashishchhabra/kafka-suite/issues)
2. Create a new issue with detailed description
3. Include relevant logs and configurations

---

**Last Updated**: July 2024  
**Kafka Version**: 3.7.0  
**Strimzi Version**: 0.41.0
