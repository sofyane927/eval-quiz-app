# 08 - Documentation technique de Quiz App

> Documentation de référence destinée aux étudiants. Elle décrit le fonctionnement existant de l'application, sans fournir les Dockerfiles, le fichier Docker Compose, les scripts Azure CLI ou les pipelines à réaliser pendant l'évaluation.

## 1. Présentation

**Quiz App** est une application de quiz sur des sujets techniques (notamment DevOps et Docker). Elle comporte une inscription utilisateur, l'enregistrement des résultats dans PostgreSQL, des notifications par email via Cloudflare Email Sending et un espace d'administration.

Les questionnaires sont définis dans le code source, notamment dans `questions_docker.js`, d'après l'arborescence fournie. Une modification de questionnaire pourra servir de scénario de test pour une Pull Request ou Merge Request et la chaîne CI/CD.

## 2. Composants et ports connus

| Composant  | Technologie / rôle                                              | Port ou point d'accès connu                                                                                               |
| ---------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Frontend   | Application web HTML, JavaScript, CSS ; développement avec Vite | **5173** en développement (`npm run dev` à la racine)                                                                     |
| Nginx      | Serveur web et reverse proxy en production                      | **8087 sur l'hôte** dans la configuration Docker Compose d'origine ; Nginx reçoit le trafic sur **80 dans son conteneur** |
| Backend    | API **Node.js / Express** (`backend/server.js`)                 | **3007** (`cd backend && npm run dev`)                                                                                    |
| PostgreSQL | Base relationnelle, résultats et données persistantes           | **5432** (port PostgreSQL employé dans l'URL de connexion d'origine)                                                      |
| Cloudflare Email Sending | Service tiers d'envoi d'emails | API HTTPS externe, activée si les variables d’envoi sont renseignées |

**Attention :** le port `5173` est le port de développement Vite, pas nécessairement le port à exposer pour le frontend conteneurisé en production. Le port `8087` est le port d'accès local de la solution Docker Compose initiale ; les étudiants devront concevoir leur propre exposition réseau.

### Points d'entrée fonctionnels documentés

- Quiz : `http://localhost:8087`
- Administration : `http://localhost:8087/gestion-quiz`

Ces URL correspondent à l'ancienne configuration locale Docker Compose. Les URL des nouvelles solutions seront définies par les étudiants.

## 3. Démarrer le projet hors Docker

**Prérequis documenté :** Node.js 20 ou supérieur.

### Frontend

À la racine du projet :

```bash
npm install
npm run dev
```

Adresse de développement indiquée dans le README initial : `http://localhost:5173`.

### Backend

Dans un autre terminal :

```bash
cd backend
npm install
npm run dev
```

Adresse de développement indiquée dans le README initial : `http://localhost:3007`.

Le fonctionnement des opérations dépendantes de PostgreSQL suppose une base accessible et correctement initialisée. Le README d'origine ne donne pas de procédure autonome complète de lancement PostgreSQL hors Docker.

## 4. Variables d'environnement

Le projet utilise les variables suivantes :

| Variable            | Rôle                                                                       |
| ------------------- | -------------------------------------------------------------------------- |
| `POSTGRES_USER`     | Utilisateur de PostgreSQL local                                            |
| `POSTGRES_PASSWORD` | Mot de passe PostgreSQL local                                              |
| `POSTGRES_DB`       | Nom de la base locale                                                      |
| `DATABASE_URL`      | URL de connexion PostgreSQL fournie au backend dans le déploiement initial |
| `CLOUDFLARE_ACCOUNT_ID` | Identifiant du compte Cloudflare |
| `CLOUDFLARE_EMAIL_API_TOKEN` | Jeton Cloudflare avec la permission Email Sending → Edit |
| `FROM_EMAIL` | Adresse d’expédition sur un domaine activé dans Cloudflare |
| `ADMIN_USERNAME`    | Identifiant de l'administrateur                                            |
| `ADMIN_PASSWORD`    | Mot de passe administrateur                                                |
| `JWT_SECRET`        | Secret JWT                                                                 |

Docker Compose construit une URL de connexion locale de la forme `postgresql://<utilisateur>:<mot-de-passe>@db:5432/<base>`. Le nom `db` fait référence au service PostgreSQL local. Les trois variables d’envoi d’email sont facultatives pour enregistrer les résultats.

**Sécurité :** conserver les secrets hors du dépôt. Le fichier `.env.example`, s'il est fourni, doit contenir seulement des valeurs fictives et des indications de configuration.

## 5. PostgreSQL et initialisation

Le code d'origine comporte un fichier `database/init.sql`, décrit comme le **schéma PostgreSQL**. Les étudiants doivent s'en servir pour déterminer comment initialiser la base de données locale puis, le cas échéant, la base PostgreSQL externe.

- **En local :** utiliser une instance PostgreSQL orchestrée par Docker Compose, avec stockage persistant.
- **Sur Azure :** connecter le backend à une instance PostgreSQL externe compatible, par exemple Neon. Le choix et la configuration doivent être documentés ; la connexion doit être sécurisée.
- **Validation :** création d'un utilisateur, réponse à un quiz, conservation des résultats après redémarrage.

Les modalités exactes d'exécution du fichier SQL et la compatibilité du backend avec la configuration TLS de Neon sont à vérifier dans le code et par des tests. Le README seul ne les confirme pas.

## 6. API documentée

### Routes publiques

| Méthode | Route          | Fonction                                                |
| ------- | -------------- | ------------------------------------------------------- |
| `POST`  | `/api/users`   | Créer un utilisateur                                    |
| `POST`  | `/api/results` | Sauvegarder les résultats et déclencher l'envoi d'email |
| `GET`   | `/health`      | Vérification de santé                                   |

### Routes administrateur (JWT)

| Méthode  | Route                            | Fonction                         |
| -------- | -------------------------------- | -------------------------------- |
| `POST`   | `/api/admin/login`               | Authentification administrateur  |
| `GET`    | `/api/admin/results`             | Liste paginée des résultats      |
| `GET`    | `/api/admin/results/export`      | Export CSV                       |
| `DELETE` | `/api/admin/results/old?days=30` | Suppression de résultats anciens |

Les corps de requête, codes HTTP, réponses JSON et la dépendance éventuelle de `/health` à la base de données ne sont **pas précisés dans le README d'origine** : consulter `backend/server.js` pour les vérifier.

## 7. Organisation du code fourni

Le dépôt initial décrit les fichiers applicatifs suivants :

```text
quiz-app-evaluation/
├── README.md                        # Consignes de l'évaluation
├── docs/                            # Documents pédagogiques
├── backend/
│   ├── package.json
│   └── server.js                   # API Express
├── database/
│   └── init.sql                    # Schéma PostgreSQL
├── nginx/
│   └── nginx.conf                  # Configuration existante, si conservée
├── public/
│   ├── admin.js
│   └── admin.css
├── index.html
├── gestion-quiz.html
├── main.js
├── style.css
└── questions_docker.js
```

Cette arborescence est indicative et devra être confrontée au dépôt réellement fourni. Les fichiers de solution d'origine (`Dockerfile`, `backend/Dockerfile`, `database/Dockerfile`, `docker-compose.yml`, `.gitlab-ci.yml`) ne font pas partie du dépôt de départ des étudiants.

## 8. Mission d'analyse préalable — Jalon 1

Avant d'écrire les fichiers de conteneurisation, les étudiants doivent :

1. Identifier les composants, leurs rôles et leurs dépendances.
2. Relever les ports utilisés en développement et expliquer ceux qui devront être exposés.
3. Repérer les variables de configuration, distinguer paramètres publics et secrets.
4. Identifier les routes utilisables pour les tests d'intégration et de santé.
5. Expliquer où se trouvent les questionnaires et comment les résultats sont conservés.
6. Réaliser un schéma d'architecture **locale** montrant les communications entre composants.
7. Justifier leurs choix de conteneurisation et de persistance.

**Livrable :** schéma d'architecture et courte description technique dans le dépôt du groupe.

## 9. Règle d'évaluation et de livraison

Chaque groupe travaille dans son propre fork du dépôt de référence (ou dans un projet GitLab équivalent si cette plateforme a été autorisée). Les Pull Requests ciblent `main` **dans le fork du groupe**, jamais dans le dépôt de référence du formateur.

GitHub Actions est recommandé ; GitLab CI/CD est admis. Une demande de fusion doit déclencher les vérifications et le scan Trivy ; après validation et fusion, une chaîne de déploiement publie les images dans Azure Container Registry et met à jour Azure Container Apps.

Chaque jalon donne lieu à une courte démonstration et au dépôt de preuves expurgées de secrets. Les critères d'acceptation et l'organisation des validations figurent dans `docs/03-jalons-validation.md` ; aucun barème chiffré n'est publié ici.
