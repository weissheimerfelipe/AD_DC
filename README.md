#  Samba AD DC Auto-Install (Windows Server 2016 Level)

Este repositório contém um script de automação para transformar um servidor **Ubuntu (22.04 ou 24.04)** em um **Controlador de Domínio Active Directory** totalmente funcional, utilizando o Samba 4.

##  Diferenciais deste Script

Diferente de instalações padrão, este script já entrega o ambiente "pronto para produção" com:
- **Nível Funcional 2016:** Configuração avançada de esquema para compatibilidade com sistemas modernos.
- **Lixeira do AD Ativa:** Recurso de `Recycle Bin` habilitado nativamente via LDB.
- **Correção de DNS (Porta 53):** Desativa e mascara automaticamente o `systemd-resolved` para evitar conflitos.
- **Provisionamento RFC2307:** Suporte a atributos Unix para ambientes híbridos Linux/Windows.
- **Kerberos Configurado:** Integração total para autenticação de tickets.



##  Pré-requisitos

- Servidor Ubuntu 24.04 LTS (recomendado).
- IP Estático configurado na máquina.
- Acesso root ou sudo.

##  Como usar

1. **Clone o repositório:**

2. **Dê permissão de execução:**
    chmod +x install.sh

3. **Execute o script:**
    sudo ./install.sh
