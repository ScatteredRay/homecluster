use reqwest::{Client, Response};
use serde::Deserialize;
use rusoto_core::{Region};
use rusoto_route53::{Change, ChangeBatch, ChangeResourceRecordSetsRequest, ResourceRecord, ResourceRecordSet, Route53Client};
use std::collections::HashMap;

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

    let client = Client::new();

    let mut index: Option<u64> = None;
    loop {
        let newIndex = update(&config, &client, index).await?;
        println!("Updated Index: {}", newIndex);
        index = Some(newIndex);
    }

    Ok(())
}

async fn update(config : &Config, client : &Client, index: Option<u64>) -> Result<u64, Box<dyn std::error::Error>>  {

    let consul_base_url = &config.consul_base_url;
    let zone_id = &config.zone_id;
    let domain = &config.domain;

    let route53_client = Route53Client::new(Region::default());

    let url = if let Some(index) = index {
        format!("{}/catalog/services?index={}&wait=5m", consul_base_url, index)
    } else {
        format!("{}/catalog/services", consul_base_url)
    };

    let response: Response = client
        .get(url)
        .send()
        .await?;

    let newIndex = response.headers()
        .get("X-Consul-Index")
        .and_then(|header| header.to_str().ok())
        .and_then(|index_str| index_str.parse::<u64>().ok())
        .unwrap_or(0);

    if index.is_none() || newIndex != index.unwrap() {

        // Fetch services from Consul
        let services: HashMap<String, Vec<String>> = response
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

                    let _change_request = ChangeResourceRecordSetsRequest {
                        hosted_zone_id: zone_id.to_string(),
                        change_batch,
                    };

                    //let _ = route53_client.change_resource_record_sets(change_request).await?;
                }
            }
        }
    }

    Ok(newIndex)
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