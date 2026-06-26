# juribook-docker

Infrastructure locale de **JuriBook** : orchestre Kafka (KRaft), 4 bases PostgreSQL et tous les microservices via Docker Compose.

## Structure du dépôt

```
juribook-docker/
└── docker/
    ├── docker-compose.yml          # Orchestration complète (infra + services)
    ├── env/
    │   ├── .env.example            # Variables d'environnement, à copier en .env
    │   └── .env                    # (ignoré par git)
    └── init-scripts/
        ├── init-authdb.sql         # Création de l'utilisateur authdb
        ├── init-lawyerdb.sql       # Création de l'utilisateur lawyerdb
        ├── init-bookingdb.sql      # Création de l'utilisateur bookingdb
        └── init-auditdb.sql        # Création de l'utilisateur auditdb
```

## Prérequis

- Docker Desktop ≥ 4.x
- Les repos des microservices clonés **au même niveau** que `juribook-docker` :

```
Projets-Web/
├── juribook-docker/       
├── juribook-auth-service/
├── juribook-lawyer-service/
├── juribook-booking-service/
├── juribook-notification-service/
├── juribook-audit-service/
└── juribook-frontend/
```

## Mise en route

```bash
# 1. Copier le fichier d'environnement
cp docker/env/.env.example docker/env/.env

# 2. Se placer dans le bon dossier
cd docker/

# 3. Démarrer toute l'infrastructure
docker compose up -d
```

---

## Commandes utiles

```bash
# Depuis juribook-docker/docker/

# Démarrer tout
docker compose up -d

# Démarrer uniquement l'infra (Kafka + bases)
docker compose up -d kafka postgres-auth postgres-lawyer postgres-booking postgres-audit

# Démarrer un service spécifique
docker compose up -d auth-service
docker compose up -d lawyer-service

# Voir les logs d'un service
docker compose logs -f auth-service
docker compose logs -f lawyer-service

# Redémarrer un service après modification
docker compose restart auth-service

# Arrêter tout (sans supprimer les volumes)
docker compose down

# Arrêter tout et supprimer les données
docker compose down -v

# Rebuild et redémarrer un service
docker compose up -d --build auth-service
docker compose up -d --build lawyer-service
```

---

## Services

### Infrastructure

| Conteneur | Image | Port hôte | Description |
|---|---|---|---|
| `juribook-kafka` | confluentinc/cp-kafka:7.6.1 | 9092 | Kafka KRaft (sans Zookeeper) |
| `juribook-postgres-auth` | postgres:16-alpine | 5432 | Base PostgreSQL auth-service |
| `juribook-postgres-lawyer` | postgres:16-alpine | 5433 | Base PostgreSQL lawyer-service |
| `juribook-postgres-booking` | postgres:16-alpine | 5434 | Base PostgreSQL booking-service |
| `juribook-postgres-audit` | postgres:16-alpine | 5435 | Base PostgreSQL audit-service |

### Microservices

| Conteneur | Port hôte | Description |
|---|---|---|
| `juribook-auth` | 8081 | auth-service - authentification, JWT, rôles |
| `juribook-lawyer` | 8082 | lawyer-service - profils avocats, recherche |

### Health checks

```bash
curl http://localhost:8081/actuator/health   # auth-service
curl http://localhost:8082/actuator/health   # lawyer-service
```

---

## Kafka (mode KRaft)

Kafka tourne sans Zookeeper grâce au mode KRaft natif (depuis Kafka 3.3+).

| Listener | Usage | Port |
|---|---|---|
| `PLAINTEXT` | Communication inter-conteneurs | 29092 |
| `PLAINTEXT_HOST` | Accès depuis la machine hôte | 9092 |
| `CONTROLLER` | Coordination KRaft interne | 9093 |

**Topics créés automatiquement** (`KAFKA_AUTO_CREATE_TOPICS_ENABLE: true`) :
- `audit-events` — événements d'audit produits par les services

---

## Bases PostgreSQL

Chaque microservice a sa propre base de données (principe microservices, pas de base partagée).

| Base | Port | Microservice |
|---|---|---|
| `authdb` | 5432 | auth-service - utilisateurs, refresh tokens |
| `lawyerdb` | 5433 | lawyer-service - profils avocats, spécialités |
| `bookingdb` | 5434 | booking-service - rendez-vous |
| `auditdb` | 5435 | audit-service - logs d'événements |

### Accès aux bases

```bash
# auth-service
docker exec -it juribook-postgres-auth psql -U juribook -d authdb

# lawyer-service
docker exec -it juribook-postgres-lawyer psql -U juribook -d lawyerdb

# booking-service
docker exec -it juribook-postgres-booking psql -U juribook -d bookingdb

# audit-service
docker exec -it juribook-postgres-audit psql -U juribook -d auditdb
```

### Réinitialiser une base (dev uniquement)

```bash
# Exemple : réinitialiser lawyerdb (repart de zéro + rejoue les migrations Flyway)
docker exec -it juribook-postgres-lawyer psql -U juribook -d lawyerdb \
  -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker compose restart lawyer-service
```

---

## Variables d'environnement

Copier `docker/env/.env.example` en `docker/env/.env` et adapter si nécessaire.

| Variable | Description | Valeur par défaut |
|---|---|---|
| `POSTGRES_USER` | Utilisateur PostgreSQL partagé | `juribook` |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL | `juribook` |
| `JWT_SECRET` | Secret JWT partagé entre les services | valeur de dev (min. 256 bits) |

> ⚠️ Ne jamais commiter le fichier `.env` — il est dans `.gitignore`.

---

## Dépendances entre services

```
kafka ──────────────────────────────────┐
                                        ↓
postgres-auth ──→ auth-service ─────→ lawyer-service
postgres-lawyer ──────────────────────────↑
```

Le `lawyer-service` démarre uniquement quand `auth-service` est `healthy`, il a besoin que les tokens JWT soient émettables pour valider les requêtes.

---

## Volumes persistants

Les données survivent aux redémarrages grâce aux volumes Docker nommés :

| Volume | Contenu |
|---|---|
| `kafka-data` | Topics et offsets Kafka |
| `postgres-auth-data` | Données authdb |
| `postgres-lawyer-data` | Données lawyerdb |
| `postgres-booking-data` | Données bookingdb |
| `postgres-audit-data` | Données auditdb |

```bash
# Lister les volumes
docker volume ls | grep juribook

# Supprimer tous les volumes (reset complet)
docker compose down -v
```

---

## Réseau

Tous les conteneurs communiquent sur le réseau bridge `juribook-network`. Les services s'appellent par leur nom de conteneur :

```yaml
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres-auth:5432/authdb
SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:29092
```

---

## Swagger UI des services

| Service | URL |
|---|---|
| auth-service | http://localhost:8081/swagger-ui.html |
| lawyer-service | http://localhost:8082/swagger-ui.html |