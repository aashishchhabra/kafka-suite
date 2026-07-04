#!/bin/bash

##############################################################################
# Kafka Authentication Setup Script
# Supports: PLAINTEXT, SCRAM, Kerberos, SASL/PLAIN, mTLS, OAuth2
# This script helps configure authentication mechanisms for Kafka brokers
##############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AUTH_DIR="${REPO_ROOT}/auth"
CONFIG_DIR="${REPO_ROOT}/config"
CERTS_DIR="${AUTH_DIR}/certs"

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

display_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup Kafka authentication mechanisms.

OPTIONS:
    -a, --auth-type         Authentication type: plaintext, scram, kerberos, sasl-plain, mtls, oauth2
    -s, --broker-server     Broker hostname/IP (for certificate generation)
    -p, --broker-port       Broker port (default: 9092)
    -d, --domain            Domain name (e.g., kafka.example.com)
    -i, --install-dir       Kafka installation directory
    --kerberos-realm        Kerberos realm (for Kerberos auth)
    --kerberos-kdc          Kerberos KDC server (for Kerberos auth)
    -h, --help              Show this help message

EXAMPLES:
    # Setup SCRAM authentication
    $0 --auth-type scram

    # Setup mTLS with certificates
    $0 --auth-type mtls --broker-server kafka.example.com --domain example.com

    # Setup Kerberos authentication
    $0 --auth-type kerberos --kerberos-realm EXAMPLE.COM --kerberos-kdc kdc.example.com

    # Setup SASL/PLAIN
    $0 --auth-type sasl-plain

EOF
    exit 0
}

##############################################################################
# Authentication Setup Functions
##############################################################################

setup_plaintext() {
    log_info "Setting up PLAINTEXT authentication..."
    
    mkdir -p "${AUTH_DIR}/plaintext"
    
    cat > "${AUTH_DIR}/plaintext/client.properties" << 'EOF'
# PLAINTEXT Client Configuration
security.protocol=PLAINTEXT
EOF
    
    log_success "PLAINTEXT authentication setup complete"
    log_info "Client config: ${AUTH_DIR}/plaintext/client.properties"
}

setup_scram() {
    log_info "Setting up SCRAM authentication..."
    
    mkdir -p "${AUTH_DIR}/scram"
    
    # Create JAAS configuration for SCRAM
    cat > "${AUTH_DIR}/scram/jaas.conf" << 'EOF'
KafkaClient {
    org.apache.kafka.common.security.scram.ScramLoginModule required
    username="kafka-client"
    password="kafka-client-secret";
};

KafkaServer {
    org.apache.kafka.common.security.scram.ScramLoginModule required;
};
EOF
    
    # Create client properties for SCRAM
    cat > "${AUTH_DIR}/scram/client.properties" << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="kafka-client" password="kafka-client-secret";
EOF
    
    log_success "SCRAM authentication setup complete"
    log_info "JAAS config: ${AUTH_DIR}/scram/jaas.conf"
    log_info "Client config: ${AUTH_DIR}/scram/client.properties"
    log_warn "Update SCRAM credentials in configuration files for production use"
}

setup_kerberos() {
    local realm="${KERBEROS_REALM:-EXAMPLE.COM}"
    local kdc="${KERBEROS_KDC:-kdc.example.com}"
    
    log_info "Setting up Kerberos authentication (Realm: $realm, KDC: $kdc)..."
    
    mkdir -p "${AUTH_DIR}/kerberos"
    
    # Create JAAS configuration for Kerberos
    cat > "${AUTH_DIR}/kerberos/jaas.conf" << EOF
KafkaClient {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="/path/to/kafka.keytab"
    principal="kafka/broker.example.com@${realm}";
};

KafkaServer {
    com.sun.security.auth.module.Krb5LoginModule required
    useKeyTab=true
    storeKey=true
    keyTab="/path/to/kafka.keytab"
    principal="kafka/broker.example.com@${realm}";
};
EOF
    
    # Create krb5.conf template
    cat > "${AUTH_DIR}/kerberos/krb5.conf" << EOF
[libdefaults]
    default_realm = ${realm}
    dns_lookup_realm = false
    dns_lookup_kdc = false

[realms]
    ${realm} = {
        kdc = ${kdc}:88
        admin_server = ${kdc}:749
        default_domain = example.com
    }

[domain_realm]
    .example.com = ${realm}
    example.com = ${realm}
EOF
    
    # Create client properties for Kerberos
    cat > "${AUTH_DIR}/kerberos/client.properties" << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=GSSAPI
sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required useKeyTab=true storeKey=true keyTab="/path/to/client.keytab" principal="user@EXAMPLE.COM";
sasl.kerberos.service.name=kafka
EOF
    
    log_success "Kerberos authentication setup complete"
    log_info "JAAS config: ${AUTH_DIR}/kerberos/jaas.conf"
    log_info "krb5.conf: ${AUTH_DIR}/kerberos/krb5.conf"
    log_info "Client config: ${AUTH_DIR}/kerberos/client.properties"
    log_warn "Update keytab paths and principals in configuration files"
}

setup_sasl_plain() {
    log_info "Setting up SASL/PLAIN authentication..."
    
    mkdir -p "${AUTH_DIR}/sasl-plain"
    
    # Create JAAS configuration for SASL/PLAIN
    cat > "${AUTH_DIR}/sasl-plain/jaas.conf" << 'EOF'
KafkaClient {
    org.apache.kafka.common.security.plain.PlainLoginModule required
    username="kafka-user"
    password="kafka-password";
};

KafkaServer {
    org.apache.kafka.common.security.plain.PlainLoginModule required;
};
EOF
    
    # Create client properties for SASL/PLAIN
    cat > "${AUTH_DIR}/sasl-plain/client.properties" << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="kafka-user" password="kafka-password";
EOF
    
    log_success "SASL/PLAIN authentication setup complete"
    log_info "JAAS config: ${AUTH_DIR}/sasl-plain/jaas.conf"
    log_info "Client config: ${AUTH_DIR}/sasl-plain/client.properties"
    log_warn "Update credentials in configuration files for production use"
}

setup_mtls() {
    local broker_server="${BROKER_SERVER:-kafka-broker}"
    local domain="${DOMAIN:-example.com}"
    
    log_info "Setting up mTLS (mutual TLS) authentication..."
    log_info "Broker Server: $broker_server, Domain: $domain"
    
    mkdir -p "${CERTS_DIR}"
    
    # Generate CA private key
    if [ ! -f "${CERTS_DIR}/ca-key.pem" ]; then
        log_info "Generating CA private key..."
        openssl genrsa -out "${CERTS_DIR}/ca-key.pem" 4096
    fi
    
    # Generate CA certificate
    if [ ! -f "${CERTS_DIR}/ca-cert.pem" ]; then
        log_info "Generating CA certificate..."
        openssl req -new -x509 -days 3650 -key "${CERTS_DIR}/ca-key.pem" \
            -out "${CERTS_DIR}/ca-cert.pem" \
            -subj "/CN=KafkaCA/O=Organization/C=US"
    fi
    
    # Generate broker private key
    if [ ! -f "${CERTS_DIR}/broker-key.pem" ]; then
        log_info "Generating broker private key..."
        openssl genrsa -out "${CERTS_DIR}/broker-key.pem" 4096
    fi
    
    # Generate broker certificate signing request
    if [ ! -f "${CERTS_DIR}/broker.csr" ]; then
        log_info "Generating broker certificate signing request..."
        openssl req -new -key "${CERTS_DIR}/broker-key.pem" \
            -out "${CERTS_DIR}/broker.csr" \
            -subj "/CN=${broker_server}/O=Organization/C=US"
    fi
    
    # Sign broker certificate with CA
    if [ ! -f "${CERTS_DIR}/broker-cert.pem" ]; then
        log_info "Signing broker certificate with CA..."
        openssl x509 -req -days 365 \
            -in "${CERTS_DIR}/broker.csr" \
            -CA "${CERTS_DIR}/ca-cert.pem" \
            -CAkey "${CERTS_DIR}/ca-key.pem" \
            -CAcreateserial -out "${CERTS_DIR}/broker-cert.pem"
    fi
    
    # Generate client private key
    if [ ! -f "${CERTS_DIR}/client-key.pem" ]; then
        log_info "Generating client private key..."
        openssl genrsa -out "${CERTS_DIR}/client-key.pem" 4096
    fi
    
    # Generate client certificate signing request
    if [ ! -f "${CERTS_DIR}/client.csr" ]; then
        log_info "Generating client certificate signing request..."
        openssl req -new -key "${CERTS_DIR}/client-key.pem" \
            -out "${CERTS_DIR}/client.csr" \
            -subj "/CN=kafka-client/O=Organization/C=US"
    fi
    
    # Sign client certificate with CA
    if [ ! -f "${CERTS_DIR}/client-cert.pem" ]; then
        log_info "Signing client certificate with CA..."
        openssl x509 -req -days 365 \
            -in "${CERTS_DIR}/client.csr" \
            -CA "${CERTS_DIR}/ca-cert.pem" \
            -CAkey "${CERTS_DIR}/ca-key.pem" \
            -CAcreateserial -out "${CERTS_DIR}/client-cert.pem"
    fi
    
    # Create broker keystore
    if [ ! -f "${CERTS_DIR}/broker-keystore.jks" ]; then
        log_info "Creating broker keystore..."
        openssl pkcs12 -export -in "${CERTS_DIR}/broker-cert.pem" \
            -inkey "${CERTS_DIR}/broker-key.pem" \
            -out "${CERTS_DIR}/broker-keystore.p12" \
            -name kafka-broker -passout pass:broker-secret
        
        keytool -importkeystore -srckeystore "${CERTS_DIR}/broker-keystore.p12" \
            -srcstoretype PKCS12 -srcstorepass broker-secret \
            -destkeystore "${CERTS_DIR}/broker-keystore.jks" \
            -deststoretype JKS -deststorepass broker-secret
    fi
    
    # Create broker truststore
    if [ ! -f "${CERTS_DIR}/broker-truststore.jks" ]; then
        log_info "Creating broker truststore..."
        keytool -import -alias ca -file "${CERTS_DIR}/ca-cert.pem" \
            -keystore "${CERTS_DIR}/broker-truststore.jks" \
            -storepass broker-secret -noprompt
    fi
    
    # Create client keystore
    if [ ! -f "${CERTS_DIR}/client-keystore.jks" ]; then
        log_info "Creating client keystore..."
        openssl pkcs12 -export -in "${CERTS_DIR}/client-cert.pem" \
            -inkey "${CERTS_DIR}/client-key.pem" \
            -out "${CERTS_DIR}/client-keystore.p12" \
            -name kafka-client -passout pass:client-secret
        
        keytool -importkeystore -srckeystore "${CERTS_DIR}/client-keystore.p12" \
            -srcstoretype PKCS12 -srcstorepass client-secret \
            -destkeystore "${CERTS_DIR}/client-keystore.jks" \
            -deststoretype JKS -deststorepass client-secret
    fi
    
    # Create client truststore
    if [ ! -f "${CERTS_DIR}/client-truststore.jks" ]; then
        log_info "Creating client truststore..."
        keytool -import -alias ca -file "${CERTS_DIR}/ca-cert.pem" \
            -keystore "${CERTS_DIR}/client-truststore.jks" \
            -storepass client-secret -noprompt
    fi
    
    mkdir -p "${AUTH_DIR}/mtls"
    
    # Create client properties for mTLS
    cat > "${AUTH_DIR}/mtls/client.properties" << 'EOF'
security.protocol=SSL
ssl.truststore.location=/path/to/client-truststore.jks
ssl.truststore.password=client-secret
ssl.truststore.type=JKS
ssl.keystore.location=/path/to/client-keystore.jks
ssl.keystore.password=client-secret
ssl.keystore.type=JKS
ssl.key.password=client-secret
ssl.endpoint.identification.algorithm=HTTPS
EOF
    
    log_success "mTLS authentication setup complete"
    log_info "Certificates directory: ${CERTS_DIR}"
    log_info "Client config: ${AUTH_DIR}/mtls/client.properties"
    log_warn "Update keystore/truststore paths in configuration files"
    log_warn "Store passwords securely (broker-secret, client-secret)"
}

setup_oauth2() {
    log_info "Setting up OAuth2 authentication..."
    
    mkdir -p "${AUTH_DIR}/oauth2"
    
    # Create JAAS configuration for OAuth2
    cat > "${AUTH_DIR}/oauth2/jaas.conf" << 'EOF'
KafkaClient {
    org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required
    clientId="kafka-client"
    clientSecret="your-client-secret"
    tokenEndpoint="https://oauth-provider.example.com/token"
    scope="kafka";
};

KafkaServer {
    org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required;
};
EOF
    
    # Create client properties for OAuth2
    cat > "${AUTH_DIR}/oauth2/client.properties" << 'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule required clientId="kafka-client" clientSecret="your-client-secret" tokenEndpoint="https://oauth-provider.example.com/token" scope="kafka";
EOF
    
    log_success "OAuth2 authentication setup complete"
    log_info "JAAS config: ${AUTH_DIR}/oauth2/jaas.conf"
    log_info "Client config: ${AUTH_DIR}/oauth2/client.properties"
    log_warn "Update OAuth2 credentials and endpoints in configuration files"
}

##############################################################################
# Main Script
##############################################################################

main() {
    local auth_type="plaintext"
    
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--auth-type)
                auth_type="$2"
                shift 2
                ;;
            -s|--broker-server)
                BROKER_SERVER="$2"
                shift 2
                ;;
            -p|--broker-port)
                BROKER_PORT="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -i|--install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --kerberos-realm)
                KERBEROS_REALM="$2"
                shift 2
                ;;
            --kerberos-kdc)
                KERBEROS_KDC="$2"
                shift 2
                ;;
            -h|--help)
                display_help
                ;;
            *)
                log_error "Unknown option: $1"
                display_help
                ;;
        esac
    done
    
    log_info "Starting Kafka Authentication Setup"
    log_info "Auth Type: $auth_type"
    
    case "$auth_type" in
        plaintext)
            setup_plaintext
            ;;
        scram)
            setup_scram
            ;;
        kerberos)
            setup_kerberos
            ;;
        sasl-plain)
            setup_sasl_plain
            ;;
        mtls|ssl)
            setup_mtls
            ;;
        oauth2)
            setup_oauth2
            ;;
        *)
            log_error "Unknown authentication type: $auth_type"
            display_help
            ;;
    esac
    
    log_success "Authentication setup complete!"
}

main "$@"
