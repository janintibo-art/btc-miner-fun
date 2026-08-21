'use strict';

// Verification des virements Tibo.
//
// Le serveur ne fait confiance a personne : il recalcule les soldes en
// rejouant la chaine, et verifie chaque signature avec la cle publique
// fournie - apres avoir verifie que cette cle correspond bien a l'adresse
// emettrice. Sans ce dernier controle, n'importe qui pourrait signer avec sa
// propre cle en pretendant depenser l'argent d'un autre.

const crypto = require('crypto');

// Prefixe DER d'une cle publique secp256k1 compressee. Verifie contre une
// cle generee par Node : les 23 premiers octets sont constants.
const PREFIXE_SPKI = Buffer.from(
  '3036301006072a8648ce3d020106052b8104000a032200', 'hex');

const VERSION_ADRESSE = 0x41;
const B58 = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

function sha256(b) {
  return crypto.createHash('sha256').update(b).digest();
}

function hash160(b) {
  return crypto.createHash('ripemd160').update(sha256(b)).digest();
}

function base58(raw) {
  let n = BigInt('0x' + raw.toString('hex'));
  let out = '';
  while (n > 0n) {
    out = B58[Number(n % 58n)] + out;
    n /= 58n;
  }
  let zeros = 0;
  while (zeros < raw.length && raw[zeros] === 0) zeros++;
  return '1'.repeat(zeros) + out;
}

/// Adresse correspondant a une cle publique compressee.
function adresseDepuisCle(publicKeyHex) {
  const pub = Buffer.from(publicKeyHex, 'hex');
  if (pub.length !== 33) return null;
  const corps = Buffer.concat([Buffer.from([VERSION_ADRESSE]), hash160(pub)]);
  const controle = sha256(sha256(corps)).subarray(0, 4);
  return base58(Buffer.concat([corps, controle]));
}

/// Verifie la forme et le code de controle d'une adresse.
function adresseValide(adresse) {
  if (typeof adresse !== 'string' || adresse.length < 26 || adresse.length > 40) {
    return false;
  }
  let n = 0n;
  for (const c of adresse) {
    const i = B58.indexOf(c);
    if (i < 0) return false;
    n = n * 58n + BigInt(i);
  }
  let hex = n.toString(16);
  if (hex.length % 2) hex = '0' + hex;
  const octets = Buffer.from(hex.padStart(50, '0'), 'hex');
  if (octets.length !== 25 || octets[0] !== VERSION_ADRESSE) return false;
  const attendu = sha256(sha256(octets.subarray(0, 21))).subarray(0, 4);
  return attendu.equals(octets.subarray(21));
}

/// Convertit une signature r||s de 64 octets au format DER attendu par Node.
function rsVersDer(rs) {
  const trim = (b) => {
    let i = 0;
    while (i < b.length - 1 && b[i] === 0) i++;
    const t = b.subarray(i);
    return (t[0] & 0x80) ? Buffer.concat([Buffer.from([0]), t]) : t;
  };
  const r = trim(rs.subarray(0, 32));
  const s = trim(rs.subarray(32, 64));
  return Buffer.concat([
    Buffer.from([0x30, 2 + r.length + 2 + s.length, 0x02, r.length]),
    r,
    Buffer.from([0x02, s.length]),
    s,
  ]);
}

/// Le texte signe. Il doit correspondre au caractere pres a celui construit
/// par l'application.
function messageSigne(tx) {
  return `TIBO|${tx.f}|${tx.t}|${Number(tx.a).toFixed(8)}|${tx.s}|${tx.n || ''}`;
}

/// Verifie la signature d'un virement, et que la cle appartient bien a
/// l'adresse emettrice.
function signatureValide(tx) {
  try {
    if (adresseDepuisCle(tx.p) !== tx.f) return false;

    const spki = Buffer.concat([PREFIXE_SPKI, Buffer.from(tx.p, 'hex')]);
    const cle = crypto.createPublicKey({ key: spki, format: 'der', type: 'spki' });
    const signature = Buffer.from(tx.g, 'hex');
    if (signature.length !== 64) return false;

    return crypto.verify(
      'sha256',
      Buffer.from(messageSigne(tx), 'utf8'),
      cle,
      rsVersDer(signature),
    );
  } catch (e) {
    return false;
  }
}

function formeValide(tx) {
  if (!tx || typeof tx !== 'object') return false;
  if (!adresseValide(tx.f) || !adresseValide(tx.t)) return false;
  if (typeof tx.a !== 'number' || !isFinite(tx.a) || tx.a <= 0) return false;
  if (!Number.isInteger(tx.s) || tx.s < 1) return false;
  if (typeof tx.p !== 'string' || !/^[0-9a-f]{66}$/.test(tx.p)) return false;
  if (typeof tx.g !== 'string' || !/^[0-9a-f]{128}$/.test(tx.g)) return false;
  if (tx.n !== undefined && (typeof tx.n !== 'string' || tx.n.length > 120)) {
    return false;
  }
  return true;
}

/// Rejoue la chaine et renvoie l'etat des comptes, ou une erreur.
function rejouer(blocs) {
  const soldes = new Map();
  const ordres = new Map();
  const solde = (a) => soldes.get(a) || 0;

  for (const bloc of blocs) {
    // La recompense va au mineur, quand il a fourni une adresse.
    if (bloc.mineur && adresseValide(bloc.mineur)) {
      soldes.set(bloc.mineur, solde(bloc.mineur) + (bloc.r || 0));
    }

    for (const tx of (bloc.tx || [])) {
      if (!formeValide(tx)) {
        return { ok: false, probleme: `bloc ${bloc.h} : virement mal forme` };
      }
      if (!signatureValide(tx)) {
        return { ok: false, probleme: `bloc ${bloc.h} : signature invalide` };
      }
      if (solde(tx.f) < tx.a) {
        return { ok: false, probleme: `bloc ${bloc.h} : solde insuffisant` };
      }
      const attendu = (ordres.get(tx.f) || 0) + 1;
      if (tx.s !== attendu) {
        return {
          ok: false,
          probleme: `bloc ${bloc.h} : numero d'ordre ${tx.s} au lieu de ${attendu}`,
        };
      }
      soldes.set(tx.f, solde(tx.f) - tx.a);
      soldes.set(tx.t, solde(tx.t) + tx.a);
      ordres.set(tx.f, tx.s);
    }
  }

  return { ok: true, soldes, ordres };
}

module.exports = {
  adresseDepuisCle,
  adresseValide,
  signatureValide,
  formeValide,
  messageSigne,
  rejouer,
  rsVersDer,
};
