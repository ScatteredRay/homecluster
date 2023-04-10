use reqwest::Client;
use serde::Deserialize;
use rusoto_core::{Region, RusotoError};
use rusoto_route53::{Change, ChangeBatch, ChangeResourceRecordSetsRequest, ListResourceRecordSetsRequest, ResourceRecord, ResourceRecordSet, Route53, Route53Client};
use std::collections::HashMap;
use std::str::FromStr;
use std::fs;

// Add Config struct
#[derive(Debug, Deserialize)]
struct Config {
    consul_base_url: String,
    zone_id: String,
    domain: String,
}

// Add load_config function
fn load_config() -> Result<Config, Box<dyn std::error::Error>> {
    let config_toml = fs::read_to_string("config.toml")?;
    let config: Config = toml::from_str(&config_toml)?;
    Ok(config)
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = load_config()?;

    let consul_base_url = &config.consul_base_url;
    let zone_id = &config.zone_id;
    let domain = &config.domain;

    let client = Client::new();
    let route53_client = Route53Client::new(Region::default());

    // Fetch services from Consul
    let services: HashMap<String, Vec<String>> = client
        .get(format!("{}/catalog/services", consul_base_url))
        .send()
        .await?
        .json()
        .await?;

    for (service_name, service_tags) in services {
        if service_tags.contains(&"dns-entry".to_string()) {
            // Fetch service details
            let service_instances: Vec<ServiceInstance> = client
                .get(format!("{}/health/service/{}", consul_base_url, service_name))
                .send()
                .await?
                .json()
                .await?;

            for instance in service_instances {
                // Update DNS records in Route53
                let dns_name = format!("{}.{}", service_name, domain);
                let a_record = create_a_record(&dns_name, &instance.Service.Address);
                let srv_record = create_srv_record(&dns_name, &instance.Service.Address, instance.Service.Port);

                println!("update {} {} {}", dns_name, instance.Node.Address, instance.Service.Address);
                let change_batch = ChangeBatch {
                    changes: vec![a_record, srv_record],
                    comment: None,
                };

                let change_request = ChangeResourceRecordSetsRequest {
                    hosted_zone_id: zone_id.to_string(),
                    change_batch,
                };

                //let _ = route53_client.change_resource_record_sets(change_request).await?;
            }
        }
    }

    Ok(())
}

fn create_a_record(name: &str, ip: &str) -> Change {
    let a_record_set = ResourceRecordSet {
        name: name.to_string(),
        type_: String::from("A"),
        ttl: Some(60),
        resource_records: Some(vec![ResourceRecord { value: ip.to_string() }]),
        ..Default::default()
    };

    Change {
        action: String::from("UPSERT"),
        resource_record_set: a_record_set,
    }
}

fn create_srv_record(name: &str, ip: &str, port: i64) -> Change {
    let srv_record_set = ResourceRecordSet {
        name: name.to_string(),
        type_: String::from("SRV"),
        ttl: Some(60),
        resource_records: Some(vec![ResourceRecord {
                    value: format!("0 5 {} {}", port, ip),
                }]),
        ..Default::default()
    };

    Change {
        action: String::from("UPSERT"),
        resource_record_set: srv_record_set,
    }

}

#[derive(Deserialize, Debug)]
struct ServiceInstance {
    Node: Node,
    Service: Service,
}

#[derive(Deserialize, Debug)]
struct Node {
    Address: String,
}

#[derive(Deserialize, Debug)]
struct Service {
    Address: String,
    Port: i64,
}