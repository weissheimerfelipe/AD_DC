#!/bin/bash

# ================================================================= #
# SCRIPT DE PROVISIONAMENTO SAMBA AD DC - NÍVEL 2016 + LIXEIRA
#
# Compatível com: Ubuntu 22.04 / 24.04 (Noble)
# ================================================================= #

# --- VARIÁVEIS (AJUSTE AQUI) ---
DOMAIN="flexclima.local"
REALM="FLEXCLIMA.LOCAL"
NETBIOS_NAME="DC01"
WORKGROUP="FLEXCLIMA"
ADMIN_PASSWORD="SuaSenhaForteAqui"
FORWARDER="8.8.8.8"

# --- 1. LIMPEZA E INSTALAÇÃO ---
echo "--- Removendo instalações antigas e instalando pacotes ---"
systemctl stop samba-ad-dc smbd nmbd winbind 2>/dev/null
apt purge samba* -y && apt autoremove -y
rm -rf /etc/samba /var/lib/samba /var/cache/samba /run/samba
apt update && apt install samba krb5-config winbind smbclient ldb-tools -y

# --- 2. PROVISIONAMENTO ---
echo "--- Provisionando o domínio $REALM ---"
samba-tool domain provision \
    --server-role=dc \
    --use-rfc2307 \
    --dns-backend=SAMBA_INTERNAL \
    --realm=$REALM \
    --domain=$WORKGROUP \
    --adminpass=$ADMIN_PASSWORD \
    --option="dns forwarder = $FORWARDER"

# --- 3. CONFIGURAÇÃO DE REDE ---
echo -e "nameserver 127.0.0.1\nsearch $DOMAIN" > /etc/resolv.conf

# --- 4. FORÇAR NÍVEL 2016 NOS 3 NÍVEIS (DC, DOMÍNIO, FLORESTA) ---
echo "--- Aplicando níveis funcionais via LDIF ---"
# Criando DN amigável para o script
BASE_DN="DC=${DOMAIN//./,DC=}"

cat <<EOF > raise_2016.ldif
# 1. Objeto do DC (Servidor)
dn: CN=NTDS Settings,CN=$NETBIOS_NAME,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,$BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7

# 2. Objeto do Domínio
dn: $BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7

# 3. Objeto da Floresta (Partições)
dn: CN=Partitions,CN=Configuration,$BASE_DN
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7
EOF

ldbmodify -H /var/lib/samba/private/sam.ldb raise_2016.ldif

# --- 5. ATIVAÇÃO DA LIXEIRA (RECYCLE BIN) ---
echo "--- Ativando a Lixeira do AD ---"
cat <<EOF > enable_recycle.ldif
dn: CN=Partitions,CN=Configuration,$BASE_DN
changetype: modify
add: msDS-EnabledFeature
msDS-EnabledFeature: CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$BASE_DN
EOF

ldbmodify -H /var/lib/samba/private/sam.ldb enable_recycle.ldif

# --- 6. SINCRONISMO DE HORA ---
chown root:lp /var/lib/samba/ntp_signd/
chmod 750 /var/lib/samba/ntp_signd/

# --- 7. FINALIZAÇÃO E REINICIALIZAÇÃO ---
echo "--- Iniciando o serviço Samba AD DC ---"
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl restart samba-ad-dc

# Aguarda 5 segundos para o serviço subir totalmente
sleep 5

# --- 8. VALIDAÇÃO ---
echo "--- VALIDAÇÃO FINAL ---"
samba-tool domain level show
