## Installation du smart contract - école étna

1. Télécharger la derniere version de node js
2. Git clone le repo et cd vers le dossier

```bash
$ git clone git@rendu-git.etna-altwernance.net:module-6893/activity-38918/group-790626.git
```
```bash
$ cd d:/le/chemin/vers/dossier
```

3. Installer Truffle.

```bash
$ npm install truffle -g
```

4. Installer Ganache CLI.

```bash
$ npm install ganache-cli -g
```


8. La structure du projet doit correspondre :

```
.
└── jobillet
    ├── client
    │   ├── public
    │   └── src
    ├── contracts
    ├── migrations
```

9. Aller dans le dossier

```bash
$ cd jobillet
```

12. Aller sur le site https://infura.io/, s'inscrire et créer un projet.
Récuperer le projet id.

13. Aller sur le site https://metamask.io/, télécharger l'extension.
Récupérer la phrase a 12 mots du wallet créé.

13. Rendez vous dans le fichier `.env` et remplacer les variables.
`INFURA_PROJECT_ID`,
`WALLET_SEED_PHRASE`

13. Installer les dépendances du projet.

```bash
$ npm install
```

14. Compiler jobillet et le smart contract

```bash
$ truffle compile
```

15. Vous devriez voir ça :

```
Compiling ./contracts/Address.sol...
Compiling ./contracts/Bileto.sol...
Compiling ./contracts/Counter.sol...
Compiling ./contracts/Migrations.sol...
Compiling ./contracts/Ownable.sol...
Compiling ./contracts/ReentrancyGuard.sol...
Compiling ./contracts/SafeMath.sol...
Writing artifacts to ./build/contracts
```

16. Ouvrir un second terminal, aller dans le même dossier et lancer Ganache-CLI

```bash
$ ganache-cli
```

17. Vous devriez voir ça :

```
Ganache CLI v6.2.5 (ganache-core: 2.3.3)

Available Accounts
==================
(0) 0x6a8feaa56e675ba16b7234a6a4bf3af959b3844b (~100 ETH)
(1) 0xb1f86f840640fdcc302e849dfa126547a0239a5d (~100 ETH)
(2) 0x6708365569b57ff513122631e582d92813c7b32f (~100 ETH)
(3) 0x4980025f8deccd8d20ba62f4d8762270b15ec1d4 (~100 ETH)
(4) 0xfa94b34f930a81c9aff1ebd69f647a034c51491d (~100 ETH)
(5) 0xa658a738c9e291686ef9bec0422148cd00424f4a (~100 ETH)
(6) 0x777f185895fc7108932e761854b1cf3dc30da02d (~100 ETH)
(7) 0x919286bdd7543720af649ca80d01244c34c51fec (~100 ETH)
(8) 0x86ef9cd0536b7b0b75e2ee3aee20545c4cfb1912 (~100 ETH)
(9) 0x291e32bfe284a244ee01ca3dd4620db39ff452d9 (~100 ETH)

Private Keys
==================
(0) 0x222ac7993d645b2d01047c11931ab8b9ae500ef9b622e735d499d96a119a5092
(1) 0x5c2da5306ad390ce4f89caa5b4b78eb6823a996689b9478f961bd495ba55f351
(2) 0x0f41012153ffcc4eb6883d3b997fc9d1f66a70a2bafcba6caee4f127cb5e768e
(3) 0xd73de38722ca90d47138e27066f0e9e9725fbc326a59e04b6433d34aaf028496
(4) 0x4b03fdecd3b5b3c4168d6d2b8869c805181be124fc6f41a4d65d6770949e7780
(5) 0xf5499448c3b9e438c35cd916f99e673099905a5699a564e03213aba1de954b69
(6) 0xe5dd6bffb00d3a510b38f0faae4010f80fd3a03190affe415b7d5c5aed1be1c5
(7) 0xaafa29cebcd78c2b3c1edb6ec6d5802c4566be7f6fc9dd4136730df6fab820e8
(8) 0xa650b4470c7423580ab770a0b9103f1b9d2f5e49d6931dcf1cfb418d38fade91
(9) 0x2041eae18eaef42f999f57edcf7b1ef9d84932212e8e4d300d234422cee2b0c5

HD Wallet
==================
Mnemonic:      gallery fee stadium abstract narrow scene account loyal immense trend cinnamon final
Base HD Path:  m/44'/60'/0'/0/{account_index}

Gas Price
==================
20000000000

Gas Limit
==================
6721975

Listening on 127.0.0.1:8545
```

18. Garder le terminal ouvert et retourner sur le premier.

19. Déployer l'application vers Ganache cli.

```bash
$ truffle migrate
```

20. Vous devrez voir ça :

```
Starting migrations...
======================
> Network name:    'development'
> Network id:      1548661854443
> Block gas limit: 6721975


2_deploy_contracts.js
=====================

   Deploying 'Bileto'
   ------------------
   > transaction hash:    0x31da26f35f6efa10eb2510aa418a30880d48f393bde79686c6e9473306f34406
   > Blocks: 0            Seconds: 0
   > contract address:    0x9774783c766e27Ba1e7737b4474317a832Fb7Bf2
   > account:             0x6a8Feaa56E675ba16b7234A6A4Bf3Af959B3844B
   > balance:             99.89264496
   > gas used:            5104652
   > gas price:           20 gwei
   > value sent:          0 ETH
   > total cost:          0.10209304 ETH


   > Saving migration to chain.
   > Saving artifacts
   -------------------------------------
   > Total cost:          0.10209304 ETH


Summary
=======
> Total deployments:   1
> Final cost:          0.10209304 ETH
```

21. Lancer le script de test.

```bash
$ truffle test
```


23. Vous avez maintenant l'application jobillet lancer sur votre machine en developpement.


### Installation du client DApp

1. Garder le cmd de Ganache-CLI ouvert.

2. Aller sur MetaMask, récupérer la phrase de 12 mots généré par Ganache-cli.
L'inserer dans MetaMask.

3. Aller dans `/client`.

```bash
$ cd client
```

3. Installer les dépendances du projet.

```bash
$ npm install
```

4. Lancer l'application.

```bash
$ npm start
```

5. Vous devriez voir ça :

```
Compiled successfully!

You can now view bileto-client in the browser.

  Local:            http://localhost:3000/
  On Your Network:  http://10.0.1.8:3000/

Note that the development build is not optimized.
To create a production build, use npm run build.
```

6. MetaMask vous demande un connection. L'accepter.


7. Le client de l'application est maintenant lancé.
