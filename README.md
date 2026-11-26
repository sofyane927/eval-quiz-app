# Quiz App - Projet d'évaluation Conteneurisation

## Mission

Vous intégrez une équipe DevOps chargée de **conteneuriser, sécuriser et déployer** l'application **Quiz App** sur Microsoft Azure, puis d'automatiser ses livraisons.

Le **code applicatif est fourni**. Votre mission concerne la conteneurisation, l'exploitation, la sécurité et le déploiement ; **ne modifiez pas la logique métier**. Une modification ciblée d'une question de quiz présente dans le code servira à démontrer le processus de livraison.

L'application comporte un frontend, un backend et une base PostgreSQL. Elle peut utiliser un service d'envoi d'emails ; les fonctionnalités qui en dépendent doivent être configurées uniquement si les accès nécessaires sont fournis.

## Résultat attendu

1. Faire fonctionner Quiz App localement avec Docker, Docker Compose et PostgreSQL persistant.
2. Construire des images sécurisées, analyser les vulnérabilités et documenter les corrections.
3. Déployer les images via Azure Container Registry (ACR) sur Azure Container Apps avec Azure CLI.
4. Connecter le backend à un PostgreSQL externe (Neon recommandé, ou solution compatible).
5. Mettre en place une CI/CD avec **GitHub Actions (recommandé)** ou **GitLab CI/CD (autorisé)** : contrôles sur Pull/Merge Request, scan Trivy bloquant, puis publication et déploiement après fusion dans `main`.
6. Présenter le travail et les preuves de chaque jalon lors d'une soutenance.

Les jalons sont validés progressivement. Une difficulté sur PostgreSQL cloud n'annule pas les jalons déjà acquis et n'interdit pas de démontrer la partie CI/CD technique.

## Travail à partir du dépôt officiel

Le formateur publie le code de départ et les consignes sur la branche `main` de son dépôt **de référence**. **Chaque groupe crée un fork de ce dépôt sur GitHub**, puis travaille exclusivement dans son fork. Les branches `feature/*` et les Pull Requests doivent cibler **`main` du fork du groupe**, jamais `main` du formateur.

- Sur GitHub : faites un fork **par groupe**, activez GitHub Actions si nécessaire et configurez vos propres secrets et autorisations Azure. Les secrets du dépôt d’origine ne sont pas transmis au fork.
- Sur GitLab (alternative admise) : créez un projet de groupe à partir du code de départ et utilisez des **Merge Requests dirigées vers `main` de votre projet**, pas vers le dépôt officiel.
- Aucun accès en écriture au dépôt du formateur n’est nécessaire. Transmettez au formateur l’URL de votre dépôt de groupe.

## Commencer

Lisez les documents dans cet ordre :

- [Présentation du projet](docs/01-presentation-projet.md)
- [Consignes techniques](docs/02-consignes-techniques.md)
- [Jalons et validations](docs/03-jalons-validation.md)
- [Exigences CI/CD](docs/04-pipeline-cicd.md)
- [Fonctionnalités avancées](docs/05-bonus-azure.md)
- [Soutenance et livrables](docs/06-soutenance-livrables.md)
- [Ressources officielles](docs/07-ressources.md)
- [Documentation technique de Quiz App : ports, API et configuration](docs/08-documentation-technique.md)
- [Utilisation responsable de l’IA](docs/09-utilisation-ia.md)
- [Schéma d’architecture locale (PNG)](docs/architecture-locale.png)
- [Schéma d’architecture Azure (PNG)](docs/architecture-azure.png)

**Important :** les comptes Azure for Students peuvent être limités par les crédits, quotas, régions et autorisations. Vérifiez les possibilités de votre abonnement avant de créer des ressources payantes. Supprimez les ressources inutilisées après sauvegarde des preuves et accord du formateur.

## Démarrer en local

Copiez `.env.example` vers `.env` et renseignez les valeurs locales. Lancez ensuite `docker compose up -d --build --wait`. Ouvrez le [quiz en local](http://localhost:8087/) ou [l’administration](http://localhost:8087/gestion-quiz).

Pour vérifier la persistance, terminez un quiz, retrouvez son score dans l’administration, puis lancez `docker compose up -d --force-recreate --wait` et vérifiez que le même résultat apparaît.

## Envoi des résultats avec Cloudflare

Pour activer l’envoi, renseignez `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_EMAIL_API_TOKEN` et `FROM_EMAIL` dans le `.env` local. Le jeton doit avoir la permission **Email Sending → Edit**. Renseignez l’adresse seule dans `FROM_EMAIL`, par exemple `quiz@example.com` pour un domaine activé dans Cloudflare. Avec Workers Free, saisissez une adresse de destination vérifiée dans le même compte pour recevoir le résultat par email. [Documentation Cloudflare](https://developers.cloudflare.com/email-service/api/send-emails/rest-api/)

Le backend peut démarrer et enregistrer les résultats sans ces variables. Un refus de Cloudflare laisse le résultat disponible dans l’administration.

## J2 — Sécurité des images

### Frontend

Trivy a relevé quatre vulnérabilités modérées dans l’image Nginx sur Alpine 3.24.4 (ARM64). Le Dockerfile met à jour `libexpat` de `2.10.0-r0` à `2.11.0-r0` et `zlib` de `1.3.2-r1` à `1.4-r0`. Après reconstruction, Trivy 0.76.2 a détecté zéro vulnérabilité dans cette image. [Rapport avant](docs/trivy/frontend-avant.json) · [Rapport après](docs/trivy/frontend-apres.json)

Pour reconstruire et scanner l’image avec Docker depuis Bash ou Zsh, lancez les commandes suivantes.

```bash
docker build -t quiz-frontend:j2 .
trivy_image=aquasec/trivy@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb
docker save quiz-frontend:j2 | docker run --rm -i --entrypoint /bin/sh "$trivy_image" \
  -c 'cat > /tmp/quiz-frontend.tar && trivy image --no-progress --scanners vuln --format json --input /tmp/quiz-frontend.tar' \
  > trivy-frontend-apres.json
```

### Backend

Le scan initial du backend (AMD64) comptait 32 alertes, dont 6 élevées. Le retrait du SDK Resend a supprimé deux alertes modérées. Le Dockerfile en deux étapes retire npm de l’image finale et met à jour `zlib` vers `1.4-r0` ainsi que `libcrypto3` et `libssl3` vers `3.5.9-r1`. Sur l’image reconstruite depuis le commit `f07bacb`, Trivy 0.71.0 a détecté **zéro vulnérabilité**. [Rapport initial](trivy-backend-avant.json) · [Rapport après retrait de Resend](trivy-backend-apres-cloudflare.json) · [Rapport après correction du Dockerfile](docs/trivy/backend-apres-correction.json)

```bash
docker build --platform linux/amd64 -t quiz-backend:j2-final ./backend
docker save quiz-backend:j2-final | docker run --rm -i --entrypoint /bin/sh aquasec/trivy:0.71.0 \
  -c 'cat > /tmp/backend.tar && trivy image --no-progress --scanners vuln --format json --input /tmp/backend.tar' \
  > backend-apres-correction.json
```

## J6-B — Déploiement automatique sur Azure

Le workflow **Deploy to Azure** se lance après une mise à jour de `main`. Il construit et scanne les deux images, les publie dans ACR avec le SHA complet du commit, puis déploie les images par digest. Si un commit plus récent arrive sur `main` pendant le scan, le workflow lui laisse le déploiement. Il affiche les révisions prêtes et vérifie `/health` depuis le frontend public.

Utilisez le registre et les applications `backend` et `quiz-frontend` déjà créés au J4, en mode de révision unique. Le frontend doit pouvoir joindre `backend:3007` via l’ingress TCP interne.

### Autoriser GitHub à déployer

Depuis PowerShell, utilisez le compte Azure qui gère le registre et les applications. Remplacez le nom du registre dans le bloc suivant. Il suppose que le registre et les deux applications sont dans le même groupe de ressources, comme dans votre déploiement initial.

```powershell
$acr = "NOM_DU_REGISTRE"
function Invoke-QuizAz {
    az @args
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI a échoué." }
}
$reg = Invoke-QuizAz acr show --name $acr -o json | ConvertFrom-Json
$rg = $reg.resourceGroup
$identity = Invoke-QuizAz identity create -n quiz-github-deploy -g $rg --location $reg.location -o json | ConvertFrom-Json
$subject = "repo:sofyane927@290667771/eval-quiz-app@1472864342:ref:refs/heads/main"

Invoke-QuizAz identity federated-credential create -n github-main --identity-name quiz-github-deploy -g $rg --issuer "https://token.actions.githubusercontent.com" --subject $subject --audiences "api://AzureADTokenExchange" -o none

$pushRole = if ($reg.roleAssignmentMode -match 'abac') { "Container Registry Repository Writer" } else { "AcrPush" }
Invoke-QuizAz role assignment create --assignee-object-id $identity.principalId --assignee-principal-type ServicePrincipal --role Reader --scope $reg.id -o none
Invoke-QuizAz role assignment create --assignee-object-id $identity.principalId --assignee-principal-type ServicePrincipal --role $pushRole --scope $reg.id -o none
foreach ($app in @("backend", "quiz-frontend")) {
    $appId = Invoke-QuizAz containerapp show -n $app -g $rg --query id -o tsv
    Invoke-QuizAz role assignment create --assignee-object-id $identity.principalId --assignee-principal-type ServicePrincipal --role "Container Apps Contributor" --scope $appId -o none
}

[ordered]@{
    AZURE_CLIENT_ID = $identity.clientId
    AZURE_TENANT_ID = $identity.tenantId
    AZURE_SUBSCRIPTION_ID = (Invoke-QuizAz account show --query id -o tsv)
    AZURE_ACR_NAME = $acr
    AZURE_RESOURCE_GROUP = $rg
} | ConvertTo-Json
```

Ajoutez les cinq valeurs affichées dans **Settings → Secrets and variables → Actions → Variables** sur le fork du groupe. La connexion OIDC est limitée à `main` et utilise un jeton temporaire. Les secrets Neon, Cloudflare et admin sont configurés sur le backend Azure. [Connexion Azure avec OIDC](https://learn.microsoft.com/fr-fr/azure/developer/github/connect-from-azure-openid-connect) · [Identifiant de sujet GitHub](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims)

Pour relancer le même déploiement manuellement, positionnez-vous sur un `main` propre et à jour. Connectez-vous avec `az login` et lancez `bash scripts/deploy.sh` depuis la racine du dépôt avec `AZURE_ACR_NAME` et `AZURE_RESOURCE_GROUP` définies. La machine doit disposer de Docker avec Buildx, Azure CLI, curl et jq.

## Preuves du scénario CI/CD

- Le test de la [PR de démonstration](https://github.com/sofyane927/eval-quiz-app/pull/4) simule le code de sortie `1` d’un scan critique. GitHub bloque alors la fusion. Le code du test a été retiré avant la fusion. [Run bloqué](https://github.com/sofyane927/eval-quiz-app/actions/runs/45834118053)
- Le [premier déploiement automatique](https://github.com/sofyane927/eval-quiz-app/actions/runs/45833158740) prouve la connexion OIDC, le tag commun `41afeca8845c90574fc1727aa0866d4a5a43794f` dans ACR et la mise à jour des deux Container Apps. Le [site public](https://quiz-frontend.redgrass-e29818c2.italynorth.azurecontainerapps.io/) relaie [`/health`](https://quiz-frontend.redgrass-e29818c2.italynorth.azurecontainerapps.io/health) vers le backend.

## Nettoyer Azure après l’évaluation

Conservez les preuves du déploiement et attendez l’accord du formateur. Depuis Bash, connectez-vous avec `az login` et définissez `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP` et `AZURE_ACR_NAME`, comme pour le déploiement. Lancez `bash scripts/destroy.sh` pour afficher l’inventaire du groupe dédié au TP. Le script exige la présence du registre, de l’environnement et des deux applications du quiz. Il bloque la suppression si une ressource hors périmètre apparaît.

Pour supprimer ce groupe et les ressources listées, relancez `bash scripts/destroy.sh --apply` et saisissez l’identifiant complet affiché. Cette suppression arrête le site Azure et efface le registre ACR. Les services Neon et Cloudflare se gèrent dans leurs comptes respectifs.

## Usage de l’IA

Nous avons utilisé Codex pour nous aider à écrire les Dockerfiles et les workflows, diagnostiquer les erreurs Azure, intégrer Cloudflare et préparer la documentation. Nous avons vérifié les propositions avec Docker Compose, les rapports Trivy, les contrôles GitHub et des essais sur Azure. Nous avons rejoué le parcours du quiz et vérifié que les scores apparaissaient dans PostgreSQL et dans l’administration. Le script de nettoyage a été testé avec des commandes Azure simulées.

## Règles générales

- Travail en groupe ; déposez le lien de votre dépôt et les preuves demandées au formateur.
- Versionnez les fichiers de configuration, les scripts et les workflows **que vous produisez**.
- Ne commitez jamais de mots de passe, URL PostgreSQL contenant des identifiants, clés API, secrets GitHub/GitLab ou fichiers `.env` réels.
- Une démonstration validée reste acquise même si les ressources cloud sont supprimées ensuite.
