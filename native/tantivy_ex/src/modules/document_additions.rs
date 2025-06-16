#[rustler::nif]
pub fn writer_delete_documents<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
    query_res: ResourceArc<QueryResource>,
) -> NifResult<Term<'a>> {
    let mut writer = writer_res.writer.lock().unwrap();

    match writer.delete_documents(query_res.query.box_clone()) {
        Ok(_) => Ok(atoms::ok().encode(env)),
        Err(e) => Err(rustler::Error::Term(Box::new(format!(
            "Failed to delete documents: {}",
            e
        )))),
    }
}

#[rustler::nif]
pub fn writer_delete_all_documents<'a>(
    env: Env<'a>,
    writer_res: ResourceArc<IndexWriterResource>,
) -> NifResult<Term<'a>> {
    let mut writer = writer_res.writer.lock().unwrap();

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
