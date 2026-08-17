# Déploiement web — Risk management

Ce document décrit la mise en ligne de l'outil pour un accès par navigateur,
sans aucune installation sur le poste de l'utilisateur.

Deux voies possibles :

- **[Render](#0-mise-en-ligne-sur-render-le-plus-simple)** — une adresse
  publique en quelques clics, sans serveur à administrer. À privilégier pour
  démarrer.
- **[Docker sur votre serveur](#1-ce-qui-est-déployé)** — pour héberger
  vous-même, dans les murs de la banque.

---

## 0. Mise en ligne sur Render (le plus simple)

Render construit l'application à partir de votre dépôt GitHub et l'expose sur
une adresse du type `https://risque-management.onrender.com`, accessible du monde
entier, HTTPS compris. Aucun serveur à administrer.

### Étapes

1. **Publier le code** sur GitHub (`git push`).
2. Créer un compte sur **render.com** — la connexion par GitHub est la plus
   directe.
3. Dans Render : **New → Blueprint**, puis sélectionner le dépôt. Render lit le
   fichier `render.yaml` et prépare le service tout seul.
4. Render réclame deux valeurs, qui ne figurent volontairement pas dans le
   dépôt :

   | Variable | Valeur |
   |---|---|
   | `RWA_COMPTE_CONSULTATION_MDP` | Mot de passe de votre supérieur (12 caractères minimum) |
   | `RWA_COMPTE_EDITION_MDP` | Votre mot de passe |

5. **Deploy**. Le premier déploiement dure une dizaine de minutes : Render
   construit l'application web puis l'API.

Les deux comptes sont créés au premier démarrage. Le secret de signature des
jetons est généré par Render, il n'apparaît nulle part dans le code.

### Ce qu'il faut savoir sur l'offre gratuite

- **Mise en veille après 15 minutes sans visite.** Le premier chargement
  suivant prend une cinquantaine de secondes. L'offre payante (environ 7 $ par
  mois) supprime cette attente.
- **Les données reviennent à leur état initial à chaque déploiement.** Le
  disque n'est pas conservé. C'est sans conséquence pour une démonstration avec
  le portefeuille d'exemple ; pour saisir des expositions durablement, il faut
  l'offre payante et un disque persistant.
- **Vos données sortent du pays.** Render héberge en Europe ou aux États-Unis.
  Avec des données réelles, c'est une question à valider avec la conformité.

### Changer un mot de passe ensuite

Les variables d'environnement ne servent qu'à la **création** des comptes : un
compte existant n'est jamais modifié par elles, sinon un mot de passe changé
serait silencieusement rétabli au redémarrage suivant. Pour le modifier
ensuite, utiliser la console Render (offre payante) ou recréer le service.

---

---

## 1. Ce qui est déployé

```
Navigateur ──HTTPS──► Caddy (proxy) ──┬──► Nginx  : application Flutter Web
                                      └──► /api/* : FastAPI ──► SQLite (volume)
```

Trois conteneurs. L'application et l'API sont servies **sous le même domaine** :
il n'y a donc aucune requête d'origine croisée, et le cookie de session reste
strictement de première partie.

Le backend n'expose aucun port vers l'extérieur : il n'est joignable que par le
proxy.

### Deux rôles

| Rôle | Droits |
|---|---|
| `consultation` | Lecture de tous les écrans, export Excel, génération de rapports |
| `edition` | Accès complet : saisie, import, modification, suppression |

Le contrôle est appliqué **côté serveur**, pour toutes les routes : toute
méthode autre que `GET` exige le rôle `edition`. Le masquage des boutons dans
l'interface n'est qu'un confort de lecture — ce n'est pas lui qui protège.

---

## 2. Prérequis

- Docker et Docker Compose
- Flutter (sur le poste de build uniquement, pas sur le serveur)
- Un nom de domaine pointant vers le serveur, pour le HTTPS automatique

---

## 3. Configuration

```bash
cp .env.example .env
```

Générer le secret de signature des jetons :

```bash
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

Reporter la valeur dans `.env`, à la ligne `RWA_JWT_SECRET`. **L'API refuse de
démarrer sans ce secret**, ou s'il fait moins de 32 caractères.

Puis choisir la stratégie HTTPS dans `.env` :

**Serveur public avec nom de domaine** — certificat obtenu et renouvelé seul :

```bash
RWA_DOMAINE=risk.mabanque.ci
RWA_EMAIL=vous@mabanque.ci
RWA_CADDYFILE=./deploy/Caddyfile.public
```

**Réseau interne sans DNS public** — Let's Encrypt est inutilisable :

```bash
RWA_DOMAINE=risk.interne.local
RWA_CADDYFILE=./deploy/Caddyfile.interne
```

Dans ce cas, déposer le certificat fourni par la DSI dans `deploy/certs/` et
remplacer `tls internal` par `tls /certs/serveur.crt /certs/serveur.key` dans
`deploy/Caddyfile.interne`. Sans certificat officiel, Caddy en génère un lui-même
et le navigateur affichera un avertissement à chaque visite : acceptable pour un
essai, pas pour une mise à disposition durable.

Le fichier `.env` n'est jamais versionné.

---

## 4. Build et lancement

L'application web est construite **avant** l'image, sur le poste de
développement : embarquer le SDK Flutter dans l'image la ferait passer à
plusieurs gigaoctets pour un résultat identique.

```bash
cd frontend && flutter build web --release && cd ..
```

```bash
docker compose up -d --build
```

Vérifier que les trois conteneurs tournent :

```bash
docker compose ps
```

---

## 5. Créer le compte de votre supérieur

Une fois les conteneurs démarrés :

```bash
docker compose exec backend python -m app.auth.cli creer --identifiant superieur --role consultation --nom "Nom Prénom"
```

Le mot de passe est demandé de façon masquée. Il n'est **jamais** passé en
argument : il resterait dans l'historique du shell et serait visible dans la
liste des processus de la machine.

Contraintes : 12 caractères minimum, 72 octets maximum.

Créer ensuite votre propre compte, avec les droits complets :

```bash
docker compose exec backend python -m app.auth.cli creer --identifiant votrenom --role edition
```

Autres commandes disponibles :

```bash
docker compose exec backend python -m app.auth.cli lister
docker compose exec backend python -m app.auth.cli mot-de-passe --identifiant superieur
docker compose exec backend python -m app.auth.cli desactiver --identifiant superieur
docker compose exec backend python -m app.auth.cli reactiver --identifiant superieur
```

Changer un mot de passe ou désactiver un compte **révoque immédiatement les
sessions ouvertes** : sans cela, la manœuvre serait sans effet pendant douze
heures.

---

## 6. URL à transmettre

```
https://risk.mabanque.ci
```

C'est tout ce que votre supérieur reçoit, avec son identifiant et son mot de
passe. Il ouvre l'adresse, se connecte, et consulte. Rien à installer.

Le mot de passe doit être transmis par un canal distinct de l'URL — pas dans le
même message.

---

## 7. Sauvegarde

Tout l'état persistant tient dans un seul volume Docker : base SQLite,
sauvegardes automatiques, exports et journaux.

```bash
docker run --rm -v fodep_rwa_donnees:/donnees -v "$PWD":/sauvegarde alpine \
  tar czf /sauvegarde/rwa-$(date +%F).tar.gz -C /donnees .
```

À planifier quotidiennement. C'est le seul élément irremplaçable de
l'installation : les images se reconstruisent, les données saisies non.

---

## 8. Mise à jour

```bash
git pull
cd frontend && flutter build web --release && cd ..
docker compose up -d --build
```

Le volume de données n'est pas touché. La base embarquée dans l'image ne sert
qu'au tout premier démarrage, quand le volume est vide : une mise à jour
n'écrase jamais les saisies.

---

## 9. Spécificités Windows

Docker Desktop suffit. Deux différences :

- Utiliser PowerShell et non bash pour les commandes de sauvegarde ;
- Les ports 80 et 443 doivent être libres (IIS ou un autre serveur web local
  peut les occuper : `netstat -ano | findstr ":443"`).

Pour un essai local sans nom de domaine, garder `RWA_DOMAINE=localhost` et
`RWA_CADDYFILE=./deploy/Caddyfile.interne`, puis ouvrir `https://localhost` en
acceptant l'avertissement du navigateur.

---

## 10. Ce qui protège les données

| Élément | Mise en œuvre |
|---|---|
| Mots de passe | Empreinte bcrypt, jamais stockés en clair |
| Jeton d'accès | 60 minutes, gardé en mémoire vive du navigateur, jamais écrit sur disque |
| Jeton de renouvellement | Cookie `HttpOnly` + `Secure` + `SameSite=Strict`, illisible par le JavaScript, limité au chemin `/api/auth` |
| Sessions en base | Seule l'empreinte du jeton est conservée ; une copie de la base ne rejoue aucune session |
| Rotation | Chaque renouvellement révoque le précédent ; rejouer un ancien jeton échoue |
| Contrôle d'accès | Refus par défaut : tout appel exige un jeton, toute écriture exige le rôle `edition` |
| Transport | HTTPS imposé, HSTS activé |
| Isolation | Backend sans port publié, conteneur exécuté sans privilèges |
| Contenu | Politique de sécurité stricte : l'application ne charge aucune ressource externe |

Aucun service tiers n'intervient dans le traitement des données. Les seuls
appels sortants possibles sont l'obtention du certificat auprès de l'autorité
de certification, et — si vous l'activez explicitement — le moteur d'analyse de
courbe des taux, désactivé par défaut.

---

## 11. Vérifier après déploiement

```bash
# L'API répond
curl -k https://votre-domaine/api/

# Une lecture sans jeton doit être refusée
curl -k -o /dev/null -w "%{http_code}\n" https://votre-domaine/api/dashboard
# Attendu : 401
```

Puis, dans le navigateur : se connecter avec le compte `consultation` et
vérifier que le module « Importations » n'apparaît pas dans le menu, et que la
mention « Consultation » figure en en-tête.
