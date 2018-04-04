# StagingDatabase

Sada skriptů pro přípravu stagingové databáze z produkční

Po spuštění skriptu na lokálním serveru se nahraje na produkční server skript, který se na něm spustí a připraví dump databáze včetně jeho anonymizace. Poté se na lokální server stáhnou dumpy struktury a dat a obnoví se na lokálním serveru. Ostrá data tak nikdy neopustí produkční server.


## Spuštění

`./backup.sh -ipogslda`


**Parametry**

- `-i`: Cesta k souboru s identitou připojení k produkční MySQL databázi na ostrém serveru
- `-p`: Název produkční databáze, ze které bude proveden dump
- `-o`: Adresář na ostrém server, kam je možné ukládat dumpy a odkud se budou stahovat dumpy na lokální server
- `-g`: Mezerou oddělené názvy tabulek, jejichž data nebudou vůbec dumpována z produkční databáze
- `-s`: Název ssh konfigurace pro přístup na ostrý server
- `-l`: Cesta k souboru s identitou připojení k lokální MySQL databázi, kam budou data obnovena
- `-d`: Název lokální databáze, kam budou data obnovena
- `-a`: Mezerou oddělené cesty k SQL skriptům, které budou spuštěny na obnoveném dumpu na ostrém serveru, vhodné pro spuštění anonymizačních skriptů.

**Možné spuštění**

`./backup.sh -i /home/ostryuzivatel/mysql.cnf -p produkci_databaze -o /home/ostryuzivatel -g "logs" -s ostryserver -l /home/lokalniuzivatel/mysql.cnf -d testovaci_databaze -a /var/www/projekt/anonymizacni_skript.sql`


**Obsah `/home/ostryuzivatel/mysql.cnf`**

```
[client]
host=localhost
user=ostryuzivatelprodatabazi
password=heslo
```


**Obsah konfigurace SSH**

```
Host ostryserver
  HostName ostryserver.cz
  User uzivatelprossh
  IdentityFile ~/.ssh/id_rsa
```
