#!/bin/bash

##############################################################################
# Kafka Listener Configuration Generator
# Generates server.properties configurations for all auth/listener combinations
# Supports PLAINTEXT, SSL/TLS, SASL_PLAINTEXT, SASL_SSL
# Auth mechanisms: PLAINTEXT, SCRAM, Kerberos, SASL/PLAIN, OAuth2
##############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${REPO_ROOT}/config"
GENERATED_CONFIG_DIR="${CONFIG_DIR}/generated"

# Create generated config directory
mkdir -p "$GENERATED_CONFIG_DIR"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

##############################################################################
# Configuration Templates
##############################################################################

# Base Kafka broker configuration (common to all)
generate_base_config() {
    local broker_id=${1:-1}
    local log_dir=${2:-/kafka/kafka-logs}
    
    cat << EOF
# Kafka Broker Configuration - Auto-generated
# Broker ID
broker.id=${broker_id}
broker.id.generation.enable=true

# Network Configuration
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Log Configuration
log.dirs=${log_dir}
num.partitions=1
num.recovery.threads.per.data.dir=1
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Replication Configuration
offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

# Consumer Group Configuration
group.max.session.timeout.ms=1800000
group.min.session.timeout.ms=6000
group.initial.rebalance.delay.ms=0

# Shutdown Configuration
controlled.shutdown.enable=true
controlled.shutdown.max.retries=2

# Zookeeper Configuration
zookeeper.connect=localhost:2181
zookeeper.connection.timeout.ms=18000

EOF
}

##############################################################################
# PLAINTEXT Listener Configurations
##############################################################################

generate_plaintext_only() {
    local host=${1:-localhost}
    local port=${2:-9092}
    
    cat << EOF
# PLAINTEXT Listener Configuration (No Authentication)
listeners=PLAINTEXT://${host}:${port}
advertised.listeners=PLAINTEXT://${host}:${port}
listener.security.protocol.map=PLAINTEXT:PLAINTEXT
inter.broker.listener.name=PLAINTEXT

# Security - None
security.inter.broker.protocol=PLAINTEXT
EOF
}

##############################################################################
# SSL/TLS Listener Configurations
##############################################################################

generate_ssl_only() {
    local host=${1:-localhost}
    local port=${2:-9093}
    local keystore_path=${3:-/path/to/keystore.jks}
    local keystore_password=${4:-keystore-secret}
    local key_password=${5:-key-secret}
    local truststore_path=${6:-/path/to/truststore.jks}
    local truststore_password=${7:-truststore-secret}
    local client_auth=${8:-required}
    
    cat << EOF
# SSL/TLS Listener Configuration (Encryption Only)
listeners=SSL://${host}:${port}
advertised.listeners=SSL://${host}:${port}
listener.security.protocol.map=SSL:SSL
inter.broker.listener.name=SSL

# SSL Configuration
ssl.keystore.location=${keystore_path}
ssl.keystore.password=${keystore_password}
ssl.key.password=${key_password}
ssl.keystore.type=JKS

ssl.truststore.location=${truststore_path}
ssl.truststore.password=${truststore_password}
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3
ssl.provider=SunJSSE

# Client Authentication
ssl.client.auth=${client_auth}

# Endpoint Validation
ssl.endpoint.identification.algorithm=HTTPS

# Security - None
security.inter.broker.protocol=SSL
EOF
}

##############################################################################
# SASL_PLAINTEXT Listener Configurations
##############################################################################

generate_sasl_plaintext_scram() {
    local host=${1:-localhost}
    local port=${2:-9094}
    
    cat << EOF
# SASL_PLAINTEXT + SCRAM-SHA-512 Configuration
listeners=SASL_PLAINTEXT://${host}:${port}
advertised.listeners=SASL_PLAINTEXT://${host}:${port}
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT
inter.broker.listener.name=SASL_PLAINTEXT

# SASL Configuration - SCRAM
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-256,SCRAM-SHA-512

# SCRAM Credentials
listener.name.sasl_plaintext.scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;

# Security
security.inter.broker.protocol=SASL_PLAINTEXT
EOF
}

generate_sasl_plaintext_plain() {
    local host=${1:-localhost}
    local port=${2:-9095}
    
    cat << EOF
# SASL_PLAINTEXT + PLAIN Configuration
listeners=SASL_PLAINTEXT://${host}:${port}
advertised.listeners=SASL_PLAINTEXT://${host}:${port}
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT
inter.broker.listener.name=SASL_PLAINTEXT

# SASL Configuration - PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN

# PLAIN Credentials
listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required;

# Security
security.inter.broker.protocol=SASL_PLAINTEXT
EOF
}

generate_sasl_plaintext_kerberos() {
    local host=${1:-localhost}
    local port=${2:-9096}
    local kerberos_realm=${3:-EXAMPLE.COM}
    local keytab_path=${4:-/path/to/kafka.keytab}
    
    cat << EOF
# SASL_PLAINTEXT + Kerberos (GSSAPI) Configuration
listeners=SASL_PLAINTEXT://${host}:${port}
advertised.listeners=SASL_PLAINTEXT://${host}:${port}
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT
inter.broker.listener.name=SASL_PLAINTEXT

# SASL Configuration - Kerberos
sasl.mechanism.inter.broker.protocol=GSSAPI
sasl.enabled.mechanisms=GSSAPI
sasl.kerberos.service.name=kafka

# Kerberos Configuration
listener.name.sasl_plaintext.gssapi.sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="${keytab_path}" principal="kafka/${host}@${kerberos_realm}";

# Security
security.inter.broker.protocol=SASL_PLAINTEXT
EOF
}

generate_sasl_plaintext_oauth2() {
    local host=${1:-localhost}
    local port=${2:-9097}
    
    cat << EOF
# SASL_PLAINTEXT + OAuth2 Configuration
listeners=SASL_PLAINTEXT://${host}:${port}
advertised.listeners=SASL_PLAINTEXT://${host}:${port}
listener.security.protocol.map=SASL_PLAINTEXT:SASL_PLAINTEXT
inter.broker.listener.name=SASL_PLAINTEXT

# SASL Configuration - OAuth2
sasl.mechanism.inter.broker.protocol=OAUTHBEARER
sasl.enabled.mechanisms=OAUTHBEARER

# OAuth2 Configuration
listener.name.sasl_plaintext.oauthbearer.sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
listener.name.sasl_plaintext.oauthbearer.sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler

# OAuth2 Server Configuration
listener.name.sasl_plaintext.oauthbearer.sasl.oauthbearer.token.endpoint.url=https://oauth-provider.example.com/token
listener.name.sasl_plaintext.oauthbearer.sasl.oauthbearer.jwks.endpoint.url=https://oauth-provider.example.com/jwks

# Security
security.inter.broker.protocol=SASL_PLAINTEXT
EOF
}

##############################################################################
# SASL_SSL Listener Configurations
##############################################################################

generate_sasl_ssl_scram() {
    local host=${1:-localhost}
    local port=${2:-9098}
    local keystore_path=${3:-/path/to/keystore.jks}
    local keystore_password=${4:-keystore-secret}
    local key_password=${5:-key-secret}
    local truststore_path=${6:-/path/to/truststore.jks}
    local truststore_password=${7:-truststore-secret}
    
    cat << EOF
# SASL_SSL + SCRAM-SHA-512 Configuration
listeners=SASL_SSL://${host}:${port}
advertised.listeners=SASL_SSL://${host}:${port}
listener.security.protocol.map=SASL_SSL:SASL_SSL
inter.broker.listener.name=SASL_SSL

# SSL Configuration
ssl.keystore.location=${keystore_path}
ssl.keystore.password=${keystore_password}
ssl.key.password=${key_password}
ssl.keystore.type=JKS

ssl.truststore.location=${truststore_path}
ssl.truststore.password=${truststore_password}
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

ssl.client.auth=required
ssl.endpoint.identification.algorithm=HTTPS

# SASL Configuration - SCRAM
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512
sasl.enabled.mechanisms=SCRAM-SHA-256,SCRAM-SHA-512

listener.name.sasl_ssl.scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;

# Security
security.inter.broker.protocol=SASL_SSL
EOF
}

generate_sasl_ssl_plain() {
    local host=${1:-localhost}
    local port=${2:-9099}
    local keystore_path=${3:-/path/to/keystore.jks}
    local keystore_password=${4:-keystore-secret}
    local key_password=${5:-key-secret}
    local truststore_path=${6:-/path/to/truststore.jks}
    local truststore_password=${7:-truststore-secret}
    
    cat << EOF
# SASL_SSL + PLAIN Configuration
listeners=SASL_SSL://${host}:${port}
advertised.listeners=SASL_SSL://${host}:${port}
listener.security.protocol.map=SASL_SSL:SASL_SSL
inter.broker.listener.name=SASL_SSL

# SSL Configuration
ssl.keystore.location=${keystore_path}
ssl.keystore.password=${keystore_password}
ssl.key.password=${key_password}
ssl.keystore.type=JKS

ssl.truststore.location=${truststore_path}
ssl.truststore.password=${truststore_password}
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

ssl.client.auth=required
ssl.endpoint.identification.algorithm=HTTPS

# SASL Configuration - PLAIN
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.enabled.mechanisms=PLAIN

listener.name.sasl_ssl.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required;

# Security
security.inter.broker.protocol=SASL_SSL
EOF
}

generate_sasl_ssl_kerberos() {
    local host=${1:-localhost}
    local port=${2:-9100}
    local keystore_path=${3:-/path/to/keystore.jks}
    local keystore_password=${4:-keystore-secret}
    local key_password=${5:-key-secret}
    local truststore_path=${6:-/path/to/truststore.jks}
    local truststore_password=${7:-truststore-secret}
    local kerberos_realm=${8:-EXAMPLE.COM}
    local keytab_path=${9:-/path/to/kafka.keytab}
    
    cat << EOF
# SASL_SSL + Kerberos (GSSAPI) Configuration
listeners=SASL_SSL://${host}:${port}
advertised.listeners=SASL_SSL://${host}:${port}
listener.security.protocol.map=SASL_SSL:SASL_SSL
inter.broker.listener.name=SASL_SSL

# SSL Configuration
ssl.keystore.location=${keystore_path}
ssl.keystore.password=${keystore_password}
ssl.key.password=${key_password}
ssl.keystore.type=JKS

ssl.truststore.location=${truststore_path}
ssl.truststore.password=${truststore_password}
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

ssl.client.auth=required
ssl.endpoint.identification.algorithm=HTTPS

# SASL Configuration - Kerberos
sasl.mechanism.inter.broker.protocol=GSSAPI
sasl.enabled.mechanisms=GSSAPI
sasl.kerberos.service.name=kafka

listener.name.sasl_ssl.gssapi.sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="${keytab_path}" principal="kafka/${host}@${kerberos_realm}";

# Security
security.inter.broker.protocol=SASL_SSL
EOF
}

generate_sasl_ssl_oauth2() {
    local host=${1:-localhost}
    local port=${2:-9101}
    local keystore_path=${3:-/path/to/keystore.jks}
    local keystore_password=${4:-keystore-secret}
    local key_password=${5:-key-secret}
    local truststore_path=${6:-/path/to/truststore.jks}
    local truststore_password=${7:-truststore-secret}
    
    cat << EOF
# SASL_SSL + OAuth2 Configuration
listeners=SASL_SSL://${host}:${port}
advertised.listeners=SASL_SSL://${host}:${port}
listener.security.protocol.map=SASL_SSL:SASL_SSL
inter.broker.listener.name=SASL_SSL

# SSL Configuration
ssl.keystore.location=${keystore_path}
ssl.keystore.password=${keystore_password}
ssl.key.password=${key_password}
ssl.keystore.type=JKS

ssl.truststore.location=${truststore_path}
ssl.truststore.password=${truststore_password}
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3

ssl.client.auth=required
ssl.endpoint.identification.algorithm=HTTPS

# SASL Configuration - OAuth2
sasl.mechanism.inter.broker.protocol=OAUTHBEARER
sasl.enabled.mechanisms=OAUTHBEARER

listener.name.sasl_ssl.oauthbearer.sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
listener.name.sasl_ssl.oauthbearer.sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler

# OAuth2 Server Configuration
listener.name.sasl_ssl.oauthbearer.sasl.oauthbearer.token.endpoint.url=https://oauth-provider.example.com/token
listener.name.sasl_ssl.oauthbearer.sasl.oauthbearer.jwks.endpoint.url=https://oauth-provider.example.com/jwks

# Security
security.inter.broker.protocol=SASL_SSL
EOF
}

##############################################################################
# Multi-Listener Configurations
##############################################################################

generate_multi_listener_all_auth() {
    local host=${1:-localhost}
    
    cat << EOF
# Multi-Listener Configuration - All Authentication Methods Enabled
# Allows clients to connect with different auth mechanisms simultaneously

listeners=PLAINTEXT://${host}:9092,SSL://${host}:9093,SASL_PLAINTEXT://${host}:9094,SASL_SSL://${host}:9095
advertised.listeners=PLAINTEXT://${host}:9092,SSL://${host}:9093,SASL_PLAINTEXT://${host}:9094,SASL_SSL://${host}:9095

listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL
inter.broker.listener.name=SSL

# SSL Configuration (for SSL and SASL_SSL listeners)
ssl.keystore.location=/path/to/keystore.jks
ssl.keystore.password=keystore-secret
ssl.key.password=key-secret
ssl.keystore.type=JKS

ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=truststore-secret
ssl.truststore.type=JKS

ssl.enabled.protocols=TLSv1.2,TLSv1.3
ssl.protocol=TLSv1.3
ssl.client.auth=required
ssl.endpoint.identification.algorithm=HTTPS

# SASL Configuration - Multiple Mechanisms
sasl.enabled.mechanisms=SCRAM-SHA-256,SCRAM-SHA-512,PLAIN,GSSAPI,OAUTHBEARER

# SCRAM
listener.name.sasl_plaintext.scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;
listener.name.sasl_ssl.scram-sha-512.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required;

# PLAIN
listener.name.sasl_plaintext.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required;
listener.name.sasl_ssl.plain.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required;

# Kerberos
sasl.kerberos.service.name=kafka
listener.name.sasl_plaintext.gssapi.sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="/path/to/kafka.keytab" principal="kafka/${host}@EXAMPLE.COM";
listener.name.sasl_ssl.gssapi.sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="/path/to/kafka.keytab" principal="kafka/${host}@EXAMPLE.COM";

# OAuth2
listener.name.sasl_plaintext.oauthbearer.sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
listener.name.sasl_plaintext.oauthbearer.sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler
listener.name.sasl_ssl.oauthbearer.sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
listener.name.sasl_ssl.oauthbearer.sasl.login.callback.handler.class=org.apache.kafka.common.security.oauthbearer.secured.OAuthBearerLoginCallbackHandler

# Security
security.inter.broker.protocol=SSL
EOF
}

##############################################################################
# Generate All Configuration Files
##############################################################################

generate_all_configs() {
    log_info "Generating all listener/auth combination configurations..."
    
    local base_config
    base_config=$(generate_base_config 1)
    
    local configs_generated=0
    
    # 1. PLAINTEXT Only
    {
        echo "$base_config"
        generate_plaintext_only "localhost" "9092"
    } > "$GENERATED_CONFIG_DIR/server-plaintext.properties"
    log_success "Generated: server-plaintext.properties"
    ((configs_generated++))
    
    # 2. SSL/TLS Only
    {
        echo "$base_config"
        generate_ssl_only "localhost" "9093"
    } > "$GENERATED_CONFIG_DIR/server-ssl.properties"
    log_success "Generated: server-ssl.properties"
    ((configs_generated++))
    
    # 3. SASL_PLAINTEXT + SCRAM
    {
        echo "$base_config"
        generate_sasl_plaintext_scram "localhost" "9094"
    } > "$GENERATED_CONFIG_DIR/server-sasl-plaintext-scram.properties"
    log_success "Generated: server-sasl-plaintext-scram.properties"
    ((configs_generated++))
    
    # 4. SASL_PLAINTEXT + PLAIN
    {
        echo "$base_config"
        generate_sasl_plaintext_plain "localhost" "9095"
    } > "$GENERATED_CONFIG_DIR/server-sasl-plaintext-plain.properties"
    log_success "Generated: server-sasl-plaintext-plain.properties"
    ((configs_generated++))
    
    # 5. SASL_PLAINTEXT + Kerberos
    {
        echo "$base_config"
        generate_sasl_plaintext_kerberos "localhost" "9096"
    } > "$GENERATED_CONFIG_DIR/server-sasl-plaintext-kerberos.properties"
    log_success "Generated: server-sasl-plaintext-kerberos.properties"
    ((configs_generated++))
    
    # 6. SASL_PLAINTEXT + OAuth2
    {
        echo "$base_config"
        generate_sasl_plaintext_oauth2 "localhost" "9097"
    } > "$GENERATED_CONFIG_DIR/server-sasl-plaintext-oauth2.properties"
    log_success "Generated: server-sasl-plaintext-oauth2.properties"
    ((configs_generated++))
    
    # 7. SASL_SSL + SCRAM
    {
        echo "$base_config"
        generate_sasl_ssl_scram "localhost" "9098"
    } > "$GENERATED_CONFIG_DIR/server-sasl-ssl-scram.properties"
    log_success "Generated: server-sasl-ssl-scram.properties"
    ((configs_generated++))
    
    # 8. SASL_SSL + PLAIN
    {
        echo "$base_config"
        generate_sasl_ssl_plain "localhost" "9099"
    } > "$GENERATED_CONFIG_DIR/server-sasl-ssl-plain.properties"
    log_success "Generated: server-sasl-ssl-plain.properties"
    ((configs_generated++))
    
    # 9. SASL_SSL + Kerberos
    {
        echo "$base_config"
        generate_sasl_ssl_kerberos "localhost" "9100"
    } > "$GENERATED_CONFIG_DIR/server-sasl-ssl-kerberos.properties"
    log_success "Generated: server-sasl-ssl-kerberos.properties"
    ((configs_generated++))
    
    # 10. SASL_SSL + OAuth2
    {
        echo "$base_config"
        generate_sasl_ssl_oauth2 "localhost" "9101"
    } > "$GENERATED_CONFIG_DIR/server-sasl-ssl-oauth2.properties"
    log_success "Generated: server-sasl-ssl-oauth2.properties"
    ((configs_generated++))
    
    # 11. Multi-Listener - All Auth Methods
    {
        echo "$base_config"
        generate_multi_listener_all_auth "localhost"
    } > "$GENERATED_CONFIG_DIR/server-multi-listener-all-auth.properties"
    log_success "Generated: server-multi-listener-all-auth.properties"
    ((configs_generated++))
    
    log_success "Generated $configs_generated configuration files in $GENERATED_CONFIG_DIR"
}

##############################################################################
# Generate Documentation
##############################################################################

generate_documentation() {
    log_info "Generating configuration documentation..."
    
    cat > "$GENERATED_CONFIG_DIR/README.md" << 'EOF'
# Kafka Listener & Authentication Configurations

This directory contains pre-generated server.properties configurations for various combinations of Kafka listeners and authentication mechanisms.

## Configuration Files Overview

### 1. PLAINTEXT (No Security)
- **File**: `server-plaintext.properties`
- **Listener**: PLAINTEXT
- **Port**: 9092
- **Use Case**: Development, testing, internal networks only
- **Security**: None

### 2. SSL/TLS (Encryption Only)
- **File**: `server-ssl.properties`
- **Listener**: SSL
- **Port**: 9093
- **Use Case**: Encrypted communication without authentication
- **Security**: TLS/SSL encryption, mutual TLS optional

### 3. SASL_PLAINTEXT + SCRAM
- **File**: `server-sasl-plaintext-scram.properties`
- **Listener**: SASL_PLAINTEXT
- **Port**: 9094
- **Auth**: SCRAM-SHA-256, SCRAM-SHA-512
- **Use Case**: Authentication without encryption (internal networks)
- **Security**: Salted Challenge Response Authentication Mechanism

### 4. SASL_PLAINTEXT + PLAIN
- **File**: `server-sasl-plaintext-plain.properties`
- **Listener**: SASL_PLAINTEXT
- **Port**: 9095
- **Auth**: PLAIN
- **Use Case**: Simple username/password authentication (internal networks)
- **Security**: Basic authentication (requires HTTPS for production)

### 5. SASL_PLAINTEXT + Kerberos
- **File**: `server-sasl-plaintext-kerberos.properties`
- **Listener**: SASL_PLAINTEXT
- **Port**: 9096
- **Auth**: Kerberos (GSSAPI)
- **Use Case**: Enterprise directory integration (internal networks)
- **Security**: Kerberos authentication

### 6. SASL_PLAINTEXT + OAuth2
- **File**: `server-sasl-plaintext-oauth2.properties`
- **Listener**: SASL_PLAINTEXT
- **Port**: 9097
- **Auth**: OAuth2 Bearer Tokens
- **Use Case**: External identity provider integration (internal networks)
- **Security**: OAuth2 token-based authentication

### 7. SASL_SSL + SCRAM
- **File**: `server-sasl-ssl-scram.properties`
- **Listener**: SASL_SSL
- **Port**: 9098
- **Auth**: SCRAM-SHA-256, SCRAM-SHA-512
- **Use Case**: Encrypted communication with credential authentication
- **Security**: TLS/SSL + SCRAM authentication

### 8. SASL_SSL + PLAIN
- **File**: `server-sasl-ssl-plain.properties`
- **Listener**: SASL_SSL
- **Port**: 9099
- **Auth**: PLAIN
- **Use Case**: Encrypted communication with username/password
- **Security**: TLS/SSL + PLAIN authentication

### 9. SASL_SSL + Kerberos
- **File**: `server-sasl-ssl-kerberos.properties`
- **Listener**: SASL_SSL
- **Port**: 9100
- **Auth**: Kerberos (GSSAPI)
- **Use Case**: Enterprise with full encryption and directory integration
- **Security**: TLS/SSL + Kerberos authentication

### 10. SASL_SSL + OAuth2
- **File**: `server-sasl-ssl-oauth2.properties`
- **Listener**: SASL_SSL
- **Port**: 9101
- **Auth**: OAuth2 Bearer Tokens
- **Use Case**: Encrypted communication with external identity provider
- **Security**: TLS/SSL + OAuth2 authentication

### 11. Multi-Listener - All Auth Methods
- **File**: `server-multi-listener-all-auth.properties`
- **Listeners**: PLAINTEXT, SSL, SASL_PLAINTEXT, SASL_SSL
- **Ports**: 9092-9095
- **Auth**: All mechanisms enabled simultaneously
- **Use Case**: Support multiple client types
- **Security**: Mixed (supports insecure and secure clients)

## Security Levels

### Development/Testing
- `server-plaintext.properties`

### Internal Network (No Encryption)
- `server-sasl-plaintext-scram.properties`
- `server-sasl-plaintext-plain.properties`
- `server-sasl-plaintext-kerberos.properties`
- `server-sasl-plaintext-oauth2.properties`

### Internal Network (Encrypted)
- `server-ssl.properties`
- `server-sasl-ssl-scram.properties`
- `server-sasl-ssl-plain.properties`
- `server-sasl-ssl-kerberos.properties`
- `server-sasl-ssl-oauth2.properties`

### Production (Recommended)
- `server-sasl-ssl-scram.properties` - Best balance
- `server-sasl-ssl-kerberos.properties` - Enterprise
- `server-sasl-ssl-oauth2.properties` - Cloud-native

## Configuration Steps

### 1. Choose Appropriate Configuration
Select a configuration file matching your security requirements.

### 2. Update Paths
Update the following paths in the configuration:
- `ssl.keystore.location`
- `ssl.truststore.location`
- `log.dirs`
- `zookeeper.connect`

### 3. Generate Certificates (if using SSL)
```bash
# Use the auth_setup.sh script to generate certificates
../auth_setup.sh --auth-type mtls --broker-server kafka.example.com
```

### 4. Setup Credentials
- **SCRAM**: Create user credentials in Zookeeper or Kafka broker
- **PLAIN**: Configure users in JAAS configuration
- **Kerberos**: Create keytab files
- **OAuth2**: Configure OAuth provider

### 5. Start Broker
```bash
kafka-server-start.sh server-<config>.properties
```

## JAAS Configuration Files

Each listener configuration may require corresponding JAAS configuration files:

```bash
../auth/plaintext/     # For PLAINTEXT
../auth/ssl/           # For SSL
../auth/scram/         # For SCRAM
../auth/plain/         # For PLAIN
../auth/kerberos/      # For Kerberos
../auth/oauth2/        # For OAuth2
```

## ACL Configuration

After authentication is setup, configure Access Control Lists (ACLs):

```bash
kafka-acls.sh --bootstrap-server localhost:9092 --add --allow-principal User:alice --operation Read --topic '*'
```

## Monitoring and Troubleshooting

### Enable Debug Logging
```bash
export KAFKA_DEBUG=1
export KAFKA_OPTS="-Djava.security.debug=all"
```

### Common Issues

1. **SSL Certificate Errors**: Ensure certificates are valid and trusted
2. **SASL Authentication Failures**: Verify credentials and JAAS configuration
3. **Kerberos Issues**: Check keytab permissions and KDC connectivity
4. **OAuth2 Token Issues**: Verify token endpoint and JWT validation

## References

- [Kafka Security Documentation](https://kafka.apache.org/documentation/#security)
- [Kafka SASL/SCRAM](https://kafka.apache.org/documentation/#security_sasl_scram)
- [Kafka OAuth2](https://kafka.apache.org/documentation/#security_sasl_oauthbearer)
- [SSL/TLS Configuration](https://kafka.apache.org/documentation/#security_ssl)

EOF
    
    log_success "Documentation generated: README.md"
}

##############################################################################
# Main
##############################################################################

main() {
    log_info "Starting Kafka Listener Configuration Generator"
    log_info "Output directory: $GENERATED_CONFIG_DIR"
    
    generate_all_configs
    generate_documentation
    
    log_success "All configurations generated successfully!"
    log_info "Next steps:"
    log_info "  1. Review configurations in: $GENERATED_CONFIG_DIR"
    log_info "  2. Update paths and credentials for your environment"
    log_info "  3. Generate certificates: ../auth_setup.sh --auth-type mtls"
    log_info "  4. Start Kafka broker with desired configuration"
}

main "$@"
