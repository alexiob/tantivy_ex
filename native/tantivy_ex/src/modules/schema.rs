use rustler::{Encoder, Env, NifResult, ResourceArc, Term};
use tantivy::schema::{
    BytesOptions, DateOptions, FacetOptions, FieldType, IpAddrOptions, JsonObjectOptions,
    NumericOptions, Schema, TextFieldIndexing, TextOptions,
};

use crate::modules::resources::SchemaResource;

/// Schema building functions
#[rustler::nif]
pub fn schema_builder_new() -> rustler::ResourceArc<SchemaResource> {
    let schema = Schema::builder().build();
    rustler::ResourceArc::new(SchemaResource { schema })
}

#[rustler::nif]
pub fn schema_add_text_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options for the new field
    let field_options = match options.as_str() {
        "TEXT_STORED" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default())
            .set_stored(),
        "TEXT" => TextOptions::default().set_indexing_options(TextFieldIndexing::default()),
        "STORED" => TextOptions::default().set_stored(),
        "FAST" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default())
            .set_fast(None),
        "FAST_STORED" => TextOptions::default()
            .set_indexing_options(
                TextFieldIndexing::default()
                    .set_index_option(tantivy::schema::IndexRecordOption::WithFreqsAndPositions),
            )
            .set_stored()
            .set_fast(None),
        _ => TextOptions::default().set_indexing_options(TextFieldIndexing::default()),
    };

    schema_builder.add_text_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_text_field_with_tokenizer(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
    tokenizer: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options and configure with custom tokenizer
    let field_options = match options.as_str() {
        "TEXT_STORED" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer))
            .set_stored(),
        "TEXT" => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer)),
        "STORED" => {
            // For STORED-only fields, we don't set indexing options or tokenizer
            TextOptions::default().set_stored()
        }
        _ => TextOptions::default()
            .set_indexing_options(TextFieldIndexing::default().set_tokenizer(&tokenizer)),
    };

    schema_builder.add_text_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_u64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Parse options for the new field
    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_u64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_i64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_i64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_f64_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_f64_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_bool_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => NumericOptions::default().set_indexed().set_stored(),
        "INDEXED" => NumericOptions::default().set_indexed(),
        "STORED" => NumericOptions::default().set_stored(),
        "FAST" => NumericOptions::default().set_fast(),
        "FAST_STORED" => NumericOptions::default().set_fast().set_stored(),
        _ => NumericOptions::default().set_indexed(),
    };

    schema_builder.add_bool_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_date_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => DateOptions::default().set_indexed().set_stored(),
        "INDEXED" => DateOptions::default().set_indexed(),
        "STORED" => DateOptions::default().set_stored(),
        "FAST" => DateOptions::default().set_fast(),
        "FAST_STORED" => DateOptions::default().set_fast().set_stored(),
        _ => DateOptions::default().set_indexed(),
    };

    schema_builder.add_date_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_facet_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    _options: String, // Facet fields don't use the same options pattern
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    // Facet fields are always indexed and stored by default
    let field_options = FacetOptions::default();

    schema_builder.add_facet_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_bytes_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => BytesOptions::default().set_indexed().set_stored(),
        "INDEXED" => BytesOptions::default().set_indexed(),
        "STORED" => BytesOptions::default().set_stored(),
        "FAST" => BytesOptions::default().set_fast(),
        "FAST_STORED" => BytesOptions::default().set_fast().set_stored(),
        _ => BytesOptions::default().set_stored(), // Bytes are typically stored
    };

    schema_builder.add_bytes_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_json_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "STORED" => JsonObjectOptions::default().set_stored(),
        _ => JsonObjectOptions::default(), // JSON fields are indexed by default
    };

    schema_builder.add_json_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_add_ip_addr_field(
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
    options: String,
) -> NifResult<ResourceArc<SchemaResource>> {
    let mut schema_builder = Schema::builder();
    copy_existing_fields_to_builder(&schema_res.schema, &mut schema_builder);

    let field_options = match options.as_str() {
        "INDEXED_STORED" => IpAddrOptions::default().set_indexed().set_stored(),
        "INDEXED" => IpAddrOptions::default().set_indexed(),
        "STORED" => IpAddrOptions::default().set_stored(),
        "FAST" => IpAddrOptions::default().set_fast(),
        "FAST_STORED" => IpAddrOptions::default().set_fast().set_stored(),
        _ => IpAddrOptions::default().set_indexed(),
    };

    schema_builder.add_ip_addr_field(&field_name, field_options);
    let schema = schema_builder.build();

    Ok(ResourceArc::new(SchemaResource { schema }))
}

#[rustler::nif]
pub fn schema_get_field_names<'a>(
    env: Env<'a>,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<Term<'a>> {
    let field_names: Vec<String> = schema_res
        .schema
        .fields()
        .map(|(field, _)| schema_res.schema.get_field_name(field).to_string())
        .collect();

    Ok(field_names.encode(env))
}

#[rustler::nif]
pub fn schema_get_field_type<'a>(
    env: Env<'a>,
    schema_res: ResourceArc<SchemaResource>,
    field_name: String,
) -> NifResult<Term<'a>> {
    match schema_res.schema.get_field(&field_name) {
        Ok(field) => {
            let field_entry = schema_res.schema.get_field_entry(field);
            let field_type_str = match field_entry.field_type() {
                FieldType::Str(_) => "text",
                FieldType::U64(_) => "u64",
                FieldType::I64(_) => "i64",
                FieldType::F64(_) => "f64",
                FieldType::Bool(_) => "bool",
                FieldType::Date(_) => "date",
                FieldType::Facet(_) => "facet",
                FieldType::Bytes(_) => "bytes",
                FieldType::JsonObject(_) => "json",
                FieldType::IpAddr(_) => "ip_addr",
            };
            Ok(field_type_str.encode(env))
        }
        Err(_) => Err(rustler::Error::Term(Box::new(format!(
            "Field '{}' not found in schema",
            field_name
        )))),
    }
}

#[rustler::nif]
pub fn schema_validate<'a>(
    env: Env<'a>,
    schema_res: ResourceArc<SchemaResource>,
) -> NifResult<Term<'a>> {
    // Basic validation - check if schema has at least one field
    let field_count = schema_res.schema.fields().count();
    if field_count == 0 {
        return Err(rustler::Error::Term(Box::new(
            "Schema must have at least one field".to_string(),
        )));
    }

    // Return success message with field count
    let message = format!("Schema is valid with {} fields", field_count);
    Ok(message.encode(env))
}

/// Helper function to copy existing fields to a new schema builder (DRY principle)
fn copy_existing_fields_to_builder(
    schema: &Schema,
    schema_builder: &mut tantivy::schema::SchemaBuilder,
) {
    for (field, field_entry) in schema.fields() {
        let field_name_existing = schema.get_field_name(field);
        match field_entry.field_type() {
            FieldType::Str(text_options) => {
                schema_builder.add_text_field(field_name_existing, text_options.clone());
            }
            FieldType::U64(int_options) => {
                schema_builder.add_u64_field(field_name_existing, int_options.clone());
            }
            FieldType::I64(int_options) => {
                schema_builder.add_i64_field(field_name_existing, int_options.clone());
            }
            FieldType::F64(float_options) => {
                schema_builder.add_f64_field(field_name_existing, float_options.clone());
            }
            FieldType::Bool(bool_options) => {
                schema_builder.add_bool_field(field_name_existing, bool_options.clone());
            }
            FieldType::Date(date_options) => {
                schema_builder.add_date_field(field_name_existing, date_options.clone());
            }
            FieldType::Facet(facet_options) => {
                schema_builder.add_facet_field(field_name_existing, facet_options.clone());
            }
            FieldType::Bytes(bytes_options) => {
                schema_builder.add_bytes_field(field_name_existing, bytes_options.clone());
            }
            FieldType::JsonObject(json_options) => {
                schema_builder.add_json_field(field_name_existing, json_options.clone());
            }
            FieldType::IpAddr(ip_options) => {
                schema_builder.add_ip_addr_field(field_name_existing, ip_options.clone());
            }
        }
    }
}
