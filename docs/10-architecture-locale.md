# Quiz App — Architecture locale (J1)

![Architecture locale de Quiz App](architecture-locale.png)

## Services et réseau

| Service Compose | Rôle | Accès prévu |
| --- | --- | --- |
| `frontend` | Nginx sert les pages compilées par Vite et relaie `/api/` et `/health` vers Express. | `http://localhost:8087`, port 80 dans le conteneur |
| `backend` | Express gère les inscriptions, les résultats et l’administration. | `backend:3007` sur le réseau Compose |
| `db` | PostgreSQL stocke les utilisateurs, les résultats et les réponses. | `db:5432` sur le réseau Compose |

Seul le port de Nginx est publié. Le frontend envoie ses requêtes à `/api/` sur la même origine. Hors Compose, le serveur de développement Vite utilise le port `5173`. Les questionnaires sont définis dans les fichiers `questions_*.js` et intégrés au build Vite.

## Configuration et données

- PostgreSQL reçoit `POSTGRES_USER`, `POSTGRES_PASSWORD` et `POSTGRES_DB`. Le backend reçoit `DATABASE_URL`, construite avec ces valeurs et l’hôte `db`. Le fichier `database/init.sql`, monté dans `/docker-entrypoint-initdb.d/`, initialise le schéma au premier démarrage sur un volume vide.
- Un volume nommé conserve les données lors de la recréation du conteneur PostgreSQL. Le test de persistance garde ce volume.
- Le backend reçoit `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `JWT_SECRET` et `RESEND_API_KEY`. `FROM_EMAIL` définit l’expéditeur. Le code actuel exige une valeur pour `RESEND_API_KEY` au démarrage. Il tente l’envoi après l’enregistrement du résultat et journalise les échecs d’envoi sans annuler cet enregistrement.
- Traiter `POSTGRES_PASSWORD`, `DATABASE_URL` (qui contient le mot de passe), `ADMIN_PASSWORD`, `JWT_SECRET` et `RESEND_API_KEY` comme des secrets. Les valeurs locales restent dans le `.env` ignoré par Git. Le dépôt contient un `.env.example` avec des valeurs fictives.

## Vérification prévue

1. Ouvrir le quiz et vérifier `GET /health` via Nginx. Cette route vérifie que l’API répond, sans interroger PostgreSQL.
2. Créer un utilisateur, terminer un quiz et retrouver son résultat via `/gestion-quiz`.
3. Recréer les conteneurs en gardant le volume PostgreSQL, puis retrouver le même résultat.
