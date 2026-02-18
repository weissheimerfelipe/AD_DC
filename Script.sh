#!/bin/bash

# ================================================================= #
# Script de Instalação Automática Samba AD DC - Nível Funcional 2016
# ================================================================= #

# 1. Variáveis de Configuração (Ajuste conforme necessário)
DOMAIN="flexclima.local"
REALM="FLEXCLIMA.LOCAL"
NETBIOS_NAME="DC01"
WORKGROUP="FLEXCLIMA"
ADMIN_PASSWORD="SuaSenhaForteAqui" # Altere após o primeiro login
FORWARDER="8.8.8.8"

echo "### Iniciando instalação do Samba AD DC ###"

# 2. Atualização do Sistema e Instalação de Dependências
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y
apt install samba krb5-config winbind smbclient ldb-tools -y

# 3. Limpeza de instalações anteriores
systemctl stop samba-ad-dc smbd nmbd winbind 2>/dev/null
systemctl disable samba-ad-dc smbd nmbd winbind 2>/dev/null
rm -f /etc/samba/smb.conf
rm -rf /var/lib/samba/private/*

# 4. Provisionamento do Domínio
echo "### Provisionando o Domínio $REALM ###"
samba-tool domain provision \
    --server-role=dc \
    --use-rfc2307 \
    --dns-backend=SAMBA_INTERNAL \
    --realm=$REALM \
    --domain=$WORKGROUP \
    --adminpass=$ADMIN_PASSWORD \
    --option="dns forwarder = $FORWARDER"

# 5. Configuração do Kerberos e DNS local
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
echo -e "nameserver 127.0.0.1\nsearch $DOMAIN" > /etc/resolv.conf

# 6. Ajuste de Nível Funcional para 2016 (Correção Manual do DC)
echo "### Elevando Nível Funcional para 2016 ###"
cat <<EOF > update_dc.ldif
dn: CN=NTDS Settings,CN=$NETBIOS_NAME,CN=Servers,CN=Default-First-Site-Name,CN=Sites,CN=Configuration,DC=${DOMAIN//./,DC=}
changetype: modify
replace: msDS-Behavior-Version
msDS-Behavior-Version: 7
EOF

ldbmodify -H /var/lib/samba/private/sam.ldb update_dc.ldif
samba-tool domain level raise --domain-level=2016
samba-tool domain level raise --forest-level=2016

# 7. Ativação da Lixeira do AD
echo "### Ativando a Lixeira do AD ###"
cat <<EOF > enable_recycle.ldif
dn: CN=Partitions,CN=Configuration,DC=${DOMAIN//./,DC=}
changetype: modify
add: msDS-EnabledFeature
msDS-EnabledFeature: CN=Recycle Bin Feature,CN=Optional Features,CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,DC=${DOMAIN//./,DC=}
EOF

ldbmodify -H /var/lib/samba/private/sam.ldb enable_recycle.ldif

# 8. Configuração de Hora e Permissões de Socket
chown root:lp /var/lib/samba/ntp_signd/
chmod 750 /var/lib/samba/ntp_signd/

# 9. Inicialização dos Serviços
systemctl unmask samba-ad-dc
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

echo "### Instalação Concluída com Sucesso! ###"
samba-tool domain level show
