#!/usr/bin/env bash
    # fix_callado_wp.sh — rotina de recuperação para site WordPress exibindo "Index of /"
    # Uso: ./fix_callado_wp.sh /caminho/para/public_html
    set -euo pipefail
    TARGET="${1:-}"
    if [[ -z "$TARGET" || ! -d "$TARGET" ]]; then
      echo "Erro: informe o caminho da pasta do site (ex.: /home/usuario/public_html)"
      exit 1
    fi
    cd "$TARGET"

    timestamp=$(date +%F-%H%M%S)
    BACKUP_DIR="${TARGET%/}/backup-${timestamp}"
    mkdir -p "$BACKUP_DIR"

    echo "1) Backup de arquivos…"
    tar -czf "${BACKUP_DIR}/files-${timestamp}.tar.gz" .

    # Tentar identificar config do WordPress para backup do DB
    DB_NAME=""; DB_USER=""; DB_PASS=""; DB_HOST="localhost"
    if [[ -f wp-config.php ]]; then
      DB_NAME=$(php -r "include 'wp-config.php'; echo DB_NAME;")
      DB_USER=$(php -r "include 'wp-config.php'; echo DB_USER;")
      DB_PASS=$(php -r "include 'wp-config.php'; echo DB_PASSWORD;")
      DB_HOST=$(php -r "include 'wp-config.php'; echo DB_HOST;")
    fi

    if [[ -n "$DB_NAME" ]]; then
      echo "2) Backup do banco de dados ${DB_NAME}…"
      if command -v mysqldump >/dev/null 2>&1; then
        mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" | gzip > "${BACKUP_DIR}/db-${DB_NAME}-${timestamp}.sql.gz" || echo "Aviso: falha no dump do banco"
      else
        echo "Aviso: mysqldump não encontrado; pulei backup do banco."
      fi
    fi

    echo "3) Aplicar .htaccess seguro e impedir listagem…"
    if [[ -f ".htaccess" ]]; then cp ".htaccess" "${BACKUP_DIR}/htaccess-${timestamp}.bak"; fi
    cat > ".htaccess" <<'HT'
    Options -Indexes
    DirectoryIndex index.php index.html
    <FilesMatch "\.(bak|sql|ini|log|conf)$">
      Require all denied
    </FilesMatch>
    <Directory "wp-content/uploads">
      <FilesMatch "\.(php|php\..*)$">
        Require all denied
      </FilesMatch>
    </Directory>
    <IfModule mod_rewrite.c>
      RewriteEngine On
      RewriteCond %{QUERY_STRING} (base64_encode|GLOBALS|REQUEST) [NC]
      RewriteRule .* - [F]
    </IfModule>
HT

    echo "4) Quarentenar arquivos suspeitos de nomes hexadecimais…"
    mkdir -p "${BACKUP_DIR}/quarentena"
    find . -maxdepth 1 -type f -regextype posix-extended -regex '.*/[A-F0-9]{16,}.*' -print -exec mv {} "${BACKUP_DIR}/quarentena/" \; || true

    echo "5) Criar página temporária index.html se não houver index.php / index.html…"
    if [[ ! -f index.php && ! -f index.html ]]; then
      cat > index.html <<'HTML'
      <!doctype html><meta charset="utf-8"><title>Manutenção</title><h1>Voltamos em instantes</h1>
HTML
    fi

    echo "6) Reinstalar núcleo do WordPress via WP-CLI (se presente)…"
    if command -v wp >/dev/null 2>&1; then
      wp core verify-checksums || true
      wp core download --force || true
      wp core update || true
      wp plugin update --all || true
      wp theme update --all || true
    else
      echo "Aviso: wp-cli não encontrado. Se possível, instale e rode: wp core verify-checksums; wp core download --force"
    fi

    echo "7) Permissões seguras…"
    find . -type d -exec chmod 755 {} \;
    find . -type f -exec chmod 644 {} \;
    [[ -d wp-content/uploads ]] && chmod -R 775 wp-content/uploads || true

    echo "8) Limpeza básica de caches (se existir)…"
    rm -rf wp-content/cache/* 2>/dev/null || true

    cat <<MSG

    ✔ Finalizado.
    Backups e quarentena em: ${BACKUP_DIR}

    Próximos passos recomendados:
      - Trocar senhas de cPanel/FTP/DB/Admin WP.
      - Instalar Wordfence ou Sucuri e rodar um scan completo.
      - Conferir usuários admin no WP e remover desconhecidos.
      - Verificar wp_options e wp_posts por conteúdo suspeito.
    MSG