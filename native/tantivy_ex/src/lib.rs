// Refactored lib.rs - Main entry point for the TantivyEx native module

// Module declarations
pub mod modules {
    pub mod aggregation;
    pub mod custom_collector;
    pub mod document;
    pub mod facet;
    pub mod index;
    pub mod index_warming;
    pub mod merge_policy;
    pub mod query;
    pub mod reader_manager;
    pub mod resources;
    pub mod schema;
    pub mod search;
    pub mod space_analysis;
    pub mod tokenizer;
}

// Import all public functions from modules
// Note: These imports appear "unused" to the compiler because they're used
// via the #[rustler::nif] macro system, not direct Rust function calls
#[allow(unused_imports)]
use modules::aggregation::*;
#[allow(unused_imports)]
use modules::custom_collector::*;
#[allow(unused_imports)]
use modules::document::*;
#[allow(unused_imports)]
use modules::facet::*;
#[allow(unused_imports)]
use modules::index::*;
#[allow(unused_imports)]
use modules::index_warming::*;
#[allow(unused_imports)]
use modules::merge_policy::*;
#[allow(unused_imports)]
use modules::query::*;
#[allow(unused_imports)]
use modules::reader_manager::*;
#[allow(unused_imports)]
use modules::schema::*;
#[allow(unused_imports)]
use modules::search::*;
#[allow(unused_imports)]
use modules::space_analysis::*;
#[allow(unused_imports)]
use modules::tokenizer::*;

rustler::atoms! {
    ok,
    error,
    nil,
}

// NIF loading function
fn load(env: rustler::Env, _: rustler::Term) -> bool {
    let _ = rustler::resource!(modules::resources::SchemaResource, env);
    let _ = rustler::resource!(modules::resources::IndexResource, env);
    let _ = rustler::resource!(modules::resources::IndexWriterResource, env);
    let _ = rustler::resource!(modules::resources::SearcherResource, env);
    let _ = rustler::resource!(modules::resources::QueryResource, env);
    let _ = rustler::resource!(modules::resources::QueryParserResource, env);
    let _ = rustler::resource!(modules::resources::TokenizerManagerResource, env);
    let _ = rustler::resource!(modules::facet::FacetCollectorResource, env);
    let _ = rustler::resource!(modules::facet::FacetResource, env);
    let _ = rustler::resource!(modules::index_warming::IndexWarmingResource, env);
    let _ = rustler::resource!(modules::merge_policy::MergePolicyResource, env);
    let _ = rustler::resource!(modules::space_analysis::SpaceAnalysisResource, env);
    let _ = rustler::resource!(modules::custom_collector::CustomCollectorResource, env);
    let _ = rustler::resource!(modules::reader_manager::ReaderManagerResource, env);
    true
}

// Register all NIFs with rustler
rustler::init!("Elixir.TantivyEx.Native", load = load);
