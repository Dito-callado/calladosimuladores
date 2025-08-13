# Recuperação rápida do site (WordPress)

## O que fazer agora
1) Faça login no cPanel/SSH.
2) Entre na pasta do site, ex.: `/home/SEU_USUARIO/public_html`.
3) Envie os arquivos deste pacote para essa pasta:
   - `index.html` (página de manutenção temporária)
   - `.htaccess` (regras para desativar listagem e endurecer segurança)
   - `fix_callado_wp.sh` (script de recuperação)
4) Pelo SSH, execute:
   ```bash
   cd /home/SEU_USUARIO/public_html
   bash fix_callado_wp.sh /home/SEU_USUARIO/public_html
   ```

> Se você não tiver SSH, ao menos envie `index.html` e `.htaccess` por FTP — isso já tira o "Index of /" do ar enquanto o restante é corrigido.

## Dicas WP-CLI (opcional)
Se `wp` estiver disponível:
```bash
wp core verify-checksums
wp core download --force
wp plugin update --all
wp theme update --all
```

## SQL úteis (phpMyAdmin)
- Ver admins inesperados
  ```sql
  SELECT ID,user_login,user_email,user_status FROM wp_users;
  ```
- URLs do site
  ```sql
  SELECT option_name, option_value FROM wp_options WHERE option_name IN ('siteurl','home');
  ```

## Depois da limpeza
- Troque todas as senhas (cPanel/FTP/DB/WordPress).
- Ative 2FA no WordPress.
- Configure backup automático diário.