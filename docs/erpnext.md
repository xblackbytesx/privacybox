# ERPnext

## Steps:
```
docker-compose up -d 
```

#### Create a site:
```sh
docker-compose exec erpnext-backend \
    bench new-site localhost \
        --mariadb-root-password secret123 \
        --admin-password secret123
```

```sh
docker-compose exec erpnext-backend bench --site localhost install-app erpnext
```

```sh
docker-compose restart erpnext-backend
```

Access your configured URL (e.g. https://erp.privacy.box) and use the default admin credentials:  

username: `Administrator`  
password: `admin` (or your configured password above)  

Next up it's time to configure your installation, enjoy!