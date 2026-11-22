// FlowXDesk: o mesmo relay (hbbr) da FlowX tem dois endereços, o público e o interno
// (RENDEZVOUS_SERVER e RENDEZVOUS_SERVER_LAN). O roteador não faz NAT loopback, então quem está no
// escritório só alcança o interno e quem está fora (4G) só o público. O endereço de relay que circula
// entre os dois lados é um só; aqui cada lado troca por um que ELE alcança (o hbbr junta pelo uuid).
// Copiado por scripts/brand.py para src/flowx_net.rs.
use hbb_common::{
    anyhow::anyhow,
    config::{Config, CONNECT_TIMEOUT, RENDEZVOUS_SERVERS},
    log, socket_client, ResultType, Stream,
};

const OWN_CANDIDATE_TIMEOUT_MS: u64 = 5_000;

fn host(addr: &str) -> &str {
    addr.rsplit_once(':').map(|(h, _)| h).unwrap_or(addr)
}

/// Endereços a tentar, em ordem. Relay de terceiros fica como veio.
pub fn relay_candidates(relay_server: &str, best_rendezvous: &str) -> Vec<String> {
    let ours: Vec<&str> = RENDEZVOUS_SERVERS.iter().map(|s| host(s)).collect();
    if !ours.contains(&host(relay_server)) {
        return vec![relay_server.to_owned()];
    }
    let port = relay_server.rsplit_once(':').map(|(_, p)| p).unwrap_or("21117");
    let mut v = Vec::new();
    // 1º o host que este processo está usando agora para falar com o hbbs; depois o que veio; depois os outros
    for h in [host(best_rendezvous), host(relay_server)].into_iter().chain(ours.into_iter()) {
        let c = format!("{h}:{port}");
        if !h.is_empty() && !v.contains(&c) {
            v.push(c);
        }
    }
    v
}

pub async fn connect_relay(relay_server: String, ipv4: bool) -> ResultType<Stream> {
    let cands = relay_candidates(&relay_server, &Config::get_rendezvous_server());
    let timeout = if cands.len() > 1 { OWN_CANDIDATE_TIMEOUT_MS } else { CONNECT_TIMEOUT };
    let mut last = None;
    for rs in cands {
        match socket_client::connect_tcp(socket_client::ipv4_to_ipv6(rs.clone(), ipv4), timeout).await {
            Ok(s) => {
                if rs != relay_server {
                    log::info!("FlowXDesk: relay {} trocado por {} (alcançável daqui)", relay_server, rs);
                }
                return Ok(s);
            }
            Err(e) => {
                log::warn!("FlowXDesk: relay {} indisponível daqui: {}", rs, e);
                last = Some(e);
            }
        }
    }
    Err(last.unwrap_or_else(|| anyhow!("nenhum relay disponível")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn foreign_relay_untouched() {
        assert_eq!(relay_candidates("1.2.3.4:21117", "x:21116"), vec!["1.2.3.4:21117"]);
    }

    #[test]
    fn own_relay_prefers_reachable_host() {
        let first = host(RENDEZVOUS_SERVERS[0]);
        let r = relay_candidates(&format!("{first}:21117"), &format!("{first}:21116"));
        assert_eq!(r[0], format!("{first}:21117"));
        assert_eq!(r.len(), RENDEZVOUS_SERVERS.len());
    }
}
