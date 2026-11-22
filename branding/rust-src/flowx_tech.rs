// FlowXDesk: acesso de técnico FlowX sem senha (copiado por scripts/brand.py para src/flowx_tech.rs).
//
// O cliente público só tem a chave PÚBLICA. O FlowXDesk Técnico (build interno, nunca publicado) é
// compilado com FLOWX_TECH_KEY (chave privada) e, quando não há senha, manda no campo de senha do login
// uma assinatura ed25519 de (contexto + ID do PC + desafio aleatório da conexão). O PC confere a
// assinatura: sem segredo no instalador público, e assinatura capturada não serve de novo (desafio muda).
use hbb_common::{
    base64::{engine::general_purpose::STANDARD, Engine as _},
    sodiumoxide::{
        self,
        crypto::sign::{sign_detached, verify_detached, PublicKey, SecretKey, Signature},
    },
};

const CONTEXT: &[u8] = b"FlowXDesk tech login v1\n";
const TECH_PUBLIC_KEY: [u8; 32] = __TECH_PUBLIC_KEY__;

fn message(id: &str, challenge: &[u8]) -> Vec<u8> {
    // "123456789@servidor" -> só o ID
    let id = id.split('@').next().unwrap_or(id);
    let mut m = Vec::with_capacity(CONTEXT.len() + id.len() + 1 + challenge.len());
    m.extend_from_slice(CONTEXT);
    m.extend_from_slice(id.as_bytes());
    m.push(b'\n');
    m.extend_from_slice(challenge);
    m
}

/// Lado do PC do cliente: a "senha" recebida é uma assinatura válida do técnico FlowX?
pub fn verify_login(my_id: &str, challenge: &[u8], sig: &[u8]) -> bool {
    if sig.len() != 64 || my_id.is_empty() || challenge.is_empty() {
        return false;
    }
    let mut s = [0u8; 64];
    s.copy_from_slice(sig);
    let Ok(sig) = Signature::from_bytes(&s) else {
        return false;
    };
    let _ = sodiumoxide::init();
    verify_detached(&sig, &message(my_id, challenge), &PublicKey(TECH_PUBLIC_KEY))
}

/// Lado do técnico: assinatura para o PC `peer_id`. None no build público (sem FLOWX_TECH_KEY).
pub fn sign_login(peer_id: &str, challenge: &[u8]) -> Option<Vec<u8>> {
    let key = STANDARD.decode(option_env!("FLOWX_TECH_KEY")?.trim()).ok()?;
    if key.len() != 64 || peer_id.is_empty() || challenge.is_empty() {
        return None;
    }
    let mut k = [0u8; 64];
    k.copy_from_slice(&key);
    let _ = sodiumoxide::init();
    Some(sign_detached(&message(peer_id, challenge), &SecretKey(k)).to_bytes().to_vec())
}

pub fn is_tech_build() -> bool {
    option_env!("FLOWX_TECH_KEY").is_some()
}

#[cfg(test)]
mod tests {
    use super::*;
    use hbb_common::sodiumoxide::crypto::sign::gen_keypair;

    #[test]
    fn signature_binds_id_and_challenge() {
        let (pk, sk) = gen_keypair();
        let sig = sign_detached(&message("123456789", b"abc"), &sk);
        assert!(verify_detached(&sig, &message("123456789@srv", b"abc"), &pk));
        assert!(!verify_detached(&sig, &message("123456780", b"abc"), &pk));
        assert!(!verify_detached(&sig, &message("123456789", b"abd"), &pk));
        assert!(!verify_login("123456789", b"abc", &[0u8; 63]));
    }
}
