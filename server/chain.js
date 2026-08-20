'use strict';

// Regles de validation de la chaine partagee.
//
// Ce fichier est le pendant exact de lib/core/my_chain.dart cote application :
// meme en-tete de 80 octets, meme preuve de travail, meme format compact de
// difficulte. Si les deux divergeaient, les blocs mines seraient refuses.

const crypto = require('crypto');

const GENESIS_PREV = '0'.repeat(64);

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest();
}

function sha256d(buffer) {
  return sha256(sha256(buffer));
}

/// Decode les quatre octets de difficulte en cible complete.
function targetFromBits(bits) {
  const exponent = (bits >>> 24) & 0xff;
  const mantissa = BigInt(bits & 0x007fffff);
  if (exponent <= 3) return mantissa >> BigInt(8 * (3 - exponent));
  return mantissa << BigInt(8 * (exponent - 3));
}

function le32(value) {
  const b = Buffer.alloc(4);
  b.writeUInt32LE(value >>> 0, 0);
  return b;
}

/// Reconstruit l'en-tete de 80 octets a partir des champs du bloc.
function header(block) {
  return Buffer.concat([
    le32(block.v),
    Buffer.from(block.p, 'hex').reverse(),
    Buffer.from(block.m, 'hex').reverse(),
    le32(block.t),
    le32(block.b),
    le32(block.n),
  ]);
}

/// Le hash affichable d'un bloc : le double SHA-256 de son en-tete, retourne.
function blockHash(block) {
  return Buffer.from(sha256d(header(block))).reverse().toString('hex');
}

/// La preuve de travail est-elle reellement apportee ?
function meetsTarget(block) {
  const value = BigInt('0x' + blockHash(block));
  return value <= targetFromBits(block.b);
}

// Longueur maximale du message inscrit dans un bloc.
//
// La genese a droit a beaucoup plus : elle n'est ecrite qu'une fois, et c'est
// le seul endroit d'une chaine ou l'on s'adresse a ceux qui viendront. Le bloc
// de genese de Bitcoin portait un titre de journal ; rien n'oblige a s'en
// tenir a une ligne.
const MAX_MSG_GENESE = 8000;
const MAX_MSG = 500;

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

/// Verifie la forme d'un bloc avant tout calcul : un champ manquant ou d'un
/// type inattendu ne doit pas faire tomber le serveur.
function hasValidShape(block) {
  if (!isPlainObject(block)) return false;
  const entiers = ['h', 'v', 't', 'b', 'n', 'x'];
  for (const champ of entiers) {
    if (!Number.isInteger(block[champ]) || block[champ] < 0) return false;
  }
  if (typeof block.p !== 'string' || !/^[0-9a-f]{64}$/.test(block.p)) return false;
  if (typeof block.m !== 'string' || !/^[0-9a-f]{64}$/.test(block.m)) return false;
  if (typeof block.r !== 'number' || !isFinite(block.r) || block.r < 0) return false;
  const limite = block.h === 0 ? MAX_MSG_GENESE : MAX_MSG;
  if (typeof block.msg !== 'string' || block.msg.length > limite) return false;
  if (block.n > 0xffffffff || block.b > 0xffffffff || block.v > 0xffffffff) return false;
  return true;
}

/// Verifie une chaine entiere. Retourne { valid, height, problem }.
function verifyChain(blocks, rules) {
  if (!Array.isArray(blocks)) return { valid: false, height: 0, problem: 'format inattendu' };
  if (blocks.length === 0) return { valid: true, height: 0 };

  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i];
    if (!hasValidShape(block)) {
      return { valid: false, height: i, problem: `bloc ${i} mal forme` };
    }
    if (block.h !== i) {
      return { valid: false, height: i, problem: `hauteur incoherente au bloc ${i}` };
    }

    if (i === 0) {
      if (block.p !== GENESIS_PREV) {
        return { valid: false, height: 0, problem: 'la genese ne doit succeder a rien' };
      }
      continue;
    }

    const previous = blocks[i - 1];
    if (block.p !== blockHash(previous)) {
      return { valid: false, height: i, problem: `le bloc ${i} ne suit pas le precedent` };
    }
    if (block.t < previous.t) {
      return { valid: false, height: i, problem: `horodatage en arriere au bloc ${i}` };
    }
    // La difficulte et la recompense sont dictees par la chaine, pas par
    // celui qui soumet le bloc.
    const attendus = expectedBits(blocks.slice(0, i), rules);
    if (block.b !== attendus) {
      return { valid: false, height: i, problem: `le bloc ${i} annonce une difficulte non conforme` };
    }
    const recompense = expectedReward(i, rules);
    if (Math.abs(block.r - recompense) > 1e-9) {
      return { valid: false, height: i, problem: `le bloc ${i} s'attribue une recompense non conforme` };
    }
    if (!meetsTarget(block)) {
      return { valid: false, height: i, problem: `le bloc ${i} n'apporte pas sa preuve de travail` };
    }
  }

  return { valid: true, height: blocks.length };
}

/// Difficulte imposee au prochain bloc, calculee depuis la chaine elle-meme.
///
/// Sans ce controle, n'importe qui pourrait annoncer une difficulte de son
/// choix et faire accepter un bloc trouve en trois essais. Le serveur ne fait
/// donc jamais confiance au champ envoye : il recalcule.
function expectedBits(blocks, rules) {
  const genesisBits = (rules && rules.bits) || 0x1f00ffff;
  if (!blocks.length) return genesisBits;

  const last = blocks[blocks.length - 1];
  const intervalle = (rules && rules.retarget) || 10;
  const vise = (rules && rules.target) || 30;

  if (blocks.length % intervalle !== 0) return last.b;
  if (blocks.length <= intervalle) return last.b;

  const premier = blocks[blocks.length - intervalle];
  let ecoule = last.t - premier.t;
  const attendu = vise * intervalle;
  if (ecoule <= 0) ecoule = 1;
  if (ecoule < Math.floor(attendu / 4)) ecoule = Math.floor(attendu / 4);
  if (ecoule > attendu * 4) ecoule = attendu * 4;

  const cible = targetFromBits(last.b);
  let ajustee = (cible * BigInt(ecoule)) / BigInt(attendu);
  const maximum = targetFromBits(genesisBits);
  if (ajustee > maximum) ajustee = maximum;
  return bitsFromTarget(ajustee);
}

/// Encode une cible en quatre octets, comme le fait l'application.
function bitsFromTarget(target) {
  if (target <= 0n) return 0;
  let hex = target.toString(16);
  if (hex.length % 2) hex = '0' + hex;
  let octets = Buffer.from(hex, 'hex');
  if (octets[0] > 0x7f) octets = Buffer.concat([Buffer.from([0]), octets]);
  const exponent = octets.length;
  let mantissa = 0;
  for (let i = 0; i < 3; i++) {
    mantissa = (mantissa << 8) | (i < octets.length ? octets[i] : 0);
  }
  return ((exponent << 24) | mantissa) >>> 0;
}

/// Recompense due a une hauteur donnee : elle non plus n'est pas negociable.
function expectedReward(height, rules) {
  const initiale = (rules && rules.reward) || 50;
  const palier = (rules && rules.halving) || 100;
  const divisions = Math.floor(height / palier);
  if (divisions >= 64) return 0;
  return initiale / Math.pow(2, divisions);
}

/// Travail cumule : la somme des difficultes, et non le nombre de blocs.
///
/// C'est la regle de Bitcoin, et elle compte ici aussi : une chaine de mille
/// blocs faciles ne doit pas l'emporter sur une chaine de cent blocs durs.
function totalWork(blocks) {
  let work = 0n;
  const deux256 = 1n << 256n;
  for (const block of blocks) {
    const target = targetFromBits(block.b);
    if (target > 0n) work += deux256 / target;
  }
  return work;
}

module.exports = {
  GENESIS_PREV,
  expectedBits,
  expectedReward,
  bitsFromTarget,
  blockHash,
  meetsTarget,
  hasValidShape,
  verifyChain,
  totalWork,
  targetFromBits,
  header,
};
