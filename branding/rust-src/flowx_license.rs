// FlowXDesk: licença emitida pelo FlowX Hub (copiado por scripts/brand.py para src/flowx_license.rs).
//
// - O Hub assina um certificado (ed25519) para cada aparelho ativado com uma chave de licença.
//   O app confere offline com LICENSE_PUBLIC_KEY e renova sozinho (cliente 1×/dia, técnico 1×/hora).
// - Sem certificado válido: o app pede a chave e o serviço recusa conexões (só quando o build tem
//   FLOWX_LICENSE_URL; sem ela tudo fica desligado e o app funciona como antes).
// - Licença do tipo "tecnico": o app assina o desafio da conexão com a chave do aparelho e manda o
//   certificado junto; o PC do cliente confere e libera SEM SENHA. Revogar no Hub corta o acesso no
//   vencimento do certificado do técnico (2 h).
use hbb_common::{
    base64::{engine::general_purpose::STANDARD, Engine as _},
    config::Config,
    log,
    serde_json::{self, json, Value},
    sodiumoxide::{
        self,
        crypto::sign::{gen_keypair, sign_detached, verify_detached, PublicKey, SecretKey, Signature},
    },
};

const LICENSE_CONTEXT: &[u8] = b"FlowXDesk license v1\n";
const PROOF_CONTEXT: &[u8] = b"FlowXDesk tech proof v1\n";
const PROOF_MAGIC: &[u8] = b"FXT1";
// Lista de públicas do Hub aceitas: na rotação publica-se o app com [atual, próxima], vira o segredo, depois tira a velha.
const LICENSE_PUBLIC_KEYS: &[[u8; 32]] = &__LICENSE_PUBLIC_KEYS__;

const OPT_KEY: &str = "flowx-license-key";
const OPT_CERT: &str = "flowx-license-cert";
const OPT_DEVICE_SK: &str = "flowx-device-sk";

/// Endereço da função de licenças do Hub; vazio = licenciamento desligado neste build.
pub fn license_url() -> &'static str {
    option_env!("FLOWX_LICENSE_URL").unwrap_or("")
}

/// Licenciamento ligado: ativa, renova, registra o aparelho no Hub e mostra o aviso para ativar.
pub fn enabled() -> bool {
    !license_url().is_empty()
}

/// Bloqueio: sem licença o app só mostra a ativação e o serviço recusa conexões. Fica desligado no
/// período de carência; liga num build com FLOWX_LICENSE_BLOCK=1 quando todos os clientes tiverem chave.
pub fn enforced() -> bool {
    enabled() && option_env!("FLOWX_LICENSE_BLOCK") == Some("1")
}

fn now() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

// O serviço (Windows) guarda as opções; a janela lê/grava por IPC (ui_interface).
fn get_opt(k: &str) -> String {
    if crate::is_server() {
        Config::get_option(k)
    } else {
        crate::ui_interface::get_option(k)
    }
}

fn set_opt(k: &str, v: String) {
    if crate::is_server() {
        Config::set_option(k.to_owned(), v);
    } else {
        crate::ui_interface::set_option(k.to_owned(), v);
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct Cert {
    pub raw: String,
    pub lic: String,
    pub typ: String,
    pub org: String,
    pub tech: String,
    pub dev: String,
    pub pk: [u8; 32],
    pub exp: i64,
}

fn verify_with(pk: &[u8; 32], context: &[u8], msg: &[u8], sig: &[u8]) -> bool {
    if sig.len() != 64 {
        return false;
    }
    let mut s = [0u8; 64];
    s.copy_from_slice(sig);
    let Ok(sig) = Signature::from_bytes(&s) else {
        return false;
    };
    let _ = sodiumoxide::init();
    let mut m = Vec::with_capacity(context.len() + msg.len());
    m.extend_from_slice(context);
    m.extend_from_slice(msg);
    verify_detached(&sig, &m, &PublicKey(*pk))
}

/// Confere a assinatura do Hub e lê o certificado (não confere validade nem aparelho).
pub fn parse_cert_with(raw: &str, hub_pk: &[u8; 32]) -> Option<Cert> {
    let (p, s) = raw.trim().split_once('.')?;
    let payload = STANDARD.decode(p).ok()?;
    let sig = STANDARD.decode(s).ok()?;
    if !verify_with(hub_pk, LICENSE_CONTEXT, &payload, &sig) {
        return None;
    }
    let v: Value = serde_json::from_slice(&payload).ok()?;
    if v["v"].as_i64()? != 1 {
        return None;
    }
    let pk = STANDARD.decode(v["pk"].as_str()?).ok()?;
    if pk.len() != 32 {
        return None;
    }
    let mut pk32 = [0u8; 32];
    pk32.copy_from_slice(&pk);
    Some(Cert {
        raw: raw.trim().to_owned(),
        lic: v["lic"].as_str()?.to_owned(),
        typ: v["type"].as_str()?.to_owned(),
        org: v["org"].as_str().unwrap_or("").to_owned(),
        tech: v["tech"].as_str().unwrap_or("").to_owned(),
        dev: v["dev"].as_str()?.to_owned(),
        pk: pk32,
        exp: v["exp"].as_i64()?,
    })
}

fn parse_cert(raw: &str) -> Option<Cert> {
    LICENSE_PUBLIC_KEYS.iter().find_map(|k| parse_cert_with(raw, k))
}

fn device_secret() -> Option<SecretKey> {
    let b = STANDARD.decode(get_opt(OPT_DEVICE_SK)).ok()?;
    if b.len() != 64 {
        return None;
    }
    let mut k = [0u8; 64];
    k.copy_from_slice(&b);
    Some(SecretKey(k))
}

fn device_public_b64() -> String {
    let sk = match device_secret() {
        Some(sk) => sk,
        None => {
            let _ = sodiumoxide::init();
            let (_, sk) = gen_keypair();
            set_opt(OPT_DEVICE_SK, STANDARD.encode(sk.0));
            sk
        }
    };
    STANDARD.encode(&sk.0[32..]) // libsodium: secret = semente(32) + pública(32)
}

/// Certificado deste aparelho, se válido agora.
pub fn my_cert() -> Option<Cert> {
    let c = parse_cert(&get_opt(OPT_CERT))?;
    let my_id = Config::get_id();
    let pk_ok = device_secret().map(|sk| sk.0[32..] == c.pk).unwrap_or(false);
    (c.exp > now() && c.dev == my_id && pk_ok).then_some(c)
}

/// Este aparelho pode usar o app/aceitar conexões?
pub fn device_licensed() -> bool {
    !enforced() || my_cert().is_some()
}

/// JSON para a tela: {"enabled","enforced","ok","licensed","type","org","tech","exp","key"}
pub fn status_json() -> String {
    let c = my_cert();
    let key = get_opt(OPT_KEY);
    json!({
        "enabled": enabled(),
        "enforced": enforced(),
        "ok": !enforced() || c.is_some(),
        "licensed": c.is_some(),
        "type": c.as_ref().map(|c| c.typ.clone()).unwrap_or_default(),
        "org": c.as_ref().map(|c| c.org.clone()).unwrap_or_default(),
        "tech": c.as_ref().map(|c| c.tech.clone()).unwrap_or_default(),
        "exp": c.as_ref().map(|c| c.exp).unwrap_or(0),
        "key": mask(&key),
    })
    .to_string()
}

fn mask(key: &str) -> String {
    if key.len() > 8 {
        format!("{}…{}", &key[..4], &key[key.len() - 4..])
    } else {
        String::new()
    }
}

/// Ativa/renova com a chave. Devolve "" se deu certo ou a mensagem de erro para mostrar.
pub async fn activate(key: String) -> String {
    let key = key.trim().to_uppercase();
    if !enabled() {
        return "Licenciamento não configurado neste build".to_owned();
    }
    if key.is_empty() {
        return "Informe a chave de licença".to_owned();
    }
    let body = json!({
        "key": key,
        "device_id": Config::get_id(),
        "device_pk": device_public_b64(),
        "hostname": crate::common::hostname(),
        "os": std::env::consts::OS,
        "app_version": crate::VERSION,
    })
    .to_string();
    let resp = match crate::post_request(license_url().to_owned(), body, "").await {
        Ok(r) => r,
        Err(e) => {
            log::warn!("FlowXDesk licença: sem resposta do Hub: {}", e);
            return "Sem conexão com a FlowX. Verifique a internet e tente de novo.".to_owned();
        }
    };
    let v: Value = serde_json::from_str(&resp).unwrap_or(Value::Null);
    if let Some(cert) = v["cert"].as_str() {
        match parse_cert(cert) {
            Some(c) if c.dev == Config::get_id() => {
                set_opt(OPT_KEY, key);
                set_opt(OPT_CERT, cert.to_owned());
                log::info!("FlowXDesk licença ativa: {} ({}) até {}", c.org, c.typ, c.exp);
                return String::new();
            }
            _ => return "Resposta inválida do servidor de licenças".to_owned(),
        }
    }
    match v["error"].as_str().unwrap_or("") {
        "licenca_invalida" => "Chave de licença inválida".to_owned(),
        "licenca_suspensa" => "Licença suspensa. Fale com a FlowX.".to_owned(),
        "licenca_vencida" => "Licença vencida. Fale com a FlowX.".to_owned(),
        "limite_de_aparelhos" => "Esta licença já está em uso no número máximo de aparelhos".to_owned(),
        "aparelho_bloqueado" => "Este aparelho foi bloqueado. Fale com a FlowX.".to_owned(),
        "aparelho_invalido" => "Não foi possível identificar este aparelho. Reinstale o FlowXDesk.".to_owned(),
        _ => "Não foi possível validar a licença agora".to_owned(),
    }
}

/// Técnico: aparelhos FlowXDesk registrados no Hub. Devolve o JSON do Hub ({"devices":[...]}) ou {"error":...}.
/// Prova: a mesma assinatura do login de técnico, com "flowx-hub" no lugar do ID e a hora como desafio.
pub async fn device_list() -> String {
    if !enabled() {
        return json!({"error": "desligado"}).to_string();
    }
    let ts = now().to_string();
    let Some(proof) = crate::flowx_tech::sign_login(DEVICES_PEER, ts.as_bytes()) else {
        return json!({"error": "nao_tecnico"}).to_string();
    };
    let body = json!({"ts": ts, "proof": STANDARD.encode(proof)}).to_string();
    match crate::post_request(devices_url(), body, "").await {
        Ok(r) => r,
        Err(e) => {
            log::warn!("FlowXDesk: lista de aparelhos sem resposta do Hub: {}", e);
            json!({"error": "sem_conexao"}).to_string()
        }
    }
}

const DEVICES_PEER: &str = "flowx-hub";

fn devices_url() -> String {
    let u = license_url();
    format!("{}/devices", u.strip_suffix("/license").unwrap_or(u))
}

/// Renovação automática (chamada pelo serviço): técnico 1×/hora, cliente 1×/12 h; renova antes de vencer.
pub fn start_refresh_loop() {
    if !enabled() {
        return;
    }
    std::thread::spawn(|| loop {
        let key = get_opt(OPT_KEY);
        if !key.is_empty() {
            let need = match my_cert() {
                Some(c) => c.exp - now() < if c.typ == "tecnico" { 3600 } else { 25 * 86400 },
                None => true,
            };
            if need {
                if let Ok(rt) = hbb_common::tokio::runtime::Runtime::new() {
                    let err = rt.block_on(activate(key));
                    if !err.is_empty() {
                        log::warn!("FlowXDesk licença: renovação falhou: {}", err);
                    }
                }
            }
        }
        std::thread::sleep(std::time::Duration::from_secs(15 * 60));
    });
}

fn proof_message(peer_id: &str, challenge: &[u8]) -> Vec<u8> {
    let id = peer_id.split('@').next().unwrap_or(peer_id);
    let mut m = Vec::new();
    m.extend_from_slice(id.as_bytes());
    m.push(b'\n');
    m.extend_from_slice(challenge);
    m
}

/// Lado do técnico: prova para o campo "senha" do login. None se este aparelho não for técnico.
pub fn tech_proof(peer_id: &str, challenge: &[u8]) -> Option<Vec<u8>> {
    let c = my_cert()?;
    if c.typ != "tecnico" || peer_id.is_empty() || challenge.is_empty() {
        return None;
    }
    let sk = device_secret()?;
    let mut m = PROOF_CONTEXT.to_vec();
    m.extend_from_slice(&proof_message(peer_id, challenge));
    let sig = sign_detached(&m, &sk).to_bytes();
    let cert = c.raw.as_bytes();
    let mut out = Vec::with_capacity(4 + 2 + cert.len() + 64);
    out.extend_from_slice(PROOF_MAGIC);
    out.extend_from_slice(&(cert.len() as u16).to_be_bytes());
    out.extend_from_slice(cert);
    out.extend_from_slice(&sig);
    Some(out)
}

/// Lado do PC do cliente: é um técnico FlowX com licença válida? Devolve o nome do técnico.
pub fn verify_tech_proof_with(my_id: &str, challenge: &[u8], proof: &[u8], hub_pk: &[u8; 32], at: i64) -> Option<String> {
    if proof.len() < 4 + 2 + 64 || &proof[..4] != PROOF_MAGIC || my_id.is_empty() || challenge.is_empty() {
        return None;
    }
    let n = u16::from_be_bytes([proof[4], proof[5]]) as usize;
    if proof.len() != 6 + n + 64 {
        return None;
    }
    let cert = std::str::from_utf8(&proof[6..6 + n]).ok()?;
    let c = parse_cert_with(cert, hub_pk)?;
    if c.typ != "tecnico" || c.exp <= at {
        return None;
    }
    verify_with(&c.pk, PROOF_CONTEXT, &proof_message(my_id, challenge), &proof[6 + n..])
        .then(|| if c.tech.is_empty() { c.org } else { c.tech })
}

pub fn verify_tech_proof(my_id: &str, challenge: &[u8], proof: &[u8]) -> Option<String> {
    let at = now();
    LICENSE_PUBLIC_KEYS.iter().find_map(|k| verify_tech_proof_with(my_id, challenge, proof, k, at))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cert_for(hub: &SecretKey, typ: &str, dev: &str, pk: &[u8], exp: i64) -> String {
        let payload = json!({"v":1,"lic":"l1","type":typ,"org":"FlowX","tech":"Ana","dev":dev,
            "pk":STANDARD.encode(pk),"iat":1,"exp":exp}).to_string();
        let mut m = LICENSE_CONTEXT.to_vec();
        m.extend_from_slice(payload.as_bytes());
        let sig = sign_detached(&m, hub).to_bytes();
        format!("{}.{}", STANDARD.encode(payload.as_bytes()), STANDARD.encode(sig))
    }

    #[test]
    fn tech_proof_roundtrip_and_rejections() {
        let (hub_pk, hub_sk) = gen_keypair();
        let (dev_pk, dev_sk) = gen_keypair();
        let cert = cert_for(&hub_sk, "tecnico", "999", &dev_pk.0, 2000);
        let mut m = PROOF_CONTEXT.to_vec();
        m.extend_from_slice(&proof_message("123456789", b"ch"));
        let sig = sign_detached(&m, &dev_sk).to_bytes();
        let mut proof = PROOF_MAGIC.to_vec();
        proof.extend_from_slice(&(cert.len() as u16).to_be_bytes());
        proof.extend_from_slice(cert.as_bytes());
        proof.extend_from_slice(&sig);
        assert_eq!(verify_tech_proof_with("123456789", b"ch", &proof, &hub_pk.0, 1000).as_deref(), Some("Ana"));
        assert!(verify_tech_proof_with("123456780", b"ch", &proof, &hub_pk.0, 1000).is_none()); // outro PC
        assert!(verify_tech_proof_with("123456789", b"xx", &proof, &hub_pk.0, 1000).is_none()); // outro desafio
        assert!(verify_tech_proof_with("123456789", b"ch", &proof, &hub_pk.0, 3000).is_none()); // vencido
        let (other_pk, _) = gen_keypair();
        assert!(verify_tech_proof_with("123456789", b"ch", &proof, &other_pk.0, 1000).is_none()); // outro Hub
        let cli = cert_for(&hub_sk, "cliente", "999", &dev_pk.0, 2000);
        assert!(parse_cert_with(&cli, &hub_pk.0).is_some());
        let mut p2 = PROOF_MAGIC.to_vec();
        p2.extend_from_slice(&(cli.len() as u16).to_be_bytes());
        p2.extend_from_slice(cli.as_bytes());
        p2.extend_from_slice(&sig);
        assert!(verify_tech_proof_with("123456789", b"ch", &p2, &hub_pk.0, 1000).is_none()); // não é técnico
    }

    #[test]
    fn embedded_keys_are_valid_and_old_key_retired() {
        let old = STANDARD.decode("xpfvRJInY4pHvpOXqUiTD6gZX64WcFanpHYLsa9dvo0=").unwrap();
        assert!(!LICENSE_PUBLIC_KEYS.is_empty());
        assert!(LICENSE_PUBLIC_KEYS.iter().all(|k| k.as_slice() != old.as_slice())); // chave antiga aposentada (24/11)
    }
}
