#!/bin/bash

# ================================================================= #
# SCRIPT DEFINITIVO SAMBA AD DC - NÍVEL 2016 + LIXEIRA
# Compatibilidade: Ubuntu 22.04 / 24.04 (Noble Numbat)
# ================================================================= #

# --- 1. VARIÁVEIS (AJUSTE CONFORME SUA REDE) ---
DOMAIN="flexclima.local"
REALM="FLEXCLIMA.LOCAL"
NETBIOS_NAME="DC01"
WORKGROUP="FLEXCLIMA"
ADMIN_PASSWORD="SuaSenhaForteAqui"
FORWARDER="8.8.8.8"
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)

echo "### [1/9] Configurando DNS temporário para instalação ###"
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# --- 2. INSTALAÇÃO DE PACOTES ---
echo "### [2/9] Instalando Samba e dependências ###"
apt update
apt install samba krb5-config krb5-user winbind smbclient ldb-tools net-tools -y

# --- 3. LIMPEZA DE AMBIENTE ---
echo "### [3/9] Limpando configurações e parando serviços antigos ###"
systemctl stop samba-ad-dc smbd nmbd winbind systemd-resolved 2>/dev/null
rm -rf /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*
mkdir -p /var/lib/samba/private
chmod 700 /var/lib/samba/private

# --- 4. PROVISIONAMENTO DO DOMÍNIO ---
echo "### [4/9] Provisionando o Domínio $REALM ###"
samba-tool domain provision \
    --server-role=dc \
    --use-rfc2307 \
    --dns-backend=SAMBA_INTERNAL \
    --realm=$REALM \
    --domain=$WORKGROUP \
    --adminpass=$ADMIN_PASSWORD \
    --option="dns forwarder = $FORWARDER"

# --- 5. AJUSTES NO SMB.CONF ---
echo "### [5/9] Ajustando smb.conf (Interfaces e Nível 2016) ###"
# Adiciona as configurações no topo da seção [global]
sed -i "/\[global\]/a \        ad dc functional level = 2016" /etc/samba/smb.conf
sed -i "/\[global\]/a \        bind interfaces only = yes" /etc/samba/smb.conf
sed -i "/\[global\]/a \        interfaces = lo $INTERFACE" /etc/samba/smb.conf

# --- 6. ELEVAÇÃO DE NÍVEL FUNCIONAL (BANCO LDB) ---
echo "### [6/9] Elevando Níveis Funcionais da Floresta e Domínio via LDB ###"
BASE_DN="DC=${DOMAIN//./,DC=}"
cat <<EOF > raise_2016.ldif
dn: CN=NTDS Settings,CN=$NETBIOS_NAME,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,$BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7

dn: $BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7

dn: CN=Partitions,CN=Configuration,$BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7
EOF
ldbmodify -H /var/lib/samba/private/sam.ldb raise_2016.ldif

# --- 7. ATIVAÇÃO DA LIXEIRA ---
echo "### [7/9] Ativando Recycle Bin Feature ###"
cat <<EOF > enable_recycle.ldif
dn: CN=Partitions,CN=Configuration,$BASE_DN
changetype: modify
add: msDS-EnabledFeature
msDS-EnabledFeature: CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$BASE_DN
EOF
ldbmodify -H /var/lib/samba/private/sam.ldb enable_recycle.ldif

# --- 8. BLINDAGEM DO DNS E SERVIÇOS ---
echo "### [8/9] Desativando systemd-resolved e configurando DNS local ###"
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl mask systemd-resolved

# Remove o link simbólico do resolv.conf e cria um estático
rm -f /etc/resolv.conf
echo "names
