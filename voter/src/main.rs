use anyhow::Result;
use nostr_sdk::prelude::*;

#[tokio::main]
async fn main() -> Result<()> {
    // Crea un nuevo par de claves aleatorio. Sustitúyelo por tu propia nsec
    // si necesitas una identidad permanente.
    let keys = Keys::generate();

    println!("🔑 Public key bech32: {}", keys.public_key().to_bech32()?);

    // Construye el cliente firmante
    let client = Client::builder()
        .signer(keys.clone())
        .build();

    // Añade el relay Mostro y conéctate
    client.add_relay("wss://relay.mostro.network").await?;
    client.connect().await;

    // Crea un "rumor" (evento sin firmar) con el contenido que quieres proteger
    let rumor: UnsignedEvent = EventBuilder::text_note("hola").build(keys.public_key());

    // Envuelve el rumor en un Gift Wrap dirigido a nosotros mismos
    let gift_wrap: Event = EventBuilder::gift_wrap(
        &keys,                 // Firmante (emisor)
        &keys.public_key(),    // Receptor (nosotros mismos en este ejemplo)
        rumor,
        None                   // Sin etiquetas adicionales
    ).await?;

    // Publica el Gift Wrap en el relay
    client.send_event(&gift_wrap).await?;

    println!("🎁 Gift Wrap enviado. Dale unos segundos al relay para procesarlo…");
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;

    Ok(())
}
