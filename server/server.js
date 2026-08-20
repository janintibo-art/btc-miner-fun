'use strict';

// Serveur de la chaine partagee.
//
// Ce n'est pas un noeud pair a pair : c'est un coordinateur, comme un pool.
// Il n'invente rien, ne mine pas, et ne peut pas fabriquer de blocs : il ne
// fait qu'accepter ceux qui apportent une preuve de travail valable, et
// conserver la chaine qui totalise le plus de travail.
//
// Consequence assumee : il faut faire confiance a celui qui l'heberge pour
// ne pas effacer la chaine. Cette confiance est exactement ce dont Bitcoin se
// passe, et c'est ce qui separe ce serveur d'un vrai reseau.

const http = require('http');
const fs = require('fs');
const path = require('path');
const {
  blockHash,
  hasValidShape,
  meetsTarget,
  verifyChain,
  totalWork,
  expectedBits,
  expectedReward,
} = require('./chain.js');

const PORT = process.env.PORT || 8080;
const FICHIER = process.env.CHAIN_FILE || path.join(__dirname, 'chaine.json');
const MAX_BLOCS = 100000;
const MAX_CORPS = 4 * 1024 * 1024; // 4 Mio : de quoi loger une longue chaine

let etat = { rules: null, blocks: [] };

// --- Persistance -----------------------------------------------------------
// Sur un hebergement gratuit, le disque est souvent efface au redemarrage.
// Ce n'est pas fatal : le premier mineur a se synchroniser repousse sa copie,
// et la regle du travail cumule la fait adopter. La chaine se reconstitue.

function charger() {
  try {
    const brut = fs.readFileSync(FICHIER, 'utf8');
    const lu = JSON.parse(brut);
    const verdict = verifyChain(lu.blocks || [], lu.rules);
    if (verdict.valid) {
      etat = { rules: lu.rules || null, blocks: lu.blocks || [] };
      console.log(`Chaine chargee : ${etat.blocks.length} blocs.`);
    } else {
      console.log(`Fichier ignore (${verdict.problem}) : on repart a vide.`);
    }
  } catch (e) {
    console.log('Aucune chaine sur le disque : demarrage a vide.');
  }
}

let ecritureEnCours = false;
function sauvegarder() {
  if (ecritureEnCours) return;
  ecritureEnCours = true;
  const contenu = JSON.stringify(etat);
  fs.writeFile(FICHIER + '.tmp', contenu, (err) => {
    if (!err) {
      // Ecriture puis renommage : jamais de fichier a moitie ecrit.
      fs.rename(FICHIER + '.tmp', FICHIER, () => {});
    }
    ecritureEnCours = false;
  });
}

// --- Utilitaires HTTP ------------------------------------------------------

function repondre(res, code, donnees) {
  const corps = JSON.stringify(donnees);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Cache-Control': 'no-store',
  });
  res.end(corps);
}

function lireCorps(req) {
  return new Promise((resolve, reject) => {
    let taille = 0;
    const morceaux = [];
    req.on('data', (morceau) => {
      taille += morceau.length;
      if (taille > MAX_CORPS) {
        reject(new Error('corps trop volumineux'));
        req.destroy();
        return;
      }
      morceaux.push(morceau);
    });
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(morceaux).toString('utf8')));
      } catch (e) {
        reject(new Error('JSON invalide'));
      }
    });
    req.on('error', reject);
  });
}

function resume() {
  const tete = etat.blocks[etat.blocks.length - 1] || null;
  return {
    height: etat.blocks.length,
    tip: tete ? blockHash(tete) : null,
    bits: tete ? tete.b : null,
    rules: etat.rules,
    work: totalWork(etat.blocks).toString(),
  };
}

// --- Le serveur ------------------------------------------------------------

const serveur = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'OPTIONS') return repondre(res, 204, {});

  // Etat de la chaine : ce que l'application interroge en boucle.
  if (req.method === 'GET' && url.pathname === '/head') {
    return repondre(res, 200, resume());
  }

  // La chaine complete.
  if (req.method === 'GET' && url.pathname === '/chain') {
    return repondre(res, 200, etat);
  }

  // Soumission d'un bloc unique : le cas normal quand on mine.
  if (req.method === 'POST' && url.pathname === '/block') {
    let bloc;
    try {
      bloc = await lireCorps(req);
    } catch (e) {
      return repondre(res, 400, { accepted: false, reason: e.message });
    }

    if (!hasValidShape(bloc)) {
      return repondre(res, 400, { accepted: false, reason: 'bloc mal forme' });
    }
    if (etat.blocks.length >= MAX_BLOCS) {
      return repondre(res, 507, { accepted: false, reason: 'chaine pleine' });
    }

    const tete = etat.blocks[etat.blocks.length - 1];
    if (!tete) {
      return repondre(res, 409, {
        accepted: false,
        reason: 'aucune chaine ici : envoie la tienne sur /chain',
        height: 0,
      });
    }
    if (bloc.h !== tete.h + 1) {
      return repondre(res, 409, {
        accepted: false,
        reason: `hauteur attendue ${tete.h + 1}`,
        height: etat.blocks.length,
        tip: blockHash(tete),
      });
    }
    if (bloc.p !== blockHash(tete)) {
      // Quelqu'un d'autre a trouve le bloc en premier : c'est la course.
      return repondre(res, 409, {
        accepted: false,
        reason: 'un autre bloc a ete accepte avant le tien',
        height: etat.blocks.length,
        tip: blockHash(tete),
      });
    }
    // Difficulte et recompense sont recalculees : le bloc ne peut pas se
    // les attribuer lui-meme.
    const bitsAttendus = expectedBits(etat.blocks, etat.rules);
    if (bloc.b !== bitsAttendus) {
      return repondre(res, 400, {
        accepted: false,
        reason: 'difficulte non conforme',
        expectedBits: bitsAttendus,
      });
    }
    const recompense = expectedReward(bloc.h, etat.rules);
    if (Math.abs(bloc.r - recompense) > 1e-9) {
      return repondre(res, 400, {
        accepted: false,
        reason: 'recompense non conforme',
        expectedReward: recompense,
      });
    }
    if (bloc.t < tete.t) {
      return repondre(res, 400, { accepted: false, reason: 'horodatage en arriere' });
    }
    if (!meetsTarget(bloc)) {
      return repondre(res, 400, {
        accepted: false,
        reason: 'preuve de travail insuffisante',
      });
    }

    etat.blocks.push(bloc);
    sauvegarder();
    console.log(`Bloc ${bloc.h} accepte : ${blockHash(bloc).slice(0, 16)}...`);
    return repondre(res, 200, {
      accepted: true,
      height: etat.blocks.length,
      tip: blockHash(bloc),
    });
  }

  // Soumission d'une chaine entiere : sert a amorcer le serveur, ou a le
  // reconstituer apres un redemarrage.
  if (req.method === 'POST' && url.pathname === '/chain') {
    let envoi;
    try {
      envoi = await lireCorps(req);
    } catch (e) {
      return repondre(res, 400, { accepted: false, reason: e.message });
    }

    const blocs = (envoi && envoi.blocks) || [];
    if (blocs.length > MAX_BLOCS) {
      return repondre(res, 507, { accepted: false, reason: 'chaine trop longue' });
    }

    const verdict = verifyChain(blocs, envoi.rules || etat.rules);
    if (!verdict.valid) {
      return repondre(res, 400, { accepted: false, reason: verdict.problem });
    }

    // La regle de Bitcoin : c'est le travail cumule qui tranche, pas le
    // nombre de blocs.
    const nouveau = totalWork(blocs);
    const actuel = totalWork(etat.blocks);
    if (nouveau <= actuel) {
      return repondre(res, 409, {
        accepted: false,
        reason: 'la chaine proposee ne totalise pas plus de travail',
        height: etat.blocks.length,
      });
    }

    etat = { rules: envoi.rules || etat.rules, blocks: blocs };
    sauvegarder();
    console.log(`Chaine adoptee : ${blocs.length} blocs.`);
    return repondre(res, 200, { accepted: true, height: blocs.length });
  }

  // Page d'accueil lisible par un humain.
  if (req.method === 'GET' && url.pathname === '/') {
    const info = resume();
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    return res.end(`<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Serveur du Tibo</title>
<style>body{background:#070a12;color:#f2f7ff;font-family:system-ui;padding:40px;
line-height:1.6}code{background:#161e30;padding:2px 6px;border-radius:5px;
color:#ffb648}h1{color:#f7931a}a{color:#36d9ff}</style></head><body>
<h1>Serveur du Tibo</h1>
<p><strong>${info.height}</strong> bloc(s) — tete :
<code>${info.tip ? info.tip.slice(0, 24) + '…' : 'chaine vide'}</code></p>
<p>Ce serveur coordonne une chaine partagee. Il verifie la preuve de travail
de chaque bloc soumis et conserve la chaine qui totalise le plus de travail.
Il ne mine pas et ne peut pas fabriquer de blocs.</p>
<p>Points d'acces :
<code>GET /head</code>, <code>GET /chain</code>,
<code>POST /block</code>, <code>POST /chain</code></p>
<p>La monnaie coordonnee ici ne vaut rien et n'est echangeable nulle part.</p>
</body></html>`);
  }

  return repondre(res, 404, { error: 'chemin inconnu' });
});

charger();
serveur.listen(PORT, () => {
  console.log(`Serveur du Tibo a l'ecoute sur le port ${PORT}.`);
});
