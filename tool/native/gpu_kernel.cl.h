// Noyau OpenCL : double SHA-256 sur en-tete de bloc Bitcoin.
//
// Ce fichier est inclus comme chaine de caracteres dans gpu_probe.cpp. Les
// constantes proviennent du meme jeu que l'implementation Dart, extraites
// automatiquement : aucune recopie manuelle, donc aucune divergence possible.
#pragma once

static const char* kSha256Kernel = R"CLC(

__constant uint K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

#define ROTR(x, n) (((x) >> (n)) | ((x) << (32 - (n))))
#define CH(e, f, g) (((e) & (f)) ^ ((~(e)) & (g)))
#define MAJ(a, b, c) (((a) & (b)) ^ ((a) & (c)) ^ ((b) & (c)))
#define S0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define S1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define s0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^ ((x) >> 3))
#define s1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ ((x) >> 10))

// Compression d'un bloc de 64 octets. w[] est modifie sur place.
static void sha256_block(uint *h, uint *w) {
  for (int i = 16; i < 64; i++) {
    w[i] = w[i - 16] + s0(w[i - 15]) + w[i - 7] + s1(w[i - 2]);
  }
  uint a = h[0], b = h[1], c = h[2], d = h[3];
  uint e = h[4], f = h[5], g = h[6], hh = h[7];
  for (int i = 0; i < 64; i++) {
    uint t1 = hh + S1(e) + CH(e, f, g) + K[i] + w[i];
    uint t2 = S0(a) + MAJ(a, b, c);
    hh = g; g = f; f = e; e = d + t1;
    d = c; c = b; b = a; a = t1 + t2;
  }
  h[0] += a; h[1] += b; h[2] += c; h[3] += d;
  h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
}

// Le nonce est stocke en petit-boutiste dans l'en-tete : le mot du message
// est donc l'inversion de ses octets.
#define NONCE_WORD(n) ((((n) & 0xffu) << 24) | ((((n) >> 8) & 0xffu) << 16) | \
                       ((((n) >> 16) & 0xffu) << 8) | (((n) >> 24) & 0xffu))

// Double SHA-256 de l'en-tete de 80 octets, fourni en 19 mots (le 20e etant
// le nonce, calcule ici).
static void hash_header(__constant uint *header, uint nonce, uint *out) {
  uint w[64];
  uint h[8];

  h[0] = 0x6a09e667; h[1] = 0xbb67ae85; h[2] = 0x3c6ef372; h[3] = 0xa54ff53a;
  h[4] = 0x510e527f; h[5] = 0x9b05688c; h[6] = 0x1f83d9ab; h[7] = 0x5be0cd19;

  // Premier bloc : les 64 premiers octets de l'en-tete.
  for (int i = 0; i < 16; i++) w[i] = header[i];
  sha256_block(h, w);

  // Second bloc : les 16 derniers octets, le nonce, puis le remplissage.
  w[0] = header[16];
  w[1] = header[17];
  w[2] = header[18];
  w[3] = NONCE_WORD(nonce);
  w[4] = 0x80000000u;
  for (int i = 5; i < 15; i++) w[i] = 0u;
  w[15] = 640u;  // 80 octets = 640 bits
  sha256_block(h, w);

  // Second SHA-256, sur les 32 octets du premier resultat.
  uint g[8];
  g[0] = 0x6a09e667; g[1] = 0xbb67ae85; g[2] = 0x3c6ef372; g[3] = 0xa54ff53a;
  g[4] = 0x510e527f; g[5] = 0x9b05688c; g[6] = 0x1f83d9ab; g[7] = 0x5be0cd19;

  for (int i = 0; i < 8; i++) w[i] = h[i];
  w[8] = 0x80000000u;
  for (int i = 9; i < 15; i++) w[i] = 0u;
  w[15] = 256u;  // 32 octets = 256 bits
  sha256_block(g, w);

  for (int i = 0; i < 8; i++) out[i] = g[i];
}

#define SWAP32(x) ((((x) & 0xffu) << 24) | ((((x) >> 8) & 0xffu) << 16) | \
                   ((((x) >> 16) & 0xffu) << 8) | (((x) >> 24) & 0xffu))

// Recherche : chaque unite de travail teste un nonce. Les candidats dont les
// quatre premiers octets du hash retourne passent sous le seuil sont empiles.
__kernel void mine(__constant uint *header,
                   const uint base_nonce,
                   const uint target_head,
                   __global uint *out,
                   const uint out_max) {
  const uint nonce = base_nonce + (uint)get_global_id(0);
  uint digest[8];
  hash_header(header, nonce, digest);

  const uint head = SWAP32(digest[7]);
  if (head <= target_head) {
    const uint slot = atomic_inc(&out[0]);
    if (slot < out_max) out[1 + slot] = nonce;
  }
}

// Auto-test : renvoie le hash complet d'un nonce donne, pour comparaison
// avec le processeur. Sans ce controle, aucun resultat GPU n'est utilise.
__kernel void hash_one(__constant uint *header,
                       const uint nonce,
                       __global uint *out) {
  uint digest[8];
  hash_header(header, nonce, digest);
  for (int i = 0; i < 8; i++) out[i] = digest[i];
}

)CLC";
