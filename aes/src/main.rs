use std::io;
mod aes;
mod processor;

fn main() -> io::Result<()> {
    println!("Welcome to the AES Simulator");
// 1) pick the *one* file in data/inbox/file
    let inbox_file_dir = "data/inbox/file";
    let mut files = std::fs::read_dir(inbox_file_dir)?;
    let file_entry = files
        .next()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no file in inbox"))??;
    let input_path = file_entry.path().display().to_string();
    println!("  picked file   : {}", input_path);

    // 2) pick the *one* key in data/inbox/key
    let key_dir = "data/inbox/key";
    let mut keys = std::fs::read_dir(key_dir)?;
    let key_entry = keys
        .next()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no key in inbox"))??;
    let key_path = key_entry.path();
    let key_hex = std::fs::read_to_string(&key_path)?
        .trim()
        .to_string();
    println!("  picked key    : {}", key_path.display());
    println!("    ({} hex chars)", key_hex.len());

    // 3) pick the *one* todo in data/inbox/todo for mode
    let todo_dir = "data/inbox/todo";
    let mut todos = std::fs::read_dir(todo_dir)?;
    let todo_entry = todos
        .next()
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "no todo entry"))??;
    let raw = todo_entry.file_name().to_string_lossy().to_lowercase();
    let mode = match raw.as_str() {
        "enc" | "encrypt" => "enc",
        "dec" | "decrypt" => "dec",
        other => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("unknown todo: {}", other),
            ))
        }
    };
    println!("  action mode   : {}", mode);

    // hand off to processor
    processor::process(mode, &input_path, &key_hex)
 }
