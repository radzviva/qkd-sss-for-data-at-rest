// src/processor.rs
use crate::aes::AesSimulator;
use std::{fs, io};
use std::path::Path;

/// Processes one AES operation on a file (encrypt or decrypt)
pub fn process(mode: &str, input_path: &str, key_hex: &str) -> io::Result<()> {
    println!("🔐 AES-128 Simulation: Data At Rest 🔐");
    println!("Mode: {} | File: {}", mode, input_path);

    // Read file contents
    let data = fs::read(input_path)?;

    // Decode hex key and validate length
    let key_bytes = hex::decode(key_hex)
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "Key must be hex"))?;
        if !(key_bytes.len() == 16 || key_bytes.len() == 32) {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Key must be 32 hex (16 bytes) or 64 hex (32 bytes)",
            ));
        }
        // 4) if they gave us 64-hex, just slice the first 16 bytes for AES-128
        let key_arr: [u8; 16] = key_bytes[..16].try_into().unwrap();


    let sim = AesSimulator::new(&key_arr);

    let block_size = 16;
    let mut output: Vec<u8> = Vec::with_capacity(data.len());

    match mode {
        "enc" => {
            // PKCS#7 padding
            let pad_len = block_size - (data.len() % block_size);
            let mut padded = data.clone();
            padded.extend(vec![pad_len as u8; pad_len]);
            println!("Encrypting {} blocks…", padded.len() / block_size);
            for (i, blk) in padded.chunks(block_size).enumerate() {
                println!("\n--- Encrypting Block {} ---", i + 1);
                let c = sim.encrypt_block(blk.try_into().unwrap());
                output.extend(&c);
            }
        }
        "dec" => {
            if data.len() % block_size != 0 {
                return Err(io::Error::new(io::ErrorKind::InvalidData, "Encrypted file size not a multiple of 16 bytes"));
            }
            println!("Decrypting {} blocks…", data.len() / block_size);
            for (i, blk) in data.chunks(block_size).enumerate() {
                println!("\n--- Decrypting Block {} ---", i + 1);
                let p = sim.decrypt_block(blk.try_into().unwrap());
                output.extend(&p);
            }
            // Remove PKCS#7 padding
            if let Some(&last) = output.last() {
                let pad_len = last as usize;
                if pad_len <= block_size {
                    let new_len = output.len().saturating_sub(pad_len);
                    output.truncate(new_len);
                }
            }
        }
        _ => {
            return Err(io::Error::new(io::ErrorKind::InvalidInput, "Mode must be 'enc' or 'dec'"));
        }
    }

    // Prefix output filename
    let input_path = Path::new(input_path);
    let file_name = input_path.file_name().unwrap().to_string_lossy();
    let prefix = if mode == "enc" { "enc_" } else { "dec_" };
    let out_file_name = format!("{}{}", prefix, file_name);
    let out_path = Path::new("data/outbox").join(out_file_name);

    fs::write(&out_path, &output)?;
    println!("\n✅ {} complete. Output: {}", mode.to_uppercase(), out_path.display());
    Ok(())
}
