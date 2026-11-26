# J2 — Sécurité de l’image frontend

Le premier scan Trivy de l’image finale Nginx sur Alpine 3.24.4 (ARM64) a signalé quatre vulnérabilités modérées. Elles concernaient deux paquets système de l’image d’exécution.

| Paquet | Version avant | Version après | Alertes du scan initial |
| --- | --- | --- | --- |
| `libexpat` | `2.10.0-r0` | `2.11.0-r0` | CVE-2026-124317, CVE-2026-128241, CVE-2026-134703 |
| `zlib` | `1.3.2-r1` | `1.4-r0` | CVE-2026-4738 |

Le Dockerfile met à jour ces deux paquets depuis les dépôts Alpine dans l’étape Nginx. Après reconstruction, les versions installées ont été vérifiées avec `apk list --installed libexpat zlib`.

Le second scan avec Trivy 0.76.2 a détecté **zéro vulnérabilité** dans l’image frontend reconstruite. Les quatre alertes initiales ont disparu du rapport. L’identifiant de l’image scannée passe de `sha256:1f7fe0d8b5bf` à `sha256:8e9c889b23ca`. [Rapport avant](trivy/frontend-avant.json) · [Rapport après](trivy/frontend-apres.json)

## Refaire le scan

Depuis la racine du dépôt, avec Docker et un terminal Bash ou Zsh, construire l’image puis transmettre son archive à Trivy.

```bash
docker build -t quiz-frontend:j2 .
trivy_image=aquasec/trivy@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb
docker save quiz-frontend:j2 | docker run --rm -i --entrypoint /bin/sh "$trivy_image" \
  -c 'cat > /tmp/quiz-frontend.tar && trivy image --no-progress --scanners vuln --format json --input /tmp/quiz-frontend.tar' \
  > trivy-frontend-apres.json
```

Le test de fonctionnement avec Docker Compose a confirmé les pages du quiz et de l’administration, `GET /health` et une inscription via `POST /api/users` (HTTP 201). Le scan du backend et le contrôle Trivy en CI font l’objet de vérifications distinctes.
