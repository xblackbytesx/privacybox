# Creating database

Login as root user
```
mysql -u root -p
```

Show all users:
```
SELECT User, Host, Password FROM mysql.user;
```

Show all databases:
```
SHOW DATABASES;
```