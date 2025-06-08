use std::collections::BTreeMap;
use std::panic::{RefUnwindSafe, UnwindSafe};
use std::sync::{Arc, Mutex};
use tantivy::schema::{OwnedValue, Schema};
use tantivy::tokenizer::TokenizerManager;
use tantivy::{query::QueryParser, Index, IndexWriter};

// Resource types for managing state
pub struct IndexResource {
    pub index: Arc<Index>,
}

// Make IndexResource safe for unwind
unsafe impl Send for IndexResource {}
unsafe impl Sync for IndexResource {}
impl RefUnwindSafe for IndexResource {}
impl UnwindSafe for IndexResource {}

pub struct SchemaResource {
    pub schema: Schema,
}

pub struct IndexWriterResource {
    pub writer: Arc<Mutex<IndexWriter>>,
}

pub struct SearcherResource {
    pub searcher: Arc<tantivy::Searcher>,
}

pub struct QueryResource {
    pub query: Box<dyn tantivy::query::Query>,
}

pub struct QueryParserResource {
    pub parser: QueryParser,
}

pub struct TokenizerManagerResource {
    pub manager: TokenizerManager,
}

// Make SearcherResource safe for unwind
unsafe impl Send for SearcherResource {}
unsafe impl Sync for SearcherResource {}
impl RefUnwindSafe for SearcherResource {}
impl UnwindSafe for SearcherResource {}

unsafe impl Send for QueryResource {}
unsafe impl Sync for QueryResource {}
impl RefUnwindSafe for QueryResource {}
impl UnwindSafe for QueryResource {}

unsafe impl Send for QueryParserResource {}
unsafe impl Sync for QueryParserResource {}
impl RefUnwindSafe for QueryParserResource {}
impl UnwindSafe for QueryParserResource {}

unsafe impl Send for TokenizerManagerResource {}
unsafe impl Sync for TokenizerManagerResource {}
impl RefUnwindSafe for TokenizerManagerResource {}
impl UnwindSafe for TokenizerManagerResource {}

// Helper function to convert serde_json::Value to BTreeMap<String, OwnedValue>
pub fn convert_json_value_to_btreemap(value: serde_json::Value) -> BTreeMap<String, OwnedValue> {
    let mut map = BTreeMap::new();

    if let serde_json::Value::Object(obj) = value {
        for (key, val) in obj {
            let owned_value = match val {
                serde_json::Value::String(s) => OwnedValue::Str(s),
                serde_json::Value::Number(n) => {
                    if let Some(i) = n.as_i64() {
                        OwnedValue::I64(i)
                    } else if let Some(u) = n.as_u64() {
                        OwnedValue::U64(u)
                    } else if let Some(f) = n.as_f64() {
                        OwnedValue::F64(f)
                    } else {
                        OwnedValue::Str(n.to_string())
                    }
                }
                serde_json::Value::Bool(b) => OwnedValue::Bool(b),
                serde_json::Value::Array(_) | serde_json::Value::Object(_) => {
                    OwnedValue::Str(val.to_string())
                }
                serde_json::Value::Null => OwnedValue::Str("null".to_string()),
            };
            map.insert(key, owned_value);
        }
    }
    map
}

// Helper function to convert IpAddr to Ipv6Addr
pub fn convert_ip_to_ipv6(ip: std::net::IpAddr) -> std::net::Ipv6Addr {
    match ip {
        std::net::IpAddr::V4(ipv4) => ipv4.to_ipv6_mapped(),
        std::net::IpAddr::V6(ipv6) => ipv6,
    }
}

pub mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,
    }
}
