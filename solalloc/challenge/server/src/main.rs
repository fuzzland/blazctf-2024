use sol_ctf_framework::ChallengeBuilder;

use solana_program::{
    instruction::{AccountMeta, Instruction},
    pubkey::Pubkey,
    system_instruction, system_program,
};
use solana_program_test::tokio;
use solana_sdk::{signature::Signer, signer::keypair::Keypair};
use std::error::Error;
use std::io::Write;
use std::net::{TcpListener, TcpStream};

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    let listener = TcpListener::bind("0.0.0.0:31337")?;

    println!("Listening on port 31337 ...");

    for stream in listener.incoming() {
        let stream = stream.unwrap();

        tokio::spawn(async {
            if let Err(err) = handle_connection(stream).await {
                println!("error: {:?}", err);
            }
        });
    }
    Ok(())
}

async fn handle_connection(mut socket: TcpStream) -> Result<(), Box<dyn Error>> {
    let mut builder = ChallengeBuilder::try_from(socket.try_clone().unwrap()).unwrap();

    let program_id = builder.add_program("/home/user/server/solalloc.so", None);
    let solve_id = builder.input_program()?;

    let mut chall = builder.build().await;

    let payer_keypair = &chall.ctx.payer;
    let payer = payer_keypair.pubkey();

    // Creating admin keypair
    let admin_keypair = Keypair::new();
    let admin = admin_keypair.pubkey();

    chall
        .run_ix(system_instruction::transfer(
            &payer,
            &admin,
            100_000_000_000,
        ))
        .await?;

    // Creating user keypair
    let user_keypair = Keypair::new();
    let user = user_keypair.pubkey();

    chall
        .run_ix(system_instruction::transfer(&payer, &user, 1_000_000_000)) // 1 sol
        .await?;

    writeln!(socket, "program: {}", program_id)?;
    writeln!(socket, "user: {}", user)?;
    writeln!(socket, "admin: {}", admin)?;

    let (data_addr, data_bump) = Pubkey::find_program_address(&["BLAZ".as_bytes()], &program_id);

    // register data
    let ix = Instruction {
        program_id,
        accounts: vec![
            AccountMeta::new(admin, true),
            AccountMeta::new(data_addr, false),
            AccountMeta::new(program_id, false),
            AccountMeta::new_readonly(system_program::id(), false),
        ],
        data: vec![1, data_bump, 0],
    };

    chall.run_ixs_full(&[ix], &[&admin_keypair], &admin).await?;

    let solve_ix = chall.read_instruction(solve_id)?;
    chall
        .run_ixs_full(&[solve_ix], &[&user_keypair], &user_keypair.pubkey())
        .await?;

    if let Some(account) = chall.ctx.banks_client.get_account(user).await? {
        if account.lamports > 2_000_000_000 {
            writeln!(
                socket,
                "Good job!\n{}",
                std::env::var("FLAG").unwrap_or_else(|_| "flag{test_flag}".to_string())
            )?;
        } else {
            writeln!(socket, "Try harder")?;
        }
    } else {
        writeln!(socket, "Try harder!")?;
    }
    Ok(())
}
