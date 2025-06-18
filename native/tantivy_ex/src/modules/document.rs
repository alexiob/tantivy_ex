use base64::{engine::general_purpose, Engine as _};
use chrono;
use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use serde_json;
use std::collections::HashMap;
use tantivy::query::{BooleanQuery, Occur, PhraseQuery, TermQuery};
use tantivy::schema::{Field, FieldType, IndexRecordOption};
use tantivy::{TantivyDocument, Term as TantivyTerm};

use crate::modules::resources::{
    atoms, convert_ip_to_ipv6, convert_json_value_to_btreemap, IndexWriterResource, QueryResource,
    SchemaResource,
};

/// Document operations and validation functions

#[rustler::nif]
pub fn writer_add_document<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    document: rustler::Term<'a>,
) -> NifResult<Term<'a>> {
    // Convert Elixir map to a HashMap first
    let doc_map: HashMap<String, rustler::Term> = match document.decode() {
        Ok(map) => map,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(
                "Failed to decode document map: Expected a map".to_string(),
            )))
        }
    };

    let writer = writer_res.writer.lock().unwrap();
    let schema = writer.index().schema();

    // Create a properly mapped Tantivy document
    let mut tantivy_doc = TantivyDocument::default();

    // Map each field in the document to the correct Tantivy field
    for (field_name, value) in doc_map {
        // Find the field in the schema
        if let Ok(field) = schema.get_field(&field_name) {
            let field_entry = schema.get_field_entry(field);

            match field_entry.field_type() {
                FieldType::Str(_) => {
                    if let Ok(string_val) = value.decode::<String>() {
                        tantivy_doc.add_text(field, &string_val);
                    }
                }
                FieldType::U64(_) => {
                    if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_u64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        if int_val >= 0 {
                            tantivy_doc.add_u64(field, int_val as u64);
                        }
                    }
                }
                FieldType::I64(_) => {
                    if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_i64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_i64(field, int_val as i64);
                    }
                }
                FieldType::F64(_) => {
                    if let Ok(float_val) = value.decode::<f64>() {
                        tantivy_doc.add_f64(field, float_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_f64(field, int_val as f64);
                    } else if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_f64(field, int_val as f64);
                    }
                }
                FieldType::Bool(_) => {
                    if let Ok(bool_val) = value.decode::<bool>() {
                        tantivy_doc.add_bool(field, bool_val);
                    }
                }
                FieldType::Date(_) => {
                    if let Ok(timestamp) = value.decode::<i64>() {
                        let date_time = tantivy::DateTime::from_timestamp_secs(timestamp);
                        tantivy_doc.add_date(field, date_time);
                    } else if let Ok(timestamp) = value.decode::<u64>() {
                        let date_time = tantivy::DateTime::from_timestamp_secs(timestamp as i64);
                        tantivy_doc.add_date(field, date_time);
                    }
                }
                FieldType::Facet(_) => {
                    // Handle both single strings and arrays of strings for facet fields
                    if let Ok(facet_val) = value.decode::<String>() {
                        if let Ok(facet) = tantivy::schema::Facet::from_text(&facet_val) {
                            tantivy_doc.add_facet(field, facet);
                        }
                    } else if let Ok(facet_array) = value.decode::<Vec<rustler::Term>>() {
                        // Handle arrays of facet values
                        for facet_item in facet_array {
                            if let Ok(facet_val) = facet_item.decode::<String>() {
                                if let Ok(facet) = tantivy::schema::Facet::from_text(&facet_val) {
                                    tantivy_doc.add_facet(field, facet);
                                }
                            }
                        }
                    }
                }
                FieldType::Bytes(_) => {
                    if let Ok(bytes_val) = value.decode::<Vec<u8>>() {
                        tantivy_doc.add_bytes(field, &bytes_val);
                    } else if let Ok(string_val) = value.decode::<String>() {
                        tantivy_doc.add_bytes(field, string_val.as_bytes());
                    }
                }
                FieldType::JsonObject(_) => {
                    if let Ok(json_str) = value.decode::<String>() {
                        if let Ok(json_val) = serde_json::from_str::<serde_json::Value>(&json_str) {
                            let btree_map = convert_json_value_to_btreemap(json_val);
                            tantivy_doc.add_object(field, btree_map);
                        }
                    }
                }
                FieldType::IpAddr(_) => {
                    if let Ok(ip_str) = value.decode::<String>() {
                        if let Ok(ip_addr) = ip_str.parse::<std::net::IpAddr>() {
                            tantivy_doc.add_ip_addr(field, convert_ip_to_ipv6(ip_addr));
                        }
                    }
                }
            }
        }
    }

    match writer.add_document(tantivy_doc) {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to add document: {}",
            e
        )))),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn writer_commit<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
) -> NifResult<Term<'a>> {
    let mut writer = writer_res.writer.lock().unwrap();
    match writer.commit() {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to commit: {}",
            e
        )))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn writer_delete_documents<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    query_res: ResourceArc<QueryResource>,
) -> NifResult<Term<'a>> {
    // Get a reference to the writer
    let writer = writer_res.writer.lock().unwrap();
    let query = query_res.query.box_clone();

    // Delete documents matching the query
    match writer.delete_query(query) {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to delete documents by query: {}",
            e
        )))),
    }
}

#[rustler::nif]
pub fn writer_delete_all_documents<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
) -> NifResult<Term<'a>> {
    let writer = writer_res.writer.lock().unwrap();

    match writer.delete_all_documents() {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to delete all documents: {}",
            e
        )))),
    }
}

#[rustler::nif]
pub fn writer_rollback<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
) -> NifResult<Term<'a>> {
    let mut writer = writer_res.writer.lock().unwrap();

    match writer.rollback() {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to rollback: {}",
            e
        )))),
    }
}

#[rustler::nif]
pub fn writer_delete_term<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    term_field: String,
    term_value: rustler::Term<'a>,
) -> NifResult<Term<'a>> {
    let writer = writer_res.writer.lock().unwrap();
    let schema = writer.index().schema();

    // Get the field from the schema
    let field = match schema.get_field(&term_field) {
        Ok(field) => field,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Field '{}' not found in schema",
                term_field
            ))));
        }
    };

    let field_entry = schema.get_field_entry(field);
    let field_type = field_entry.field_type();

    // Create a Tantivy Term or Query based on the field type and value
    match field_type {
        FieldType::Str(text_options) => {
            if let Ok(string_val) = term_value.decode::<String>() {
                // Check if the field is tokenized
                if let Some(indexing) = text_options.get_indexing_options() {
                    // For tokenized text fields, we need to use query-based deletion
                    let words: Vec<&str> = string_val.split_whitespace().collect();
                    let _word_count = words.len();

                    let query: Box<dyn tantivy::query::Query> = if words.len() == 1 {
                        // Single word - use term query with lowercase normalization
                        let tantivy_term =
                            TantivyTerm::from_field_text(field, &words[0].to_lowercase());
                        Box::new(TermQuery::new(tantivy_term, IndexRecordOption::Basic))
                    } else {
                        // Multiple words - check if positions are indexed for phrase queries
                        if indexing.index_option().has_positions() {
                            // Use phrase query when positions are available
                            let terms: Vec<TantivyTerm> = words
                                .iter()
                                .map(|word| {
                                    TantivyTerm::from_field_text(field, &word.to_lowercase())
                                })
                                .collect();
                            Box::new(PhraseQuery::new(terms))
                        } else {
                            // Use boolean query with all terms as MUST when positions are not available
                            let mut clauses = Vec::new();
                            for word in words {
                                let tantivy_term =
                                    TantivyTerm::from_field_text(field, &word.to_lowercase());
                                let term_query =
                                    TermQuery::new(tantivy_term, IndexRecordOption::Basic);
                                clauses.push((
                                    Occur::Must,
                                    Box::new(term_query) as Box<dyn tantivy::query::Query>,
                                ));
                            }
                            Box::new(BooleanQuery::new(clauses))
                        }
                    };

                    // Perform the deletion using query
                    match writer.delete_query(query) {
                        Ok(_opstamp) => {
                            return Ok(atoms::ok().encode(env));
                        }
                        Err(e) => {
                            return Err(rustler::Error::Term(Box::new(format!(
                                "Failed to delete by query: {}",
                                e
                            ))));
                        }
                    }
                } else {
                    // Non-tokenized text field - use term deletion
                    let tantivy_term = TantivyTerm::from_field_text(field, &string_val);

                    // Perform the deletion
                    let _opstamp = writer.delete_term(tantivy_term.clone());

                    return Ok(atoms::ok().encode(env));
                }
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid string value for text field".to_string(),
                )));
            }
        }
        FieldType::U64(_) => {
            let tantivy_term = if let Ok(int_val) = term_value.decode::<u64>() {
                TantivyTerm::from_field_u64(field, int_val)
            } else if let Ok(int_val) = term_value.decode::<i64>() {
                if int_val >= 0 {
                    TantivyTerm::from_field_u64(field, int_val as u64)
                } else {
                    return Err(rustler::Error::Term(Box::new(
                        "Negative value not allowed for u64 field".to_string(),
                    )));
                }
            } else if let Ok(string_val) = term_value.decode::<String>() {
                // Try to parse string as u64
                match string_val.parse::<u64>() {
                    Ok(val) => TantivyTerm::from_field_u64(field, val),
                    Err(_) => {
                        return Err(rustler::Error::Term(Box::new(format!(
                            "Cannot parse '{}' as u64 for field '{}'",
                            string_val, term_field
                        ))));
                    }
                }
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid value for u64 field - expected number or numeric string".to_string(),
                )));
            };

            // Perform the deletion
            let _opstamp = writer.delete_term(tantivy_term.clone());

            return Ok(atoms::ok().encode(env));
        }
        FieldType::I64(_) => {
            let tantivy_term = if let Ok(int_val) = term_value.decode::<i64>() {
                TantivyTerm::from_field_i64(field, int_val)
            } else if let Ok(int_val) = term_value.decode::<u64>() {
                TantivyTerm::from_field_i64(field, int_val as i64)
            } else if let Ok(string_val) = term_value.decode::<String>() {
                // Try to parse string as i64
                match string_val.parse::<i64>() {
                    Ok(val) => TantivyTerm::from_field_i64(field, val),
                    Err(_) => {
                        return Err(rustler::Error::Term(Box::new(format!(
                            "Cannot parse '{}' as i64 for field '{}'",
                            string_val, term_field
                        ))));
                    }
                }
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid value for i64 field - expected number or numeric string".to_string(),
                )));
            };

            // Perform the deletion
            let _opstamp = writer.delete_term(tantivy_term.clone());

            return Ok(atoms::ok().encode(env));
        }
        FieldType::F64(_) => {
            let tantivy_term = if let Ok(float_val) = term_value.decode::<f64>() {
                TantivyTerm::from_field_f64(field, float_val)
            } else if let Ok(int_val) = term_value.decode::<i64>() {
                TantivyTerm::from_field_f64(field, int_val as f64)
            } else if let Ok(string_val) = term_value.decode::<String>() {
                // Try to parse string as f64
                match string_val.parse::<f64>() {
                    Ok(val) => TantivyTerm::from_field_f64(field, val),
                    Err(_) => {
                        return Err(rustler::Error::Term(Box::new(format!(
                            "Cannot parse '{}' as f64 for field '{}'",
                            string_val, term_field
                        ))));
                    }
                }
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid value for f64 field - expected number or numeric string".to_string(),
                )));
            };

            // Perform the deletion
            let _opstamp = writer.delete_term(tantivy_term.clone());

            return Ok(atoms::ok().encode(env));
        }
        FieldType::Bool(_) => {
            let tantivy_term = if let Ok(bool_val) = term_value.decode::<bool>() {
                TantivyTerm::from_field_bool(field, bool_val)
            } else if let Ok(string_val) = term_value.decode::<String>() {
                // Handle string boolean values
                let bool_val = match string_val.to_lowercase().as_str() {
                    "true" | "t" | "1" | "yes" | "y" => true,
                    "false" | "f" | "0" | "no" | "n" => false,
                    _ => {
                        return Err(rustler::Error::Term(Box::new(format!(
                            "Cannot parse '{}' as boolean for field '{}'",
                            string_val, term_field
                        ))));
                    }
                };
                TantivyTerm::from_field_bool(field, bool_val)
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid value for bool field - expected boolean or boolean string".to_string(),
                )));
            };

            // Perform the deletion
            let _opstamp = writer.delete_term(tantivy_term.clone());

            return Ok(atoms::ok().encode(env));
        }
        FieldType::Date(_) => {
            let tantivy_term = if let Ok(timestamp) = term_value.decode::<i64>() {
                let date_time = tantivy::DateTime::from_timestamp_secs(timestamp);
                TantivyTerm::from_field_date(field, date_time)
            } else if let Ok(string_val) = term_value.decode::<String>() {
                // Try to parse string as timestamp
                match string_val.parse::<i64>() {
                    Ok(timestamp) => {
                        let date_time = tantivy::DateTime::from_timestamp_secs(timestamp);
                        TantivyTerm::from_field_date(field, date_time)
                    }
                    Err(_) => {
                        return Err(rustler::Error::Term(Box::new(format!(
                            "Cannot parse '{}' as timestamp for field '{}'",
                            string_val, term_field
                        ))));
                    }
                }
            } else {
                return Err(rustler::Error::Term(Box::new(
                    "Invalid value for date field - expected timestamp or timestamp string"
                        .to_string(),
                )));
            };

            // Perform the deletion
            let _opstamp = writer.delete_term(tantivy_term.clone());

            return Ok(atoms::ok().encode(env));
        }
        _ => {
            return Err(rustler::Error::Term(Box::new(format!(
                "Unsupported field type for deletion: {:?}",
                field_type
            ))));
        }
    };
}

#[rustler::nif]
pub fn writer_add_document_with_schema<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    document: rustler::Term<'a>,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<Term<'a>> {
    // Convert Elixir map to a HashMap first
    let doc_map: HashMap<String, rustler::Term> = match document.decode() {
        Ok(map) => map,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(
                "Failed to decode document map: Expected a map".to_string(),
            )))
        }
    };

    let schema = &schema_res.schema;
    let writer = writer_res.writer.lock().unwrap();

    // Create a properly mapped Tantivy document
    let mut tantivy_doc = TantivyDocument::default();

    // Map each field in the document to the correct Tantivy field
    for (field_name, value) in doc_map {
        // Find the field in the schema
        if let Ok(field) = schema.get_field(&field_name) {
            let field_entry = schema.get_field_entry(field);

            match field_entry.field_type() {
                FieldType::Str(_) => {
                    if let Ok(string_val) = value.decode::<String>() {
                        tantivy_doc.add_text(field, &string_val);
                    }
                }
                FieldType::U64(_) => {
                    if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_u64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        if int_val >= 0 {
                            tantivy_doc.add_u64(field, int_val as u64);
                        }
                    }
                }
                FieldType::I64(_) => {
                    if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_i64(field, int_val);
                    } else if let Ok(int_val) = value.decode::<u64>() {
                        tantivy_doc.add_i64(field, int_val as i64);
                    }
                }
                FieldType::F64(_) => {
                    if let Ok(float_val) = value.decode::<f64>() {
                        tantivy_doc.add_f64(field, float_val);
                    } else if let Ok(int_val) = value.decode::<i64>() {
                        tantivy_doc.add_f64(field, int_val as f64);
                    }
                }
                FieldType::Bool(_) => {
                    if let Ok(bool_val) = value.decode::<bool>() {
                        tantivy_doc.add_bool(field, bool_val);
                    }
                }
                FieldType::Date(_) => {
                    if let Ok(timestamp) = value.decode::<i64>() {
                        let datetime = tantivy::DateTime::from_timestamp_secs(timestamp);
                        tantivy_doc.add_date(field, datetime);
                    } else if let Ok(string_val) = value.decode::<String>() {
                        // Try to parse ISO 8601 format
                        if let Ok(dt) = chrono::DateTime::parse_from_rfc3339(&string_val) {
                            let timestamp = dt.timestamp();
                            let datetime = tantivy::DateTime::from_timestamp_secs(timestamp);
                            tantivy_doc.add_date(field, datetime);
                        }
                    }
                }
                FieldType::Facet(_) => {
                    // Handle both single strings and arrays of strings for facet fields
                    if let Ok(string_val) = value.decode::<String>() {
                        if let Ok(facet) = tantivy::schema::Facet::from_text(&string_val) {
                            tantivy_doc.add_facet(field, facet);
                        }
                    } else if let Ok(facet_array) = value.decode::<Vec<rustler::Term>>() {
                        // Handle arrays of facet values
                        for facet_item in facet_array {
                            if let Ok(facet_val) = facet_item.decode::<String>() {
                                if let Ok(facet) = tantivy::schema::Facet::from_text(&facet_val) {
                                    tantivy_doc.add_facet(field, facet);
                                }
                            }
                        }
                    }
                }
                FieldType::Bytes(_) => {
                    if let Ok(string_val) = value.decode::<String>() {
                        // Assume base64 encoded
                        if let Ok(bytes) = general_purpose::STANDARD.decode(&string_val) {
                            tantivy_doc.add_bytes(field, &bytes);
                        }
                    }
                }
                FieldType::JsonObject(_) => {
                    // Convert the value to JSON
                    let json_value = convert_term_to_json_value(value);
                    let btree_map = convert_json_value_to_btreemap(json_value);
                    tantivy_doc.add_object(field, btree_map);
                }
                FieldType::IpAddr(_) => {
                    if let Ok(string_val) = value.decode::<String>() {
                        if let Ok(ip) = string_val.parse::<std::net::IpAddr>() {
                            let ipv6 = convert_ip_to_ipv6(ip);
                            tantivy_doc.add_ip_addr(field, ipv6);
                        }
                    }
                }
            }
        }
    }

    match writer.add_document(tantivy_doc) {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to add document: {}",
            e
        )))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn writer_add_document_batch<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    documents: Vec<rustler::Term<'a>>,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<Term<'a>> {
    let schema = &schema_res.schema;
    let writer = writer_res.writer.lock().unwrap();

    let mut successful_count = 0;
    let mut errors = Vec::new();

    for (index, document) in documents.iter().enumerate() {
        // Convert document using the same logic as single document addition
        let doc_map: HashMap<String, rustler::Term> = match document.decode() {
            Ok(map) => map,
            Err(_) => {
                errors.push((index, "Failed to decode document".to_string()));
                continue;
            }
        };

        let mut tantivy_doc = TantivyDocument::default();

        // Process each field in the document
        let mut doc_valid = true;
        for (field_name, value) in doc_map {
            if let Ok(field) = schema.get_field(&field_name) {
                let field_entry = schema.get_field_entry(field);

                match add_field_to_document(
                    &mut tantivy_doc,
                    field,
                    field_entry.field_type(),
                    value,
                ) {
                    Ok(_) => {}
                    Err(err) => {
                        errors.push((index, format!("Field '{}': {}", field_name, err)));
                        doc_valid = false;
                        break;
                    }
                }
            }
        }

        if doc_valid {
            match writer.add_document(tantivy_doc) {
                Ok(_) => successful_count += 1,
                Err(e) => {
                    errors.push((index, format!("Failed to add document: {}", e)));
                }
            }
        }
    }

    // Return result summary
    let result = format!(
        "{{\"successful\": {}, \"errors\": {}}}",
        successful_count,
        errors.len()
    );

    Ok(result.encode(env))
}

#[rustler::nif]
pub fn validate_document_against_schema<'a>(
    env: Env<'a>,
    document: rustler::Term<'a>,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<Term<'a>> {
    let doc_map: HashMap<String, rustler::Term> = match document.decode() {
        Ok(map) => map,
        Err(_) => {
            return Err(rustler::Error::Term(Box::new(
                "Failed to decode document map".to_string(),
            )))
        }
    };

    let schema = &schema_res.schema;
    let mut validation_errors = Vec::new();

    for (field_name, value) in doc_map {
        if let Ok(field) = schema.get_field(&field_name) {
            let field_entry = schema.get_field_entry(field);

            if let Err(error) = validate_field_value(value, field_entry.field_type()) {
                validation_errors.push(format!("Field '{}': {}", field_name, error));
            }
        } else {
            validation_errors.push(format!("Unknown field: '{}'", field_name));
        }
    }

    if validation_errors.is_empty() {
        Ok(atoms::ok().encode(env))
    } else {
        let error_msg = validation_errors.join("; ");
        Err(rustler::Error::Term(Box::new(error_msg)))
    }
}

/// Helper functions for document operations

pub fn add_field_to_document(
    doc: &mut TantivyDocument,
    field: Field,
    field_type: &FieldType,
    value: rustler::Term,
) -> Result<(), String> {
    match field_type {
        FieldType::Str(_) => {
            let string_val: String = value.decode().map_err(|_| "Expected string value")?;
            doc.add_text(field, &string_val);
            Ok(())
        }
        FieldType::U64(_) => {
            if let Ok(int_val) = value.decode::<u64>() {
                doc.add_u64(field, int_val);
                Ok(())
            } else if let Ok(int_val) = value.decode::<i64>() {
                if int_val >= 0 {
                    doc.add_u64(field, int_val as u64);
                    Ok(())
                } else {
                    Err("Negative value not allowed for u64 field".to_string())
                }
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::I64(_) => {
            if let Ok(int_val) = value.decode::<i64>() {
                doc.add_i64(field, int_val);
                Ok(())
            } else if let Ok(int_val) = value.decode::<u64>() {
                doc.add_i64(field, int_val as i64);
                Ok(())
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::F64(_) => {
            if let Ok(float_val) = value.decode::<f64>() {
                doc.add_f64(field, float_val);
                Ok(())
            } else if let Ok(int_val) = value.decode::<i64>() {
                doc.add_f64(field, int_val as f64);
                Ok(())
            } else if let Ok(int_val) = value.decode::<u64>() {
                doc.add_f64(field, int_val as f64);
                Ok(())
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::Bool(_) => {
            let bool_val: bool = value.decode().map_err(|_| "Expected boolean value")?;
            doc.add_bool(field, bool_val);
            Ok(())
        }
        FieldType::Date(_) => {
            if let Ok(timestamp) = value.decode::<i64>() {
                let datetime = tantivy::DateTime::from_timestamp_secs(timestamp);
                doc.add_date(field, datetime);
                Ok(())
            } else if let Ok(string_val) = value.decode::<String>() {
                let dt = chrono::DateTime::parse_from_rfc3339(&string_val)
                    .map_err(|_| "Invalid date format, expected ISO 8601".to_string())?;
                let timestamp = dt.timestamp();
                let datetime = tantivy::DateTime::from_timestamp_secs(timestamp);
                doc.add_date(field, datetime);
                Ok(())
            } else {
                Err("Expected timestamp (integer) or ISO 8601 date string".to_string())
            }
        }
        FieldType::Facet(_) => {
            // Handle both single strings and arrays of strings for facet fields
            if let Ok(string_val) = value.decode::<String>() {
                let facet = tantivy::schema::Facet::from_text(&string_val)
                    .map_err(|_| "Invalid facet format".to_string())?;
                doc.add_facet(field, facet);
                Ok(())
            } else if let Ok(facet_array) = value.decode::<Vec<rustler::Term>>() {
                // Handle arrays of facet values
                for facet_item in facet_array {
                    if let Ok(facet_val) = facet_item.decode::<String>() {
                        if let Ok(facet) = tantivy::schema::Facet::from_text(&facet_val) {
                            doc.add_facet(field, facet);
                        }
                    }
                }
                Ok(())
            } else {
                Err("Expected string value or array of strings for facet".to_string())
            }
        }
        FieldType::Bytes(_) => {
            if let Ok(bytes_val) = value.decode::<Vec<u8>>() {
                doc.add_bytes(field, &bytes_val);
                Ok(())
            } else if let Ok(string_val) = value.decode::<String>() {
                let bytes = general_purpose::STANDARD
                    .decode(&string_val)
                    .map_err(|_| "Invalid base64 encoding".to_string())?;
                doc.add_bytes(field, &bytes);
                Ok(())
            } else {
                Err("Expected byte array or base64 string".to_string())
            }
        }
        FieldType::JsonObject(_) => {
            let json_value = convert_term_to_json_value(value);
            let btree_map = convert_json_value_to_btreemap(json_value);
            doc.add_object(field, btree_map);
            Ok(())
        }
        FieldType::IpAddr(_) => {
            let string_val: String = value
                .decode()
                .map_err(|_| "Expected string value for IP address")?;
            let ip = string_val
                .parse::<std::net::IpAddr>()
                .map_err(|_| "Invalid IP address format".to_string())?;
            let ipv6 = convert_ip_to_ipv6(ip);
            doc.add_ip_addr(field, ipv6);
            Ok(())
        }
    }
}

pub fn validate_field_value(value: rustler::Term, field_type: &FieldType) -> Result<(), String> {
    match field_type {
        FieldType::Str(_) => {
            value
                .decode::<String>()
                .map_err(|_| "Expected string value")?;
            Ok(())
        }
        FieldType::U64(_) => {
            if value.decode::<u64>().is_ok() {
                Ok(())
            } else if let Ok(int_val) = value.decode::<i64>() {
                if int_val >= 0 {
                    Ok(())
                } else {
                    Err("Negative value not allowed for u64 field".to_string())
                }
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::I64(_) => {
            if value.decode::<i64>().is_ok() || value.decode::<u64>().is_ok() {
                Ok(())
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::F64(_) => {
            if value.decode::<f64>().is_ok()
                || value.decode::<i64>().is_ok()
                || value.decode::<u64>().is_ok()
            {
                Ok(())
            } else {
                Err("Expected numeric value".to_string())
            }
        }
        FieldType::Bool(_) => {
            value
                .decode::<bool>()
                .map_err(|_| "Expected boolean value")?;
            Ok(())
        }
        FieldType::Date(_) => {
            if value.decode::<i64>().is_ok() {
                Ok(())
            } else if let Ok(string_val) = value.decode::<String>() {
                chrono::DateTime::parse_from_rfc3339(&string_val)
                    .map_err(|_| "Invalid date format, expected ISO 8601".to_string())?;
                Ok(())
            } else {
                Err("Expected timestamp (integer) or ISO 8601 date string".to_string())
            }
        }
        FieldType::Facet(_) => {
            // Handle both single strings and arrays of strings for facet fields
            if let Ok(string_val) = value.decode::<String>() {
                tantivy::schema::Facet::from_text(&string_val)
                    .map_err(|_| "Invalid facet format".to_string())?;
                Ok(())
            } else if let Ok(facet_array) = value.decode::<Vec<rustler::Term>>() {
                // Handle arrays of facet values
                for facet_item in facet_array {
                    if let Ok(facet_val) = facet_item.decode::<String>() {
                        tantivy::schema::Facet::from_text(&facet_val)
                            .map_err(|_| "Invalid facet format".to_string())?;
                    }
                }
                Ok(())
            } else {
                Err("Expected string value or array of strings for facet".to_string())
            }
        }
        FieldType::Bytes(_) => {
            if value.decode::<Vec<u8>>().is_ok() {
                Ok(())
            } else if let Ok(string_val) = value.decode::<String>() {
                general_purpose::STANDARD
                    .decode(&string_val)
                    .map_err(|_| "Invalid base64 encoding".to_string())?;
                Ok(())
            } else {
                Err("Expected byte array or base64 string".to_string())
            }
        }
        FieldType::JsonObject(_) => {
            // JSON objects can be pretty much anything
            Ok(())
        }
        FieldType::IpAddr(_) => {
            let string_val: String = value
                .decode()
                .map_err(|_| "Expected string value for IP address")?;
            string_val
                .parse::<std::net::IpAddr>()
                .map_err(|_| "Invalid IP address format".to_string())?;
            Ok(())
        }
    }
}

pub fn convert_term_to_json_value(term: rustler::Term) -> serde_json::Value {
    if let Ok(s) = term.decode::<String>() {
        serde_json::Value::String(s)
    } else if let Ok(i) = term.decode::<i64>() {
        serde_json::Value::Number(serde_json::Number::from(i))
    } else if let Ok(u) = term.decode::<u64>() {
        serde_json::Value::Number(serde_json::Number::from(u))
    } else if let Ok(f) = term.decode::<f64>() {
        serde_json::Value::Number(
            serde_json::Number::from_f64(f).unwrap_or(serde_json::Number::from(0)),
        )
    } else if let Ok(b) = term.decode::<bool>() {
        serde_json::Value::Bool(b)
    } else if let Ok(map) = term.decode::<HashMap<String, rustler::Term>>() {
        let mut obj = serde_json::Map::new();
        for (key, value) in map {
            obj.insert(key, convert_term_to_json_value(value));
        }
        serde_json::Value::Object(obj)
    } else if let Ok(vec) = term.decode::<Vec<rustler::Term>>() {
        let array: Vec<serde_json::Value> =
            vec.into_iter().map(convert_term_to_json_value).collect();
        serde_json::Value::Array(array)
    } else {
        serde_json::Value::Null
    }
}
