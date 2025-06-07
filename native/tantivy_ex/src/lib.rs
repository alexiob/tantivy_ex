// Refactored lib.rs - Main entry point for the TantivyEx native module

// Module declarations
pub mod modules {
    pub mod document;
    pub mod index;
    pub mod query;
    pub mod resources;
    pub mod schema;
    pub mod search;
}

// Import all public functions from modules
// Note: These imports appear "unused" to the compiler because they're used
// via the #[rustler::nif] macro system, not direct Rust function calls
#[allow(unused_imports)]
use modules::document::*;
#[allow(unused_imports)]
use modules::index::*;
#[allow(unused_imports)]
use modules::query::*;
#[allow(unused_imports)]
use modules::schema::*;
#[allow(unused_imports)]
use modules::search::*;

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
    true
}

// Register all NIFs with rustler
rustler::init! {
    "Elixir.TantivyEx.Native",
    load = load
}
