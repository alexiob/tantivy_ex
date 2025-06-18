use base64::{engine::general_purpose, Engine as _};
use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use serde_json;
use tantivy::collector::TopDocs;
use tantivy::schema::Value;
use tantivy::TantivyDocument;

use crate::modules::resources::{QueryResource, SearcherResource};

/// Search and retrieval functions

#[rustler::nif(schedule = "DirtyCpu")]
pub fn searcher_search<'a>(
    env: Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    _query_str: String,
    limit: usize,
    include_docs: bool,
) -> NifResult<Term<'a>> {
    use tantivy::query::AllQuery;

    // For string queries, we'll use AllQuery for now (matches all documents)
    // In the future, this could be enhanced to parse the string
    let query = AllQuery;
    let top_docs = TopDocs::with_limit(limit);

    match searcher_res.searcher.search(&query, &top_docs) {
        Ok(docs) => {
            let mut results = Vec::new();

            for (score, doc_address) in docs {
                if include_docs {
                    if let Ok(doc) = searcher_res.searcher.doc::<TantivyDocument>(doc_address) {
                        let mut doc_map = serde_json::Map::new();
                        doc_map.insert(
                            "score".to_string(),
                            serde_json::Value::Number(
                                serde_json::Number::from_f64(score as f64)
                                    .unwrap_or(serde_json::Number::from(0)),
                            ),
                        );
                        doc_map.insert(
                            "doc_id".to_string(),
                            serde_json::Value::Number(serde_json::Number::from(
                                doc_address.doc_id as u64,
                            )),
                        );

                        // Add document fields
                        for (field, value) in doc.field_values() {
                            let field_name = searcher_res.searcher.schema().get_field_name(field);
                            let json_value = if let Some(s) = value.as_str() {
                                serde_json::Value::String(s.to_string())
                            } else if let Some(n) = value.as_u64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_i64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_f64() {
                                serde_json::Value::Number(
                                    serde_json::Number::from_f64(n)
                                        .unwrap_or(serde_json::Number::from(0)),
                                )
                            } else if let Some(b) = value.as_bool() {
                                serde_json::Value::Bool(b)
                            } else if let Some(d) = value.as_datetime() {
                                serde_json::Value::String(format!("{:?}", d))
                            } else if let Some(f) = value.as_facet() {
                                serde_json::Value::String(f.to_string())
                            } else if let Some(b) = value.as_bytes() {
                                serde_json::Value::String(general_purpose::STANDARD.encode(b))
                            } else if let Some(obj_iter) = value.as_object() {
                                // Convert object iterator to JSON value
                                let mut json_obj = serde_json::Map::new();
                                for (key, val) in obj_iter {
                                    // For now, just convert to string - could be enhanced later
                                    json_obj.insert(
                                        key.to_string(),
                                        serde_json::Value::String(format!("{:?}", val)),
                                    );
                                }
                                serde_json::Value::Object(json_obj)
                            } else if let Some(ip) = value.as_ip_addr() {
                                serde_json::Value::String(ip.to_string())
                            } else {
                                serde_json::Value::Null
                            };
                            doc_map.insert(field_name.to_string(), json_value);
                        }

                        results.push(serde_json::Value::Object(doc_map));
                    }
                } else {
                    // Just return score and doc_id
                    let mut doc_map = serde_json::Map::new();
                    doc_map.insert(
                        "score".to_string(),
                        serde_json::Value::Number(
                            serde_json::Number::from_f64(score as f64)
                                .unwrap_or(serde_json::Number::from(0)),
                        ),
                    );
                    doc_map.insert(
                        "doc_id".to_string(),
                        serde_json::Value::Number(serde_json::Number::from(
                            doc_address.doc_id as u64,
                        )),
                    );
                    results.push(serde_json::Value::Object(doc_map));
                }
            }

            match serde_json::to_string(&results) {
                Ok(json) => Ok(json.encode(env)),
                Err(e) => Err(rustler::Error::Term(Box::new(format!(
                    "Failed to serialize results: {}",
                    e
                )))),
            }
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Search failed: {}",
            e
        )))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn searcher_search_with_query(
    searcher_res: ResourceArc<SearcherResource>,
    query_res: ResourceArc<QueryResource>,
    limit: u64,
    include_docs: bool,
) -> NifResult<String> {
    let top_docs = TopDocs::with_limit(limit as usize);
    match searcher_res.searcher.search(&*query_res.query, &top_docs) {
        Ok(docs) => {
            let mut results = Vec::new();

            for (score, doc_address) in docs {
                if include_docs {
                    if let Ok(doc) = searcher_res.searcher.doc::<TantivyDocument>(doc_address) {
                        let mut doc_map = serde_json::Map::new();
                        doc_map.insert(
                            "score".to_string(),
                            serde_json::Value::Number(
                                serde_json::Number::from_f64(score as f64)
                                    .unwrap_or(serde_json::Number::from(0)),
                            ),
                        );
                        doc_map.insert(
                            "doc_id".to_string(),
                            serde_json::Value::Number(serde_json::Number::from(
                                doc_address.doc_id as u64,
                            )),
                        );

                        // Add document fields
                        for (field, value) in doc.field_values() {
                            let field_name = searcher_res.searcher.schema().get_field_name(field);
                            let json_value = if let Some(s) = value.as_str() {
                                serde_json::Value::String(s.to_string())
                            } else if let Some(n) = value.as_u64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_i64() {
                                serde_json::Value::Number(serde_json::Number::from(n))
                            } else if let Some(n) = value.as_f64() {
                                serde_json::Value::Number(
                                    serde_json::Number::from_f64(n)
                                        .unwrap_or(serde_json::Number::from(0)),
                                )
                            } else if let Some(b) = value.as_bool() {
                                serde_json::Value::Bool(b)
                            } else if let Some(d) = value.as_datetime() {
                                serde_json::Value::String(format!("{:?}", d))
                            } else if let Some(f) = value.as_facet() {
                                serde_json::Value::String(f.to_string())
                            } else if let Some(b) = value.as_bytes() {
                                serde_json::Value::String(general_purpose::STANDARD.encode(b))
                            } else if let Some(obj_iter) = value.as_object() {
                                // Convert object iterator to JSON value
                                let mut json_obj = serde_json::Map::new();
                                for (key, val) in obj_iter {
                                    // For now, just convert to string - could be enhanced later
                                    json_obj.insert(
                                        key.to_string(),
                                        serde_json::Value::String(format!("{:?}", val)),
                                    );
                                }
                                serde_json::Value::Object(json_obj)
                            } else if let Some(ip) = value.as_ip_addr() {
                                serde_json::Value::String(ip.to_string())
                            } else {
                                serde_json::Value::Null
                            };
                            doc_map.insert(field_name.to_string(), json_value);
                        }

                        results.push(serde_json::Value::Object(doc_map));
                    }
                } else {
                    // Just return score and doc_id
                    let mut doc_map = serde_json::Map::new();
                    doc_map.insert(
                        "score".to_string(),
                        serde_json::Value::Number(
                            serde_json::Number::from_f64(score as f64)
                                .unwrap_or(serde_json::Number::from(0)),
                        ),
                    );
                    doc_map.insert(
                        "doc_id".to_string(),
                        serde_json::Value::Number(serde_json::Number::from(
                            doc_address.doc_id as u64,
                        )),
                    );
                    results.push(serde_json::Value::Object(doc_map));
                }
            }

            match serde_json::to_string(&results) {
                Ok(json) => Ok(json),
                Err(e) => Err(rustler::Error::Term(Box::new(format!(
                    "Failed to serialize results: {}",
                    e
                )))),
            }
        }
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Search failed: {}",
            e
        )))),
    }
}
